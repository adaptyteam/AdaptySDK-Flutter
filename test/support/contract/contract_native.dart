import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/src/constants/method.dart';
import 'package:adapty_flutter/src/runtime/adapty_native_transport.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/contract/src/baseline.dart';
import '../../../tool/contract/src/contract_schema.dart';
import '../../../tool/contract/src/corpus.dart';
import '../../../tool/contract/src/schema_validator.dart' show normalizeJson;

/// What a call the SDK made on the adapty channel looked like to the contract native.
final class ContractCall {
  ContractCall({required this.method, required this.arguments, required this.violations, required this.reply});

  /// The name of the call on the channel.
  final String method;

  /// The JSON arguments, decoded; empty when they were not a JSON object.
  final Map<String, Object?> arguments;

  /// The violations of the contract the baseline did not take away.
  final List<Violation> violations;

  /// The reply sent back, as the JSON string the native side would send; null when there was none.
  final String? reply;

  /// [arguments] with every value that changes from one release of the SDK to the next replaced by a
  /// placeholder: the cross-platform SDK version becomes [sdkVersionPlaceholder].
  Map<String, Object?> get normalizedArguments => _normalized(arguments)! as Map<String, Object?>;

  static Object? _normalized(Object? value) => switch (value) {
    Map<String, Object?>() => {
      for (final MapEntry(:key, :value) in value.entries)
        key: key == 'cross_platform_sdk_version' && value is String ? sdkVersionPlaceholder : _normalized(value),
    },
    List<Object?>() => [for (final item in value) _normalized(item)],
    _ => value,
  };
}

/// What a cross-platform SDK version is replaced with in [ContractCall.normalizedArguments].
const sdkVersionPlaceholder = '<sdk-version>';

/// A violation the baseline took away, with the call it came from and the item that took it.
typedef SuppressedViolation = ({ContractCall call, Violation violation, BaselineItem item});

/// The schema and the corpus of this repository, read once per test file.
final ContractSchema _repositorySchema = ContractSchema.load('.');
final Corpus _repositoryCorpus = Corpus.load('.');

const _channel = MethodChannel(adaptyChannelName);
const _codec = StandardMethodCodec();

/// The calls that answer an event of the native side, matched to it by `event_id`.
final _eventAnswers = {for (final answer in NativeEventResponse.values) answer.wireName};

/// The native side of one platform as the bridge contract describes it, behind the real adapty
/// method channel.
///
/// Every call of the SDK is checked against its request in the schema for [platform], with the
/// overlays of the schema and the baseline of known discrepancies; what is still wrong is a problem,
/// and the problems fail the test when it ends. The reply is the `default` case of the method in the
/// corpus of [platform], another case after [respond], the answer before activation after
/// [replyNotActivated]. A method the platform does not handle gets the "method not found" error of
/// the native side and is a `platform_method` violation. Events go to the SDK from the corpus with
/// [sendEvent]; an answer to an event is matched to it by its `event_id`, and only one answer of each
/// kind is allowed.
final class ContractNative {
  ContractNative._(this.platform, this._schema, this._corpus, this._baseline);

  /// Answers the calls on the adapty channel as the native side of [platform] until the end of the
  /// test, then fails the test with every problem left.
  ///
  /// The schema, the corpus and the baseline are those of this repository unless given.
  static ContractNative install({
    required ContractPlatform platform,
    ContractSchema? schema,
    Corpus? corpus,
    List<BaselineEntry>? baseline,
  }) {
    final source = corpus ?? _repositoryCorpus;
    final native = ContractNative._(
      platform,
      schema ?? _repositorySchema,
      source,
      baselineItems(baseline ?? source.baseline),
    );
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_channel, native._handle);
    addTearDown(() {
      messenger.setMockMethodCallHandler(_channel, null);
      native.verify();
    });
    return native;
  }

  final ContractPlatform platform;
  final ContractSchema _schema;
  final Corpus _corpus;
  final List<BaselineItem> _baseline;

  final _calls = <ContractCall>[];
  final _suppressed = <SuppressedViolation>[];
  final _problems = <String>[];
  final _cases = <String, String>{};
  final _sentEventIds = <String>{};
  final _answered = <(String, String)>{};
  var _notActivated = false;

  /// Every call the SDK made, in order.
  List<ContractCall> get calls => List.unmodifiable(_calls);

  /// Every violation the baseline took away, in order.
  List<SuppressedViolation> get suppressed => List.unmodifiable(_suppressed);

  /// What is wrong so far, one line each.
  List<String> get problems => List.unmodifiable(_problems);

  /// Hands over the problems so far and forgets them.
  List<String> takeProblems() {
    final taken = [..._problems];
    _problems.clear();
    return taken;
  }

  /// Fails the test with every problem so far.
  void verify() {
    if (_problems.isEmpty) return;
    fail('The contract native of ${platform.name} found ${_problems.length} problem(s):\n${_problems.join('\n')}');
  }

  /// Answers [method] with the case [caseName] of the platform from now on. A case the corpus does
  /// not have for the platform is refused at once.
  void respond(String method, String caseName) {
    if (_corpus.fixture(CorpusKind.response, method, caseName, platform) == null) {
      throw ArgumentError.value(caseName, 'caseName', 'no case of $method on ${platform.name} in the corpus');
    }
    _cases[method] = caseName;
  }

  /// Answers every call from now on as the native side does before the SDK is activated.
  void replyNotActivated() => _notActivated = true;

  /// Sends the event [id] with the payload of its case [caseName] of the platform, as the native side
  /// does, and returns the reply of the SDK. An event the platform does not send, or a case the corpus
  /// does not have for it, is refused at once.
  Future<Object?> sendEvent(String id, {String caseName = 'default'}) async {
    if (!(_schema.eventPlatforms[id]?.contains(platform) ?? false)) {
      throw ArgumentError.value(id, 'id', '${platform.name} does not send this event');
    }
    final fixture =
        _corpus.fixture(CorpusKind.event, id, caseName, platform) ??
        (throw ArgumentError.value(caseName, 'caseName', 'no case of $id on ${platform.name} in the corpus'));
    final payload = fixture.payload;
    if (payload is Map<String, Object?>) {
      if (payload['event_id'] case final String eventId) _sentEventIds.add(eventId);
    }

    final reply = Completer<ByteData?>();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      adaptyChannelName,
      _codec.encodeMethodCall(MethodCall(id, jsonEncode(payload))),
      reply.complete,
    );
    final data = await reply.future;
    if (data == null) {
      _problems.add('$id on ${platform.name}: nothing on the channel took the event');
      return null;
    }
    return _codec.decodeEnvelope(data);
  }

  /// The answers the SDK sent to the event with [eventId], in order.
  List<ContractCall> answersTo(String eventId) => [
    for (final call in _calls)
      if (_eventAnswers.contains(call.method) && call.arguments['event_id'] == eventId) call,
  ];

  Future<Object?> _handle(MethodCall call) async {
    final method = call.method;
    final where = '$method on ${platform.name}';
    final arguments = _decode(call.arguments);
    if (arguments == null) _problems.add('$where: the arguments are not a JSON object as a string: ${call.arguments}');
    final args = arguments ?? const <String, Object?>{};

    final SchemaEntry entry;
    try {
      entry = _schema.requestEntry(method);
    } on ArgumentError {
      _problems.add('$where: not a request of the contract');
      final reply = _methodNotFound(method);
      _record(method, args, const [], reply);
      return reply;
    }

    final handled = _schema.methodPlatforms[method]!.contains(platform);
    final violations = [
      if (arguments != null) ..._schema.validate(entry, arguments, platform: platform).violations,
      if (!handled)
        Violation(
          instancePath: '',
          keyword: 'platform_method',
          schemaPointer: entry.pointer,
          detail: '${platform.name} does not handle $method',
        ),
    ];
    final kept = <Violation>[];
    final taken = <(Violation, BaselineItem)>[];
    for (final violation in violations) {
      final item = _baseline.where((item) => item.matches(entry.name, platform, violation)).firstOrNull;
      if (item == null) {
        kept.add(violation);
        _problems.add('$where: ${entry.name} (${entry.mode.label}): $violation');
      } else {
        taken.add((violation, item));
      }
    }

    if (_eventAnswers.contains(method)) _matchAnswer(method, args, where);

    final String? reply;
    if (_notActivated) {
      reply = _notActivatedReply(platform);
    } else if (!handled) {
      reply = _methodNotFound(method);
    } else {
      final caseName = _cases[method] ?? 'default';
      final fixture = _corpus.fixture(CorpusKind.response, method, caseName, platform);
      if (fixture == null) _problems.add('$where: no case "$caseName" in the corpus to answer with');
      reply = fixture == null ? null : jsonEncode(fixture.payload);
    }

    final recorded = _record(method, args, kept, reply);
    for (final (violation, item) in taken) {
      _suppressed.add((call: recorded, violation: violation, item: item));
    }
    return reply;
  }

  ContractCall _record(String method, Map<String, Object?> arguments, List<Violation> violations, String? reply) {
    final call = ContractCall(method: method, arguments: arguments, violations: violations, reply: reply);
    _calls.add(call);
    return call;
  }

  void _matchAnswer(String method, Map<String, Object?> arguments, String where) {
    final eventId = arguments['event_id'];
    if (eventId is! String) return;
    if (!_sentEventIds.contains(eventId)) {
      _problems.add('$where: answers the event with event_id "$eventId", which the native never sent');
    } else if (!_answered.add((method, eventId))) {
      _problems.add('$where: answers the event with event_id "$eventId" a second time');
    }
  }

  static Map<String, Object?>? _decode(Object? arguments) {
    if (arguments is! String) return null;
    try {
      final decoded = normalizeJson(jsonDecode(arguments));
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// The answer of the Android plugin to a method it has no branch for
  /// (`crossplatform/src/main/java/com/adapty/internal/crossplatform/AdaptyCallHandler.kt:104,710-712`
  /// of Android 4.4.0); no method of the contract is unknown to the iOS plugin.
  static String _methodNotFound(String method) => jsonEncode({
    'error': {'adapty_code': 2006, 'message': 'Method $method not found'},
  });

  /// The answer of each plugin to a call before the SDK is activated: iOS `notActivated` with the SDK
  /// error as the detail, Android `ADAPTY_NOT_INITIALIZED` without a detail.
  static String _notActivatedReply(ContractPlatform platform) => switch (platform) {
    ContractPlatform.ios => jsonEncode({
      'error': {
        'adapty_code': 2002,
        'message': _iosNotActivated,
        'detail': jsonEncode({
          'adapty_code': 2002,
          'message': _iosNotActivated,
          'detail': 'AdaptyError.notActivated([4.4.1]: Adapty/Adapty+Shared.swift#43)',
        }),
      },
    }),
    ContractPlatform.android => jsonEncode({
      'error': {'adapty_code': 20, 'message': 'Adapty was not initialized'},
    }),
  };

  static const _iosNotActivated =
      'Adapty SDK is not initialized. You need to activate the SDK before using its methods.';
}

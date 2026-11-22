import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/src/runtime/adapty_native_transport.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/contract/src/baseline.dart';
import '../../../tool/contract/src/contract_schema.dart';
import '../../../tool/contract/src/contract_source.dart';
import '../../../tool/contract/src/corpus.dart';
import '../../../tool/contract/src/request_check.dart';
import '../../../tool/contract/src/schema_validator.dart' show normalizeJson;

export '../../../tool/contract/src/request_check.dart' show eventAnswerMethods, sdkVersionPlaceholder;

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
  Map<String, Object?> get normalizedArguments => normalizedRequest(arguments)! as Map<String, Object?>;
}

/// A violation the baseline took away, with the call it came from and the item that took it.
typedef SuppressedViolation = ({ContractCall call, Violation violation, BaselineItem item});

/// The schema and the corpus of this repository, read once per test file.
final ContractSchema _repositorySchema = ContractSchema.load('.');
final Corpus _repositoryCorpus = Corpus.load('.');
final ContractSource _repositorySource = ContractSource.load('.');

const _channel = MethodChannel(adaptyChannelName);
const _codec = StandardMethodCodec();

/// The native side of one platform as the bridge contract describes it, behind the real adapty
/// method channel.
///
/// Every call of the SDK is checked against its request in the schema for [platform], with the
/// overlays of the schema and the baseline of known discrepancies; what is still wrong is a problem,
/// and the problems fail the test when it ends. In a call declared as a case with [expectCase] only
/// an item of that case takes a violation away; an entry that is not accepted takes nothing away from
/// a call that is not declared. The reply is the `default` case of the method in the corpus of
/// [platform], another case after [respond], the answer before activation after [replyNotActivated].
/// A method the platform does not handle gets the "method not found" error of the native side and is
/// a `platform_method` violation. Events go to the SDK from the corpus with
/// [sendEvent]; an answer to an event is matched to it by its `event_id`, and only one answer of each
/// kind is allowed. That rule is stricter than the natives, which take an answer to an unknown id
/// without complaint: it is a check of the SDK, which never has a reason to send one.
///
/// A failure inside the contract native itself is a problem too, so a test that expects an error of
/// the SDK does not pass on it. The reply comes back sooner than over the real channel, as part of the
/// same turn of the event loop; a test of the order of events and replies cannot rely on it.
final class ContractNative {
  ContractNative._(this.platform, this._schema, this._corpus, this._baseline)
    : _eventAnswers = eventAnswerMethods(_schema);

  /// Answers the calls on the adapty channel as the native side of [platform] until the end of the
  /// test, then fails the test with every problem left.
  ///
  /// The schema, the corpus and the baseline are those of this repository unless given; a test whose
  /// outcome depends on what the baseline holds passes its own. The clean-up is registered with
  /// [registerTearDown], which only the self-test of this file replaces.
  static ContractNative install({
    required ContractPlatform platform,
    ContractSchema? schema,
    Corpus? corpus,
    List<BaselineEntry>? baseline,
    @visibleForTesting void Function(dynamic Function()) registerTearDown = addTearDown,
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
    registerTearDown(() {
      messenger.setMockMethodCallHandler(_channel, null);
      native.verify();
    });
    return native;
  }

  final ContractPlatform platform;
  final ContractSchema _schema;
  final Corpus _corpus;
  final List<BaselineItem> _baseline;
  final Set<String> _eventAnswers;

  final _calls = <ContractCall>[];
  final _suppressed = <SuppressedViolation>[];
  final _problems = <String>[];
  final _cases = <String, String>{};
  final _declared = <String, String>{};
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

  /// Declares that the calls of its method from now on are the case [name] (`<method>/<case>`, as the
  /// baseline names a case). An entry of the baseline that is not accepted takes away a violation only
  /// in a call declared as one of its cases. A name without a method is refused at once.
  void expectCase(String name) {
    final slash = name.indexOf('/');
    if (slash <= 0 || slash == name.length - 1) throw ArgumentError.value(name, 'name', 'not <method>/<case>');
    _declared[name.substring(0, slash)] = name;
  }

  /// Answers every call from now on as the native side does before the SDK is activated: `is_activated`
  /// is false; `activate`, the log level, the SDK version and the answers to events are answered as
  /// usual; a view is never found; iOS does not create a flow view until AdaptyUI is activated and
  /// Android not until Adapty is; the calls of the SDK proper get the not-activated error; a method a
  /// platform has no branch for still gets its "method not found" answer first. Any other call is a
  /// problem: what the native answers to it before activation is not modelled.
  void replyNotActivated() => _notActivated = true;

  /// Sends the event [id] with the payload of its case [caseName] of the platform, as the native side
  /// does, and returns the reply of the SDK. With [eventId] the event goes with that `event_id` instead
  /// of the one of the case, so that two events of the same case can be told apart. An event the
  /// platform does not send, a case the corpus does not have for it, or an [eventId] for a case
  /// without an `event_id`, is refused at once.
  Future<Object?> sendEvent(String id, {String caseName = 'default', String? eventId}) async {
    if (!(_schema.eventPlatforms[id]?.contains(platform) ?? false)) {
      throw ArgumentError.value(id, 'id', '${platform.name} does not send this event');
    }
    final fixture =
        _corpus.fixture(CorpusKind.event, id, caseName, platform) ??
        (throw ArgumentError.value(caseName, 'caseName', 'no case of $id on ${platform.name} in the corpus'));
    var payload = fixture.payload;
    if (eventId != null) {
      if (payload is! Map<String, Object?> || payload['event_id'] is! String) {
        throw ArgumentError.value(eventId, 'eventId', 'the case $caseName of $id has no event_id');
      }
      payload = {...payload, 'event_id': eventId};
    }
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
    final where = '${call.method} on ${platform.name}';
    try {
      return _answer(call, where);
    } catch (e) {
      _problems.add('$where: the contract native failed: $e');
      rethrow;
    }
  }

  String? _answer(MethodCall call, String where) {
    final method = call.method;
    final arguments = _decode(call.arguments);
    if (arguments == null) _problems.add('$where: the arguments are not a JSON object as a string: ${call.arguments}');
    final args = arguments ?? const <String, Object?>{};

    final check = checkRequest(
      _schema,
      _baseline,
      method: method,
      arguments: arguments,
      platform: platform,
      declaredCase: _declared[method],
    );
    if (check == null) {
      _problems.add('$where: not a request of the contract');
      final reply = methodNotFoundReply(method, platform);
      _record(method, args, const [], reply);
      return reply;
    }
    final RequestCheck(:entry, :handled, :kept, :taken) = check;
    for (final violation in kept) {
      _problems.add('$where: ${entry.name} (${entry.mode.label}): $violation');
    }

    if (_eventAnswers.contains(method)) _matchAnswer(method, args, where);

    final reply = !handled
        ? methodNotFoundReply(method, platform)
        : _notActivated
        ? _beforeActivation(method, args, where)
        : _fromCorpus(method, where);

    final recorded = _record(method, args, kept, reply);
    for (final (violation, item) in taken) {
      _suppressed.add((call: recorded, violation: violation, item: item));
    }
    return reply;
  }

  String? _fromCorpus(String method, String where) {
    final caseName = _cases[method] ?? 'default';
    final fixture = _corpus.fixture(CorpusKind.response, method, caseName, platform);
    if (fixture == null) _problems.add('$where: no case "$caseName" in the corpus to answer with');
    return fixture == null ? null : jsonEncode(fixture.payload);
  }

  /// Whether the answer of [method] before activation is modelled ([replyNotActivated]) as a call the SDK makes
  /// on its own: the answers to events are left out, since before activation there is no event to answer.
  static bool modelsBeforeActivation(String method) =>
      method == 'is_activated' ||
      method == 'adapty_ui_create_flow_view' ||
      _answeredBeforeActivation.contains(method) ||
      _viewMethods.contains(method) ||
      _activatedSdkMethods.contains(method);

  String? _beforeActivation(String method, Map<String, Object?> arguments, String where) {
    if (_eventAnswers.contains(method)) return _fromCorpus(method, where);
    if (!modelsBeforeActivation(method)) {
      _problems.add('$where: what the native answers before activation is not modelled');
      return null;
    }
    if (method == 'is_activated') return jsonEncode({'success': false});
    if (_answeredBeforeActivation.contains(method)) return _fromCorpus(method, where);
    if (_viewMethods.contains(method)) return viewNotFoundReply('${arguments['id']}', platform);
    if (method == 'adapty_ui_create_flow_view' && platform == ContractPlatform.ios) return adaptyUINotActivatedReply;
    return notActivatedReply(platform, version: _repositorySource.schemaVersion);
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

  /// The methods both plugins answer before activation as after it: they do not go through the
  /// activated SDK. iOS 4.4.1 `Sources.AdaptyPlugin/Requests/Request.Activate.swift`,
  /// `Request.LogLevel.swift`, `Request.SDKVersion.swift`; Android 4.4.0
  /// `crossplatform/src/main/java/com/adapty/internal/crossplatform/AdaptyCallHandler.kt:108,186,461`.
  static const _answeredBeforeActivation = {'activate', 'set_log_level', 'get_log_level', 'get_sdk_version'};

  /// The methods that look up a view by its id; before activation there is none, and both plugins
  /// answer that the view is not found. iOS 4.4.1
  /// `Sources.AdaptyUI/Crossplatform/Plugin.swift:145,179,204,229,248,344,374`; Android 4.4.0
  /// `crossplatform/src/main/java/com/adapty/internal/crossplatform/ui/CrossplatformUiHelper.kt:55,109,161,223,242,366,429`.
  static const _viewMethods = {
    'adapty_ui_present_flow_view',
    'adapty_ui_dismiss_flow_view',
    'adapty_ui_destroy_flow_view',
    'adapty_ui_send_app_message',
    'adapty_ui_show_dialog',
    'adapty_ui_present_onboarding_view',
    'adapty_ui_dismiss_onboarding_view',
  };

  /// The methods of the SDK proper seen answering the not-activated error on both platforms: the
  /// iOS SDK throws it at `Sources/Adapty+Shared.swift:43`, the Android SDK at
  /// `adapty/src/main/java/com/adapty/Adapty.kt:862-863`.
  static const _activatedSdkMethods = {
    'get_profile',
    'update_profile',
    'identify',
    'logout',
    'get_flow',
    'get_flow_for_default_audience',
    'preload_flows',
    'get_onboarding',
    'get_current_installation_status',
  };
}

/// The cases the native probe sends to each plugin before activation: the golden requests of the
/// contract and the payloads derived from them that break one rule, each with the outcome the
/// plugin is expected to answer with.
library;

import 'dart:convert';

import '../../contract/src/baseline.dart';
import '../../contract/src/contract_schema.dart';
import '../../contract/src/corpus.dart';
import '../../contract/src/negative_variants.dart';
import '../../contract/src/overlays.dart' show plainYaml;
import '../../contract/src/request_check.dart';
import '../../contract/src/schema_validator.dart' show escapePointerSegment;
import '../../contract/src/source_refs.dart';

/// The kind of a native error message.
enum MessageClass {
  /// The plugin knows the method and could not decode its arguments.
  params('params'),

  /// The plugin does not know the method.
  unknownMethod('unknown-method'),

  /// Any other message.
  other('other');

  const MessageClass(this.wireName);

  final String wireName;

  static MessageClass parse(String name) =>
      values.firstWhere((c) => c.wireName == name, orElse: () => throw FormatException('unknown message class $name'));
}

/// The messages of each plugin by kind, as patterns; `{method}` stands for the called method. iOS
/// release/4.4.1: `Sources.AdaptyPlugin/AdaptyJsonData/AdaptyPlugin+AdaptyJsonData.swift:44` for a request
/// that does not decode, `:33` with `Sources.AdaptyPlugin/Requests/Request.swift:89` for an unknown method
/// (the message is the description of the internal error, not its case name). Android 4.4.0:
/// `crossplatform/src/main/java/com/adapty/internal/crossplatform/AdaptyCallHandler.kt:696` and `:711`.
const messagePatterns = <ContractPlatform, Map<MessageClass, String>>{
  ContractPlatform.ios: {
    MessageClass.params: r'^Request params of method:{method} is invalid',
    MessageClass.unknownMethod: r'^Decoding failed: .*AdaptyPluginInternalError error 0\b',
  },
  ContractPlatform.android: {
    MessageClass.params: r'^Error while parsing parameter',
    MessageClass.unknownMethod: r'^Method {method} not found$',
  },
};

/// The kind of an error message [message] the plugin of [platform] answers a call of [method] with.
MessageClass messageClassOf(ContractPlatform platform, String method, String message) {
  for (final MapEntry(key: messageClass, value: pattern) in messagePatterns[platform]!.entries) {
    if (RegExp(pattern.replaceAll('{method}', RegExp.escape(method))).hasMatch(message)) return messageClass;
  }
  return MessageClass.other;
}

/// What a plugin answers a case with.
sealed class Outcome {
  const Outcome();

  /// The outcome as a constant of the integration test app.
  String get dart;
}

final class SuccessOutcome extends Outcome {
  const SuccessOutcome();

  @override
  String get dart => 'L2aSuccess()';
}

final class ErrorOutcome extends Outcome {
  const ErrorOutcome(this.code, this.messageClass);

  final int code;
  final MessageClass messageClass;

  @override
  String get dart => 'L2aError($code, L2aMessageClass.${messageClass.name})';
}

/// The plugin throws: the call ends in a `PlatformException` instead of a reply.
final class NativeExceptionOutcome extends Outcome {
  const NativeExceptionOutcome();

  @override
  String get dart => 'L2aNativeException()';
}

final class TimeoutOutcome extends Outcome {
  const TimeoutOutcome();

  @override
  String get dart => 'L2aTimeout()';
}

/// The case is not called.
final class SkipOutcome extends Outcome {
  const SkipOutcome(this.reason);

  final String reason;

  @override
  String get dart => 'L2aSkip(${_dartString(reason)})';
}

/// The case is called and its answer recorded, not checked.
final class ObserveOutcome extends Outcome {
  const ObserveOutcome();

  @override
  String get dart => 'L2aObserve()';
}

/// Problems that stop the bundle, one line each.
final class BundleProblems implements Exception {
  const BundleProblems(this.problems);

  final List<String> problems;

  @override
  String toString() => problems.join('\n');
}

/// Why a case expects its outcome.
enum Basis {
  /// The default of its kind of request.
  byDefault('default'),

  /// A row of the expectations file.
  record('record'),

  /// A broken payload of a method that decodes the field.
  params('params'),

  /// A broken payload the plugin takes.
  insensitive('insensitive'),

  /// A broken payload the plugin answers as not activated before the SDK uses it.
  unobservable('unobservable'),

  /// A method of the denylist.
  denied('denied'),

  /// Nothing says what to expect: a case without a row in a bundle for discovery, or a negative fixture whose
  /// violation no kind of broken payload stands for (observed in a strict bundle too).
  undecided('undecided');

  const Basis(this.wireName);

  final String wireName;
}

/// One call of the probe.
final class BundleCase {
  const BundleCase({
    required this.id,
    required this.method,
    required this.arguments,
    required this.expected,
    this.variant,
    this.instancePath,
    required this.basis,
  });

  /// Why the case expects [expected].
  final Basis basis;

  /// `<method>/<case>` for a golden request, `<method>/<case>/<kind><path>` for a payload derived from it.
  final String id;
  final String method;

  /// The arguments as the JSON string the SDK sends.
  final String arguments;
  final Outcome expected;

  /// The kind of the broken payload ([MutantKind.wireName]); null for a golden request.
  final String? variant;

  /// Where the payload is broken.
  final String? instancePath;
}

/// The creation params of one embedded view of the corpus.
final class ViewCase {
  const ViewCase({required this.id, required this.viewType, required this.params});

  /// `<view>/<case>`, as the case is named under `contract/pseudo/`.
  final String id;

  /// The view type the plugin registers.
  final String viewType;

  /// The creation params as the JSON string the SDK passes.
  final String params;
}

/// The cases of each platform.
final class L2aBundle {
  const L2aBundle({
    required this.channelName,
    required this.discover,
    required this.cases,
    this.probedIosSha = '',
    this.views = const {},
    this.afterProbe = const {},
    this.contractMethods = const {},
  });

  /// The requests of the contract the SDK sends and the platform handles; the cases of the platform call each one
  /// or deny it.
  final Map<ContractPlatform, List<String>> contractMethods;

  /// The calls the probe makes after all cases, in order, for each platform.
  final Map<ContractPlatform, List<BundleCase>> afterProbe;

  /// The iOS SDK the expectations were recorded on; empty before they are.
  final String probedIosSha;

  /// The creation params of the embedded views of each platform.
  final Map<ContractPlatform, List<ViewCase>> views;

  final String channelName;

  /// Whether what has no expectation is observed instead of stopping the bundle.
  final bool discover;
  final Map<ContractPlatform, List<BundleCase>> cases;

  /// The bundle as a Dart library for the integration test app, the same bytes for the same bundle.
  String render() {
    final out = StringBuffer()
      ..writeln('// Generated by `dart run tool/l2a/bundle_cases.dart` from contract/ and the l2a files of the')
      ..writeln('// integration test app. Do not edit.')
      ..writeln()
      ..writeln("import 'l2a_types.dart';")
      ..writeln()
      ..writeln('/// The channel of the plugin, as the SDK declares it.')
      ..writeln('const l2aChannelName = ${_dartString(channelName)};')
      ..writeln()
      ..writeln('/// Whether the bundle was made for discovery: what has no expectation is observed.')
      ..writeln('const l2aDiscovery = $discover;')
      ..writeln()
      ..writeln('/// The iOS SDK the expectations were recorded on; empty before they are.')
      ..writeln('const l2aProbedIosSha = ${_dartString(probedIosSha)};')
      ..writeln()
      ..writeln('/// The error messages of each plugin by kind; `{method}` stands for the called method.')
      ..writeln('const l2aMessagePatterns = <String, Map<L2aMessageClass, String>>{');
    for (final platform in ContractPlatform.values) {
      out.writeln("  '${platform.name}': {");
      for (final MapEntry(:key, :value) in messagePatterns[platform]!.entries) {
        out.writeln('    L2aMessageClass.${key.name}: ${_dartString(value)},');
      }
      out.writeln('  },');
    }
    out
      ..writeln('};')
      ..writeln()
      ..writeln('/// The cases of each platform, in the order the probe calls them.')
      ..writeln('const l2aCases = <String, List<L2aCase>>{');
    _writeCases(out, cases);
    out
      ..writeln()
      ..writeln('/// The requests of the contract the SDK sends, for each platform; each is called or denied.')
      ..writeln('const l2aContractMethods = <String, List<String>>{');
    for (final platform in ContractPlatform.values) {
      out.writeln(
        "  '${platform.name}': [${[for (final m in contractMethods[platform] ?? const <String>[]) _dartString(m)].join(', ')}],",
      );
    }
    out
      ..writeln('};')
      ..writeln()
      ..writeln('/// The calls the probe makes after all cases, in order, for each platform.')
      ..writeln('const l2aAfterProbe = <String, List<L2aCase>>{');
    _writeCases(out, afterProbe);
    out
      ..writeln()
      ..writeln('/// The creation params of the embedded views of each platform.')
      ..writeln('const l2aViews = <String, List<L2aViewCase>>{');
    for (final platform in ContractPlatform.values) {
      out.writeln("  '${platform.name}': [");
      for (final v in views[platform] ?? const <ViewCase>[]) {
        out
          ..writeln('    L2aViewCase(')
          ..writeln('      id: ${_dartString(v.id)},')
          ..writeln('      viewType: ${_dartString(v.viewType)},')
          ..writeln('      params: ${_dartString(v.params)},')
          ..writeln('    ),');
      }
      out.writeln('  ],');
    }
    out.writeln('};');
    return out.toString();
  }

  /// Writes the entries of a map of cases by platform, and its closing brace.
  static void _writeCases(StringBuffer out, Map<ContractPlatform, List<BundleCase>> byPlatform) {
    for (final platform in ContractPlatform.values) {
      out.writeln("  '${platform.name}': [");
      for (final c in byPlatform[platform] ?? const <BundleCase>[]) {
        out
          ..writeln('    L2aCase(')
          ..writeln('      id: ${_dartString(c.id)},')
          ..writeln('      method: ${_dartString(c.method)},')
          ..writeln('      arguments: ${_dartString(c.arguments)},')
          ..writeln('      expected: ${c.expected.dart},')
          ..writeln('      basis: L2aBasis.${c.basis.name},');
        if (c.variant != null) {
          out
            ..writeln('      variant: ${_dartString(c.variant!)},')
            ..writeln('      instancePath: ${_dartString(c.instancePath!)},');
        }
        out.writeln('    ),');
      }
      out.writeln('  ],');
    }
    out.writeln('};');
  }
}

/// [text] as a Dart string literal.
String _dartString(String text) {
  final out = StringBuffer("'");
  for (final rune in text.runes) {
    out.write(switch (rune) {
      0x5C => r'\\',
      0x27 => r"\'",
      0x24 => r'\$',
      0x0A => r'\n',
      0x0D => r'\r',
      0x09 => r'\t',
      < 0x20 => '\\u{${rune.toRadixString(16)}}',
      _ => String.fromCharCode(rune),
    });
  }
  out.write("'");
  return out.toString();
}

/// The methods the probe does not call, with the reason: calls with a side effect on the device or the
/// process.
final class Denylist {
  const Denylist(this.path, this.reasons);

  /// The denylist of the YAML [text] of the file at [path].
  static Denylist parse(String text, {required String path}) {
    final problems = <String>[];
    final reasons = <String, String>{};
    final root = plainYaml(text);
    final rows = root is Map<String, Object?> ? root['denied'] : null;
    if (rows is! List<Object?>) throw BundleProblems(['$path: denied is not a list']);
    for (final (i, row) in rows.indexed) {
      final where = '$path: denied[$i]';
      if (row is! Map<String, Object?>) {
        problems.add('$where is not a map');
        continue;
      }
      final method = row['method'], reason = row['reason'];
      if (row.keys.toSet().difference(const {'method', 'reason'}) case final unknown when unknown.isNotEmpty) {
        problems.add('$where: unknown keys ${unknown.join(', ')}');
      }
      if (method is! String || method.isEmpty) {
        problems.add('$where: no method');
      } else if (reason is! String || reason.trim().isEmpty) {
        problems.add('$where: $method has no reason');
      } else if (reasons.containsKey(method)) {
        problems.add('$where: $method is denied twice');
      } else {
        reasons[method] = reason;
      }
    }
    if (problems.isNotEmpty) throw BundleProblems(problems);
    return Denylist(path, reasons);
  }

  final String path;
  final Map<String, String> reasons;
}

/// A recorded outcome of a method on a platform: of its golden requests ([kind] null), or of its payloads
/// broken by [kind] at [path]; of one case or, when [caseName] is null, of every case.
final class _Record {
  const _Record({
    required this.index,
    required this.method,
    required this.platform,
    required this.caseName,
    required this.kind,
    required this.path,
    required this.outcome,
  });

  /// The position of the row in `expectations`.
  final int index;
  final String method;
  final ContractPlatform platform;
  final String? caseName;
  final String? kind;
  final String? path;
  final Outcome outcome;
}

/// How a plugin takes the broken payloads of a method.
enum _Mode {
  /// It refuses them, except at the insensitive and the unobservable fields of the row.
  decodes,

  /// It takes them all.
  insensitive,

  /// It answers each as not activated before it gets to the arguments, so whether it would refuse them does not
  /// show.
  unobservable,
}

/// How a plugin takes the broken payloads of a method ([mode]), with the fields where it takes them
/// ([insensitiveFields]) and where activation hides the answer ([unobservableFields]) when it decodes; each
/// field is `<kind> <path>`, with its position in its list.
final class _Sensitivity {
  const _Sensitivity({
    required this.index,
    required this.method,
    required this.platform,
    required this.mode,
    required this.insensitiveFields,
    required this.unobservableFields,
  });

  /// The position of the row in `sensitivity`.
  final int index;
  final String method;
  final ContractPlatform platform;
  final _Mode mode;
  final Map<String, int> insensitiveFields;
  final Map<String, int> unobservableFields;
}

/// The recorded answers of the plugins before activation: the defaults, the outcomes that differ from
/// them and how each method takes broken payloads on each platform.
final class Expectations {
  const Expectations._(
    this.path,
    this._notActivated,
    this._params,
    this._records,
    this._sensitivity,
    this.probedIosSha,
    this._afterProbe,
  );

  /// The expectations of the YAML [text] of the file at [path]; every default and row needs a reason and
  /// a source under one of the native [refs] the contract is fixed to.
  static Expectations parse(String text, {required String path, required Set<String> refs}) {
    final problems = <String>[];
    final root = plainYaml(text);
    if (root is! Map<String, Object?>) throw BundleProblems(['$path: not a map']);
    final unknown = root.keys.toSet().difference(const {
      'probed',
      'defaults',
      'expectations',
      'sensitivity',
      'after_probe',
    });
    if (unknown.isNotEmpty) problems.add('$path: unknown keys ${unknown.join(', ')}');
    if (root['probed'] is! Map<String, Object?>) problems.add('$path: probed is not a map');

    void checkSource(String where, Map<String, Object?> row) {
      final reason = row['reason'], source = row['source'];
      if (reason is! String || source is! String) {
        problems.add('$where: needs a reason and a source');
        return;
      }
      for (final problem in sourceProblems(reason, source, refs: refs)) {
        problems.add('$where: $problem');
      }
    }

    Map<ContractPlatform, int?> defaults(String name, {required bool withCode}) {
      final out = <ContractPlatform, int?>{};
      final node = switch (root['defaults']) {
        final Map<String, Object?> defaults => defaults[name],
        _ => null,
      };
      for (final platform in ContractPlatform.values) {
        final where = '$path: defaults.$name.${platform.name}';
        final row = node is Map<String, Object?> ? node[platform.name] : null;
        if (row is! Map<String, Object?>) {
          problems.add('$where is missing');
          continue;
        }
        checkSource(where, row);
        final code = row['code'];
        if (withCode && code is! int) problems.add('$where: no code');
        out[platform] = code is int ? code : null;
      }
      return out;
    }

    final notActivated = defaults('not_activated', withCode: true);
    final params = defaults('params', withCode: true);
    defaults('event_answer', withCode: false);

    final records = <_Record>[];
    final seen = <String>{};
    for (final (i, row) in _list(root, 'expectations', path, problems).indexed) {
      final where = '$path: expectations[$i]';
      if (row is! Map<String, Object?>) {
        problems.add('$where is not a map');
        continue;
      }
      final extra = row.keys.toSet().difference(const {
        'method',
        'platform',
        'case',
        'kind',
        'path',
        'outcome',
        'reason',
        'source',
      });
      if (extra.isNotEmpty) problems.add('$where: unknown keys ${extra.join(', ')}');
      checkSource(where, row);
      try {
        final record = _Record(
          index: i,
          method: _string(row, 'method'),
          platform: ContractPlatform.parse(_string(row, 'platform')),
          caseName: row['case'] as String?,
          kind: _kind(row['kind'] as String?),
          path: row['path'] as String?,
          outcome: _outcome(row['outcome']),
        );
        if ((record.kind == null) != (record.path == null)) {
          problems.add('$where: kind and path go together');
        }
        final key = '${record.method} ${record.platform.name} ${record.caseName} ${record.kind} ${record.path}';
        if (!seen.add(key)) problems.add('$where: the same case is recorded twice');
        records.add(record);
      } on Object catch (e) {
        problems.add('$where: ${e is FormatException ? e.message : e}');
      }
    }

    final sensitivity = <String, _Sensitivity>{};
    for (final (i, row) in _list(root, 'sensitivity', path, problems).indexed) {
      final where = '$path: sensitivity[$i]';
      if (row is! Map<String, Object?>) {
        problems.add('$where is not a map');
        continue;
      }
      final extra = row.keys.toSet().difference(const {
        'method',
        'platform',
        'sensitivity',
        'insensitive_fields',
        'unobservable_fields',
        'reason',
        'source',
      });
      if (extra.isNotEmpty) problems.add('$where: unknown keys ${extra.join(', ')}');
      checkSource(where, row);
      try {
        final method = _string(row, 'method');
        final platform = ContractPlatform.parse(_string(row, 'platform'));
        final value = _string(row, 'sensitivity');
        final mode = _Mode.values.where((m) => m.name == value).firstOrNull;
        if (mode == null) throw FormatException('sensitivity is $value');
        Map<String, int> fieldsOf(String key) {
          final fields = <String, int>{};
          for (final (j, field) in ((row[key] as List<Object?>?) ?? const <Object?>[]).indexed) {
            if (field is! Map<String, Object?>) throw FormatException('$key[$j] is not a map');
            fields['${_kind(_string(field, 'kind'))} ${_string(field, 'path')}'] = j;
          }
          return fields;
        }

        final fields = fieldsOf('insensitive_fields');
        final unobservable = fieldsOf('unobservable_fields');
        if (mode != _Mode.decodes && (fields.isNotEmpty || unobservable.isNotEmpty)) {
          throw FormatException('a method that is $value lists no fields');
        }
        if (fields.keys.toSet().intersection(unobservable.keys.toSet()) case final both when both.isNotEmpty) {
          throw FormatException('${both.join(', ')} is both insensitive and unobservable');
        }
        if (sensitivity.containsKey('$method ${platform.name}')) throw FormatException('$method is listed twice');
        sensitivity['$method ${platform.name}'] = _Sensitivity(
          index: i,
          method: method,
          platform: platform,
          mode: mode,
          insensitiveFields: fields,
          unobservableFields: unobservable,
        );
      } on Object catch (e) {
        problems.add('$where: ${e is FormatException ? e.message : e}');
      }
    }

    final afterProbe = <(ContractPlatform, BundleCase)>[];
    final afterIds = <String>{};
    final afterRows = root['after_probe'] == null ? const <Object?>[] : _list(root, 'after_probe', path, problems);
    for (final (i, row) in afterRows.indexed) {
      final where = '$path: after_probe[$i]';
      if (row is! Map<String, Object?>) {
        problems.add('$where is not a map');
        continue;
      }
      final extra = row.keys.toSet().difference(const {
        'id',
        'platform',
        'method',
        'arguments',
        'outcome',
        'reason',
        'source',
      });
      if (extra.isNotEmpty) problems.add('$where: unknown keys ${extra.join(', ')}');
      checkSource(where, row);
      try {
        final id = _string(row, 'id');
        final platform = ContractPlatform.parse(_string(row, 'platform'));
        final arguments = _string(row, 'arguments');
        try {
          jsonDecode(arguments);
        } on FormatException {
          throw const FormatException('the arguments are not JSON');
        }
        if (!afterIds.add('${platform.name} $id')) throw FormatException('$id is listed twice');
        afterProbe.add((
          platform,
          BundleCase(
            id: id,
            method: _string(row, 'method'),
            arguments: arguments,
            expected: _outcome(row['outcome']),
            basis: Basis.record,
          ),
        ));
      } on Object catch (e) {
        problems.add('$where: ${e is FormatException ? e.message : e}');
      }
    }

    if (problems.isNotEmpty) throw BundleProblems(problems);
    final probed = root['probed'];
    final iosSha = probed is Map<String, Object?> ? probed['ios_sha'] : null;
    return Expectations._(path, notActivated, params, records, sensitivity, iosSha is String ? iosSha : '', afterProbe);
  }

  /// The calls the probe makes after all cases, in the order of the file, with their platform.
  final List<(ContractPlatform, BundleCase)> _afterProbe;

  /// The iOS SDK the rows were recorded on (`probed.ios_sha`); empty before they are.
  final String probedIosSha;

  final String path;
  final Map<ContractPlatform, int?> _notActivated;
  final Map<ContractPlatform, int?> _params;
  final List<_Record> _records;
  final Map<String, _Sensitivity> _sensitivity;

  /// The records that match a case: the one of its own case, then the one of every case of the method; the first
  /// gives the outcome.
  List<_Record> _matching(String method, ContractPlatform platform, String caseName, String? kind, String? path) {
    _Record? find(String? ofCase) => _records
        .where(
          (r) =>
              r.method == method && r.platform == platform && r.caseName == ofCase && r.kind == kind && r.path == path,
        )
        .firstOrNull;
    return [?find(caseName), ?find(null)];
  }
}

List<Object?> _list(Map<String, Object?> root, String key, String path, List<String> problems) {
  final value = root[key];
  if (value is List<Object?>) return value;
  problems.add('$path: $key is not a list');
  return const [];
}

String _string(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('no $key');
}

const _variantKinds = {MutantKind.removeRequired, MutantKind.swapType, MutantKind.foreignEnum};

String? _kind(String? name) {
  if (name == null) return null;
  if (_variantKinds.any((k) => k.wireName == name)) return name;
  throw FormatException('unknown kind $name');
}

Outcome _outcome(Object? node) => switch (node) {
  'success' => const SuccessOutcome(),
  'native_exception' => const NativeExceptionOutcome(),
  'timeout' => const TimeoutOutcome(),
  {'error': {'code': final int code, 'class': final String messageClass}} => ErrorOutcome(
    code,
    MessageClass.parse(messageClass),
  ),
  _ => throw FormatException('unknown outcome $node'),
};

/// The names of the requests the SDK sends, as [methodSource] (`lib/src/constants/method.dart`) declares them in its
/// enums of methods and of answers to events.
Set<String> sdkMethodsFrom(String methodSource) {
  final names = <String>{};
  for (final enumName in const ['NativeMethod', 'NativeEventResponse']) {
    final start = RegExp('enum\\s+$enumName\\b[^{]*\\{').firstMatch(methodSource);
    if (start == null) throw FormatException('the SDK declares no enum $enumName');
    final end = methodSource.indexOf(';', start.end);
    for (final match in RegExp(r"\w+\('([a-z_]+)'\)").allMatches(methodSource.substring(start.end, end))) {
      names.add(match.group(1)!);
    }
  }
  return names;
}

/// The name of the adapty channel as [transportSource] declares it.
String channelNameFrom(String transportSource) {
  final match = RegExp(r"const\s+String\s+adaptyChannelName\s*=\s*'([^']+)'\s*;").firstMatch(transportSource);
  if (match == null) throw const FormatException('the transport does not declare adaptyChannelName');
  return match.group(1)!;
}

/// [value] with the placeholder of the SDK version replaced by [sdkVersion].
Object? _filled(Object? value, String sdkVersion) => switch (value) {
  sdkVersionPlaceholder => sdkVersion,
  Map<String, Object?>() => {for (final MapEntry(:key, :value) in value.entries) key: _filled(value, sdkVersion)},
  List<Object?>() => [for (final item in value) _filled(item, sdkVersion)],
  _ => value,
};

/// [payload] without the values at [paths] (JSON Pointers).
Object? _without(Object? payload, Iterable<String> paths) {
  final copy = jsonDecode(jsonEncode(payload));
  for (final path in paths) {
    final segments = path.split('/').skip(1).map((s) => s.replaceAll('~1', '/').replaceAll('~0', '~')).toList();
    if (segments.isEmpty) continue;
    Object? node = copy;
    for (final segment in segments.take(segments.length - 1)) {
      node = node is List ? node[int.parse(segment)] : (node! as Map)[segment];
    }
    if (node is Map) node.remove(segments.last);
  }
  return copy;
}

/// The bundle of the golden requests of [corpus] against [schema]: on each platform that handles a
/// method, each of its cases (the file of the platform, else the shared one) with the SDK version filled
/// in, and the payloads derived from it that remove a required field, swap a type or put an unknown
/// constant (the keys the baseline accepts on the platform left out). A method of [denylist] is skipped.
/// Outcomes come from [expectations]; in a strict bundle ([discover] false) a UI method without a
/// recorded outcome, and a method and platform with broken payloads and no sensitivity, stop the bundle;
/// in discovery they are observed.
L2aBundle buildBundle({
  required ContractSchema schema,
  required Corpus corpus,
  required String sdkVersion,
  required String channelName,
  required Denylist denylist,
  required Expectations expectations,
  required PlatformViewCases views,
  required Set<String> sdkMethods,
  bool discover = false,
}) {
  final problems = <String>[];
  final requests = schema.requestMethods.toSet();
  for (final method in denylist.reasons.keys) {
    if (!requests.contains(method)) problems.add('${denylist.path}: $method is not a request of the contract');
  }
  final baseline = baselineItems(corpus.baseline);
  final eventAnswers = eventAnswerMethods(schema);
  final requestCases = {
    for (final f in corpus.fixtures)
      if (f.kind == CorpusKind.request) (f.name, f.caseName),
  }.toList()..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));

  Outcome missing(String what) {
    if (!discover) problems.add('${expectations.path}: $what');
    return const ObserveOutcome();
  }

  final usedRecords = <int>{};
  final usedSensitivity = <int>{};
  final usedFields = <String>{};

  /// The recorded outcome of a case; every record that matches it is used.
  Outcome? recorded(String method, ContractPlatform platform, String caseName, String? kind, String? path) {
    final matching = expectations._matching(method, platform, caseName, kind, path);
    usedRecords.addAll(matching.map((r) => r.index));
    return matching.firstOrNull?.outcome;
  }

  final cases = <ContractPlatform, List<BundleCase>>{};
  for (final platform in ContractPlatform.values) {
    final out = cases[platform] = [];
    final withoutSensitivity = <String>{};

    /// The sensitivity of [method] on the platform, which is then used; a strict bundle stops without one.
    _Sensitivity? sensitivityOf(String method) {
      final sensitivity = expectations._sensitivity['$method ${platform.name}'];
      if (sensitivity != null) usedSensitivity.add(sensitivity.index);
      if (sensitivity == null && withoutSensitivity.add(method) && !discover) {
        problems.add('${expectations.path}: no sensitivity for $method on ${platform.name}');
      }
      return sensitivity;
    }

    for (final (method, caseName) in requestCases) {
      if (!(schema.methodPlatforms[method]?.contains(platform) ?? false)) continue;
      final fixture = corpus.fixture(CorpusKind.request, method, caseName, platform);
      if (fixture == null) continue;
      final id = '$method/$caseName';
      final payload = _filled(fixture.payload, sdkVersion);
      final arguments = jsonEncode(payload);
      if (denylist.reasons[method] case final String reason) {
        out.add(
          BundleCase(id: id, method: method, arguments: arguments, expected: SkipOutcome(reason), basis: Basis.denied),
        );
        continue;
      }
      final check = checkRequest(
        schema,
        baseline,
        method: method,
        arguments: payload is Map<String, Object?> ? payload : null,
        platform: platform,
        declaredCase: id,
      );
      if (check == null) {
        problems.add('${fixture.path}: $method is not a request of the contract');
        continue;
      }
      if (fixture.isNegative) {
        final negative = _negativeCase(fixture, platform, check, problems);
        if (negative == null) continue;
        final (kind, path) = negative;
        final sensitivity = sensitivityOf(method);
        final (expected, basis) = switch (recorded(method, platform, caseName, kind, path)) {
          final Outcome outcome => (outcome, Basis.record),
          null when kind == null => (const ObserveOutcome(), Basis.undecided),
          null => _brokenOutcome(sensitivity, kind, path, expectations, platform, usedFields),
        };
        out.add(
          BundleCase(
            id: id,
            method: method,
            arguments: arguments,
            expected: expected,
            basis: basis,
            variant: kind ?? (fixture.expect!['violation']! as Map<String, Object?>)['keyword']! as String,
            instancePath: path,
          ),
        );
        continue;
      }
      if (check.kept.isNotEmpty) {
        problems.add('${fixture.path} on ${platform.name}: ${check.kept.join('; ')}');
        continue;
      }

      final (golden, goldenBasis) = switch (recorded(method, platform, caseName, null, null)) {
        final Outcome outcome => (outcome, Basis.record),
        null when eventAnswers.contains(method) => (const SuccessOutcome(), Basis.byDefault),
        null when method.startsWith('adapty_ui_') => (
          missing('no expectation for $method on ${platform.name} (case $caseName)'),
          Basis.undecided,
        ),
        null => (ErrorOutcome(expectations._notActivated[platform]!, MessageClass.other), Basis.byDefault),
      };
      out.add(BundleCase(id: id, method: method, arguments: arguments, expected: golden, basis: goldenBasis));

      final List<NegativeVariant> variants;
      try {
        variants = negativeVariants(
          check.entry,
          _without(payload, check.taken.map((t) => t.$1.instancePath)),
          platform,
          kinds: _variantKinds,
        );
      } on ArgumentError catch (e) {
        problems.add('${fixture.path} on ${platform.name}: ${e.message}');
        continue;
      }
      if (variants.isEmpty) continue;
      final sensitivity = sensitivityOf(method);
      final ids = <String>{};
      for (final variant in variants) {
        final kind = variant.kind.wireName;
        var variantId = '$id/$kind${variant.instancePath}';
        for (var n = 2; !ids.add(variantId); n++) {
          variantId = '$id/$kind${variant.instancePath}#$n';
        }
        final (expected, basis) = switch (recorded(method, platform, caseName, kind, variant.instancePath)) {
          final Outcome outcome => (outcome, Basis.record),
          null => _brokenOutcome(sensitivity, kind, variant.instancePath, expectations, platform, usedFields),
        };
        out.add(
          BundleCase(
            id: variantId,
            method: method,
            arguments: jsonEncode(variant.instance),
            expected: expected,
            variant: kind,
            instancePath: variant.instancePath,
            basis: basis,
          ),
        );
      }
    }
  }
  problems.addAll(_unusedRows(expectations, denylist, usedRecords, usedSensitivity, usedFields));
  for (final (platform, c) in expectations._afterProbe) {
    final arguments = jsonDecode(c.arguments);
    final check = checkRequest(
      schema,
      baseline,
      method: c.method,
      arguments: arguments is Map<String, Object?> ? arguments : null,
      platform: platform,
    );
    if (check != null && check.kept.isNotEmpty) {
      problems.add('${expectations.path}: after_probe ${c.id} on ${platform.name}: ${check.kept.join('; ')}');
    }
  }
  if (problems.isNotEmpty) throw BundleProblems(problems);
  return L2aBundle(
    channelName: channelName,
    discover: discover,
    cases: cases,
    probedIosSha: expectations.probedIosSha,
    contractMethods: {
      for (final platform in ContractPlatform.values)
        platform: [
          for (final method in schema.requestMethods.toList()..sort())
            if ((schema.methodPlatforms[method]?.contains(platform) ?? false) && sdkMethods.contains(method)) method,
        ],
    },
    afterProbe: {
      for (final platform in ContractPlatform.values)
        platform: [
          for (final (p, c) in expectations._afterProbe)
            if (p == platform) c,
        ],
    },
    views: {
      for (final platform in ContractPlatform.values)
        platform: [
          for (final (view, caseName) in {
            for (final c in views.cases) (c.name, c.caseName),
          }.toList()..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2)))
            if (views.fixture(view, caseName, platform) case final fixture?)
              ViewCase(id: '$view/$caseName', viewType: 'adaptyui_$view', params: jsonEncode(fixture.payload)),
        ],
    },
  );
}

/// The default outcome on [platform] of a payload broken by [kind] at [path] under [sensitivity], with its basis:
/// observed without a sensitivity (undecided), for an insensitive method and at an insensitive field; not activated
/// for an unobservable method and at an unobservable field; else refused as bad params. A field that gives the outcome
/// is used, as `<row>/<list>/<field>` in [usedFields].
(Outcome, Basis) _brokenOutcome(
  _Sensitivity? sensitivity,
  String kind,
  String path,
  Expectations expectations,
  ContractPlatform platform,
  Set<String> usedFields,
) {
  final notActivated = ErrorOutcome(expectations._notActivated[platform]!, MessageClass.other);
  switch (sensitivity?.mode) {
    case null:
      return (const ObserveOutcome(), Basis.undecided);
    case _Mode.insensitive:
      return (const ObserveOutcome(), Basis.insensitive);
    case _Mode.unobservable:
      return (notActivated, Basis.unobservable);
    case _Mode.decodes:
  }
  if (sensitivity!.insensitiveFields['$kind $path'] case final int field) {
    usedFields.add('${sensitivity.index}/i/$field');
    return (const ObserveOutcome(), Basis.insensitive);
  }
  if (sensitivity.unobservableFields['$kind $path'] case final int field) {
    usedFields.add('${sensitivity.index}/u/$field');
    return (notActivated, Basis.unobservable);
  }
  return (ErrorOutcome(expectations._params[platform]!, MessageClass.params), Basis.params);
}

/// The rows of [expectations] no case of their platform used, in strict mode and in discovery alike: a row of a
/// denied method, a record that matches no case, a sensitivity of a method and platform without broken payloads and
/// an insensitive or unobservable field that matches no broken payload of its method.
List<String> _unusedRows(
  Expectations expectations,
  Denylist denylist,
  Set<int> usedRecords,
  Set<int> usedSensitivity,
  Set<String> usedFields,
) {
  final problems = <String>[];
  String unused(String method, ContractPlatform platform, String nothing) => denylist.reasons.containsKey(method)
      ? '$method is denied, so the row is never used'
      : '$method on ${platform.name} $nothing';
  for (final r in expectations._records) {
    if (usedRecords.contains(r.index)) continue;
    final what = [if (r.caseName != null) 'case ${r.caseName}', if (r.kind != null) '${r.kind} ${r.path}'];
    final nothing = 'matches no case${what.isEmpty ? '' : ' (${what.join(', ')})'}';
    problems.add('${expectations.path}: expectations[${r.index}]: ${unused(r.method, r.platform, nothing)}');
  }
  for (final row in expectations._sensitivity.values.toList()..sort((a, b) => a.index.compareTo(b.index))) {
    if (!usedSensitivity.contains(row.index)) {
      final what = unused(row.method, row.platform, 'matches no broken payload');
      problems.add('${expectations.path}: sensitivity[${row.index}]: $what');
      continue;
    }
    for (final (list, fields) in [
      ('insensitive_fields', row.insensitiveFields),
      ('unobservable_fields', row.unobservableFields),
    ]) {
      for (final MapEntry(key: field, value: j) in fields.entries) {
        if (usedFields.contains('${row.index}/${list[0]}/$j')) continue;
        problems.add(
          '${expectations.path}: sensitivity[${row.index}].$list[$j]: '
          '$field matches no broken payload of ${row.method} on ${row.platform.name}',
        );
      }
    }
  }
  return problems;
}

/// The kinds of broken payloads that a violation of a negative request fixture stands for, by its keyword.
const _kindOfKeyword = {
  'required': 'remove_required',
  'type': 'swap_type',
  'enum': 'foreign_enum',
  'const': 'foreign_enum',
};

/// How the negative request [fixture] is broken on [platform], as the kind of broken payload its violation stands
/// for (null for a keyword no kind stands for) and the path of the field: the contract has to report exactly the
/// violation its `expect` names ([check]), else the fixture goes to [problems] and the result is null.
(String?, String)? _negativeCase(
  CorpusFixture fixture,
  ContractPlatform platform,
  RequestCheck check,
  List<String> problems,
) {
  final named = fixture.expect!['violation'];
  if (named is! Map<String, Object?>) {
    problems.add('${fixture.path}: expect names no violation, so the probe cannot tell how the request is broken');
    return null;
  }
  final keyword = named['keyword']! as String, pointer = named['pointer']! as String;
  final kept = check.kept;
  if (kept.length != 1 || kept.single.keyword != keyword || !kept.single.pointsAt(pointer)) {
    problems.add(
      '${fixture.path} on ${platform.name}: expect names $keyword at $pointer, '
      'the contract reports ${kept.isEmpty ? 'nothing' : kept.join('; ')}',
    );
    return null;
  }
  final violation = kept.single;
  final missing = RegExp(r'^missing "([^"]+)"$').firstMatch(violation.detail);
  if (keyword == 'required' && missing == null) {
    problems.add(
      '${fixture.path} on ${platform.name}: a negative fixture removes one required key, '
      'this one removes more (${violation.detail})',
    );
    return null;
  }
  final path = keyword == 'required' && missing != null
      ? '${violation.instancePath}/${escapePointerSegment(missing.group(1)!)}'
      : violation.instancePath;
  return (_kindOfKeyword[keyword], path);
}

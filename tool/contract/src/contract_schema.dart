/// The bridge contract: requests Dart sends, responses and events the native side sends, checked per
/// platform.
library;

import 'dart:io';

import 'contract_source.dart';
import 'json_pointer.dart';
import 'overlays.dart';
import 'schema_validator.dart';

export 'overlays.dart' show ContractOverlays, ContractPlatform;
export 'schema_validator.dart' show ContractShapeError, SchemaVisit, ValidationMode, Violation;

/// One request, response or event of the contract.
final class SchemaEntry {
  const SchemaEntry({required this.schema, required this.name, required this.pointer, required this.mode, this.method});

  final ContractSchema schema;

  /// The key of the entry in the schema, `GetFlow.Request`; the last pointer segment otherwise.
  final String name;
  final String pointer;
  final ValidationMode mode;

  /// For a request: the method, which the payload of a channel call does not carry and the
  /// validation puts in.
  final String? method;
}

/// The result of one validation.
final class ValidationReport {
  const ValidationReport({required this.entry, required this.platform, required this.violations});

  final SchemaEntry entry;
  final ContractPlatform platform;
  final List<Violation> violations;

  ValidationMode get mode => entry.mode;
  bool get isValid => violations.isEmpty;

  /// The entry, the mode, the platform and every violation, one per line.
  String describe() {
    final head = '${entry.name} (${mode.label}, ${platform.name})';
    if (isValid) return '$head: valid';
    final count = violations.length == 1 ? '1 violation' : '${violations.length} violations';
    return ['$head: $count', for (final v in violations) '  $v'].join('\n');
  }
}

/// The parsed contract with its overlays.
final class ContractSchema {
  /// Parses a schema document given as YAML text.
  factory ContractSchema.fromYaml(String text, {ContractOverlays overlays = const ContractOverlays()}) {
    final root = plainYaml(text);
    if (root is! Map<String, Object?>) throw ContractShapeError('the schema document is not a map');
    final validator = SchemaValidator(root, overlays)..checkShape();
    return ContractSchema._(text, validator);
  }

  /// The schema and the overlays of the repository at [repoRoot]; the schema path comes from
  /// `contract/CONTRACT_SOURCE`.
  static ContractSchema load(String repoRoot) => ContractSchema.fromYaml(
    File(ContractSource.load(repoRoot).schemaPath(repoRoot)).readAsStringSync(),
    overlays: ContractOverlays.load(repoRoot),
  );

  ContractSchema._(this.text, this.validator) {
    for (final MapEntry(:key, :value) in _section(r'$requests').entries) {
      if (!key.endsWith('.Request')) continue;
      _add(_requests, _constOf(value, 'method', r'$requests', key), 'method', r'$requests', key);
    }
    for (final MapEntry(:key, :value) in _section(r'$events').entries) {
      _add(_events, _constOf(value, 'id', r'$events', key), 'id', r'$events', key);
    }
  }

  final _requests = <String, String>{};
  final _events = <String, String>{};

  Map<String, Object?> _section(String name) => (validator.root[name] as Map<String, Object?>?) ?? const {};

  /// Puts the entry [name] of [section] under its [property] constant [value] in [entries]; a second entry with the
  /// same value stops the schema.
  static void _add(Map<String, String> entries, String value, String property, String section, String name) {
    final first = entries[value];
    if (first != null) {
      throw ContractShapeError('#/$section/$name has the $property "$value" of #/$section/$first');
    }
    entries[value] = name;
  }

  static String _constOf(Object? entry, String property, String section, String name) {
    final properties = (entry as Map<String, Object?>)['properties'] as Map<String, Object?>?;
    final value = (properties?[property] as Map<String, Object?>?)?['const'];
    if (value is! String) throw ContractShapeError('#/$section/$name has no $property constant');
    return value;
  }

  /// The raw schema text, for the marker scanner.
  final String text;
  final SchemaValidator validator;

  ContractOverlays get overlays => validator.overlays;

  /// The `method` of every request, in schema order.
  List<String> get requestMethods => _requests.keys.toList();

  /// The `id` of every event, in schema order.
  List<String> get eventIds => _events.keys.toList();

  SchemaEntry requestEntry(String method) {
    final name = _requests[method] ?? (throw ArgumentError.value(method, 'method', 'no request in the contract'));
    return SchemaEntry(
      schema: this,
      name: name,
      pointer: '#/\$requests/${escapePointerSegment(name)}',
      mode: ValidationMode.requestClosed,
      method: method,
    );
  }

  SchemaEntry responseEntry(String method) {
    final name = requestEntry(method).name.replaceFirst(RegExp(r'\.Request$'), '.Response');
    if (!_section(r'$requests').containsKey(name)) {
      throw ArgumentError.value(method, 'method', 'no response in the contract');
    }
    return SchemaEntry(
      schema: this,
      name: name,
      pointer: '#/\$requests/${escapePointerSegment(name)}',
      mode: ValidationMode.responseOpen,
    );
  }

  SchemaEntry eventEntry(String id) {
    final name = _events[id] ?? (throw ArgumentError.value(id, 'id', 'no event in the contract'));
    return SchemaEntry(
      schema: this,
      name: name,
      pointer: '#/\$events/${escapePointerSegment(name)}',
      mode: ValidationMode.responseOpen,
    );
  }

  /// Any node of the schema as an entry, for example the `success` value of a response.
  SchemaEntry entryAt(String pointer, ValidationMode mode) {
    validator.resolve(pointer);
    return SchemaEntry(schema: this, name: pointer.split('/').last, pointer: pointer, mode: mode);
  }

  /// The platforms that handle each method; both, unless `platform_methods` says otherwise.
  Map<String, Set<ContractPlatform>> get methodPlatforms => _platformsOf(requestMethods, isEvent: false);

  /// The platforms that send each event; both, unless `platform_methods` says otherwise.
  Map<String, Set<ContractPlatform>> get eventPlatforms => _platformsOf(eventIds, isEvent: true);

  Map<String, Set<ContractPlatform>> _platformsOf(List<String> names, {required bool isEvent}) {
    final rows = {
      for (final row in overlays.platformMethods)
        if (row.isEvent == isEvent) row.name: row.platforms,
    };
    return {for (final name in names) name: rows[name] ?? ContractPlatform.values.toSet()};
  }

  Object? resolve(String pointer) => validator.resolve(pointer);

  /// The violations of [instance] against [entry]; [onVisit] gets every schema node the payload
  /// matched (see [SchemaValidator.validate]).
  ValidationReport validate(
    SchemaEntry entry,
    Object? instance, {
    required ContractPlatform platform,
    SchemaVisit? onVisit,
  }) {
    final normalized = normalizeJson(instance);
    final payload = entry.method != null && normalized is Map<String, Object?>
        ? {...normalized, 'method': entry.method}
        : normalized;
    return ValidationReport(
      entry: entry,
      platform: platform,
      violations: validator.validate(payload, entry.pointer, mode: entry.mode, platform: platform, onVisit: onVisit),
    );
  }

  ValidationReport validateRequest(String method, Map<String, Object?> args, {required ContractPlatform platform}) =>
      validate(requestEntry(method), args, platform: platform);

  ValidationReport validateResponse(String method, Object? payload, {required ContractPlatform platform}) =>
      validate(responseEntry(method), payload, platform: platform);

  ValidationReport validateEvent(String id, Object? payload, {required ContractPlatform platform}) =>
      validate(eventEntry(id), payload, platform: platform);
}

/// The values that match more than one branch of the `oneOf` at [pointer]: candidates are the
/// constants and enum values of its branches. Empty when the branches do not overlap on them.
List<Object?> overlappingBranches(ContractSchema schema, String pointer) {
  final node = schema.resolve(pointer) as Map<String, Object?>;
  final branches = (node['oneOf'] ?? node['anyOf']) as List<Object?>? ?? const [];
  final combinator = node.containsKey('oneOf') ? 'oneOf' : 'anyOf';
  final candidates = <Object?>{
    for (final branch in branches.cast<Map<String, Object?>>()) ...[
      if (branch.containsKey('const')) branch['const'],
      ...?(branch['enum'] as List<Object?>?),
    ],
  };
  bool matches(Object? value, int i) => schema.validator
      .validate(value, '$pointer/$combinator/$i', mode: ValidationMode.responseOpen, platform: ContractPlatform.ios)
      .isEmpty;
  return [
    for (final value in candidates)
      if ([
            for (var i = 0; i < branches.length; i++)
              if (matches(value, i)) i,
          ].length >
          1)
        value,
  ];
}

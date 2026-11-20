/// What the corpus of the contract has to show of the schema: every property, every branch of a
/// `oneOf`/`anyOf` and every value of an `enum`/`const` a native writes in a response the SDK reads
/// or an event, in a positive fixture of that platform, or a row of `contract/coverage_exceptions.yaml`
/// that says why no fixture does.
///
/// The check asks for a value to be there; it does not ask for one to be absent: that a native
/// leaves an optional field out is for the fixtures that leave it out to show.
library;

import 'dart:convert';
import 'dart:io';

import 'contract_schema.dart';
import 'corpus.dart';
import 'overlays.dart' show plainYaml;
import 'source_refs.dart';

/// Why no fixture of a platform shows an item.
enum CoverageExceptionKind {
  /// The native of the platform never writes it.
  notWritten('not_written'),

  /// The SDK never makes the call or never gets the event that would carry it.
  notCalled('not_called'),

  /// The native could write it, but no real payload does.
  unrealistic('unrealistic');

  const CoverageExceptionKind(this.wireName);

  final String wireName;
}

/// A row of `contract/coverage_exceptions.yaml`.
final class CoverageException {
  const CoverageException({
    required this.pointer,
    required this.platforms,
    required this.kind,
    required this.reason,
    required this.source,
    this.hasValue = false,
    this.value,
  });

  /// The rows of the file of the repository at [repoRoot]; none when there is no file.
  static List<CoverageException> load(String repoRoot) {
    final file = File('$repoRoot/$path');
    return file.existsSync() ? parse(file.readAsStringSync()) : const [];
  }

  /// The rows of [text], the YAML of the file.
  static List<CoverageException> parse(String text) {
    final list = plainYaml(text);
    if (list == null) return const [];
    if (list is! List<Object?>) throw const FormatException('$path: not a list of rows');
    return [for (final (index, row) in list.indexed) _row('$path row ${index + 1}', row)];
  }

  static const _keys = {'pointer', 'value', 'platforms', 'kind', 'reason', 'source'};

  static CoverageException _row(String where, Object? row) {
    if (row is! Map<String, Object?>) throw FormatException('$where: not a map');
    for (final key in row.keys) {
      if (!_keys.contains(key)) throw FormatException('$where: unknown key "$key"');
    }
    String text(String key) => switch (row[key]) {
      final String value => value,
      _ => throw FormatException('$where: $key is not a text'),
    };
    final platforms = switch (row['platforms']) {
      final List<Object?> names when names.isNotEmpty && names.every((n) => n is String) => {
        for (final name in names.cast<String>()) ContractPlatform.parse(name),
      },
      _ => throw FormatException('$where: platforms is not a list of platforms'),
    };
    final kindName = text('kind');
    final kind = CoverageExceptionKind.values.firstWhere(
      (k) => k.wireName == kindName,
      orElse: () => throw FormatException('$where: unknown kind "$kindName"'),
    );
    return CoverageException(
      pointer: text('pointer'),
      platforms: platforms,
      kind: kind,
      reason: row['reason'] is String ? row['reason']! as String : '',
      source: row['source'] is String ? row['source']! as String : '',
      hasValue: row.containsKey('value'),
      value: row['value'],
    );
  }

  /// The file relative to the repository root.
  static const path = 'contract/coverage_exceptions.yaml';

  /// The property, the branch, or the node with an `enum`/`const` the row is about.
  final String pointer;

  /// Whether the row is about one value of the `enum`/`const` at [pointer]: [value].
  final bool hasValue;
  final Object? value;
  final Set<ContractPlatform> platforms;
  final CoverageExceptionKind kind;
  final String reason;
  final String source;

  /// The item of the row, as [coverageItem] writes it.
  String get item => coverageItem(pointer, hasValue: hasValue, value: value);
}

/// An item of the coverage: the pointer of a property or a branch, or the pointer of a node with
/// one of its `enum`/`const` values.
String coverageItem(String pointer, {bool hasValue = false, Object? value}) =>
    hasValue ? '$pointer = ${jsonEncode(value)}' : pointer;

/// The items a positive fixture of [platform] has to show: those reachable from the response of
/// every method the SDK sends ([sentMethods]) and [platform] handles, and from every event
/// [platform] sends. A node of `$defs` counts once, whatever reaches it; the values of a dictionary
/// are reached and its keys are data. A field or a branch of another platform (as a native fixture
/// reads it) is left out with everything under it.
Set<String> coverageUniverse(ContractSchema schema, ContractPlatform platform, {required Set<String> sentMethods}) {
  final validator = schema.validator;
  final items = <String>{};
  final walked = <String>{};
  void walk(Map<String, Object?> node, String pointer) {
    if (!walked.add(pointer)) return;
    if (node[r'$ref'] case final String ref) walk(validator.resolve(ref)! as Map<String, Object?>, ref);
    if (node.containsKey('const')) items.add(coverageItem(pointer, hasValue: true, value: node['const']));
    for (final value in (node['enum'] as List<Object?>?) ?? const []) {
      items.add(coverageItem(pointer, hasValue: true, value: value));
    }
    final view = validator.objectView(node, pointer, platform, ValidationMode.nativeFixture);
    for (final (propertyPointer, property) in view.properties.values) {
      if (validator.foreignOwners(propertyPointer, platform, withRequired: true) != null) continue;
      items.add(propertyPointer);
      walk(property, propertyPointer);
    }
    for (final keyword in const ['items', 'additionalProperties']) {
      if (node[keyword] case final Map<String, Object?> inner) walk(inner, '$pointer/$keyword');
    }
    for (final combinator in const ['oneOf', 'anyOf']) {
      for (final (index, branch) in ((node[combinator] as List<Object?>?) ?? const []).indexed) {
        final branchPointer = '$pointer/$combinator/$index';
        if (validator.foreignOwners(branchPointer, platform, withRequired: true) != null) continue;
        items.add(branchPointer);
        walk(branch! as Map<String, Object?>, branchPointer);
      }
    }
  }

  for (final MapEntry(key: method, value: platforms) in schema.methodPlatforms.entries) {
    if (!platforms.contains(platform) || !sentMethods.contains(method)) continue;
    final SchemaEntry entry;
    try {
      entry = schema.responseEntry(method);
    } on ArgumentError {
      continue;
    }
    walk(schema.resolve(entry.pointer)! as Map<String, Object?>, entry.pointer);
  }
  for (final MapEntry(key: id, value: platforms) in schema.eventPlatforms.entries) {
    if (!platforms.contains(platform)) continue;
    final entry = schema.eventEntry(id);
    walk(schema.resolve(entry.pointer)! as Map<String, Object?>, entry.pointer);
  }
  return items;
}

/// The items the positive fixtures of [corpus] for [platform] show: their own and the ones both
/// platforms share, of a method [platform] handles or an event it sends, read as a native fixture,
/// counting only fixtures without a violation there.
Set<String> coveredItems(Corpus corpus, ContractSchema schema, ContractPlatform platform) {
  final items = <String>{};
  for (final fixture in corpus.fixtures) {
    if (fixture.isNegative || fixture.kind == CorpusKind.request) continue;
    if (fixture.platform != null && fixture.platform != platform) continue;
    final isEvent = fixture.kind == CorpusKind.event;
    final handled = (isEvent ? schema.eventPlatforms : schema.methodPlatforms)[fixture.name] ?? const {};
    if (!handled.contains(platform)) continue;
    final SchemaEntry entry;
    try {
      entry = isEvent ? schema.eventEntry(fixture.name) : schema.responseEntry(fixture.name);
    } on ArgumentError {
      continue;
    }
    final shown = <String>[];
    final violations = schema.validator.validate(
      fixture.payload,
      entry.pointer,
      mode: ValidationMode.nativeFixture,
      platform: platform,
      onVisit: (pointer, _, {value}) {
        shown.add(pointer);
        final node = schema.resolve(pointer)! as Map<String, Object?>;
        if (node.containsKey('const') || node.containsKey('enum')) {
          shown.add(coverageItem(pointer, hasValue: true, value: value));
        }
      },
    );
    if (violations.isEmpty) items.addAll(shown);
  }
  return items;
}

/// The node every error of the bridge is.
const _errorPointer = r'#/$defs/AdaptyError';

/// A branch of the envelope of a response and its `error`: their value is an [_errorPointer].
final _envelopeError = RegExp(r'^#/\$requests/[^/]+\.Response/(oneOf|anyOf)/\d+(/properties/error)?$');

bool _isEnvelopeError(ContractSchema schema, String item) {
  if (!_envelopeError.hasMatch(item)) return false;
  final branch = item.replaceFirst(RegExp(r'/properties/error$'), '');
  final properties = (schema.resolve(branch)! as Map<String, Object?>)['properties'] as Map<String, Object?>?;
  return (properties?['error'] as Map<String, Object?>?)?[r'$ref'] == _errorPointer;
}

/// Every item of a platform no positive fixture shows and no row of [exceptions] explains, and
/// every row that is wrong; one line each. The error branch of the envelope of a response is shown
/// on a platform when every item of the error is: the envelope is the same for every method, and
/// any of them can answer with an error. A row is wrong when its reason or source is not there
/// (`source` as [sourceProblems] reads it, under [refs] and with the files of this repository
/// under [root]), when its pointer is no node of the schema, when its item is not one its platform
/// has to show, and when a fixture of its platform shows the item.
List<String> schemaCoverageProblems(
  Corpus corpus,
  ContractSchema schema,
  List<CoverageException> exceptions, {
  required Set<String> sentMethods,
  required Set<String> refs,
  String root = '.',
}) {
  final problems = <String>[];
  for (final row in exceptions) {
    final where = 'exception ${row.item}';
    for (final problem in sourceProblems(row.reason, row.source, refs: refs, root: root)) {
      problems.add('$where: $problem');
    }
    try {
      schema.resolve(row.pointer);
    } on ArgumentError {
      problems.add('$where: no such schema node');
    }
  }
  for (final platform in ContractPlatform.values) {
    final universe = coverageUniverse(schema, platform, sentMethods: sentMethods);
    final covered = coveredItems(corpus, schema, platform);
    final excepted = {
      for (final row in exceptions)
        if (row.platforms.contains(platform)) row.item: row,
    };
    for (final MapEntry(key: item, value: row) in excepted.entries) {
      final where = 'exception ${row.item}';
      if (problems.contains('$where: no such schema node')) continue;
      if (!universe.contains(item)) {
        problems.add('$where: not an item ${platform.name} has to show');
      } else if (covered.contains(item)) {
        problems.add('$where: in a positive fixture of ${platform.name} now, remove the row');
      }
    }
    final missing = universe.difference(covered).difference(excepted.keys.toSet());
    final errorShown = !missing.any((item) => item.startsWith('$_errorPointer/'));
    for (final item in missing.toList()..sort()) {
      if (errorShown && _isEnvelopeError(schema, item)) continue;
      problems.add('${platform.name} $item: in no positive fixture');
    }
  }
  return problems;
}

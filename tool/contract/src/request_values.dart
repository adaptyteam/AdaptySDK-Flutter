/// What the golden requests of the corpus have to show of the schema: every value of an `enum` that
/// a request of a method the SDK sends can carry on a platform, reached by `$ref` from its `.Request`
/// entry, in a golden request of that platform, unless a row of `contract/request_value_exceptions.yaml`
/// says why none does.
library;

import 'dart:io';

import 'contract_schema.dart';
import 'corpus.dart';
import 'overlays.dart' show plainYaml;
import 'schema_coverage.dart' show coverageItem;
import 'source_refs.dart';

/// A row of `contract/request_value_exceptions.yaml`: a value of the `enum` at [pointer] that no
/// golden request of [platforms] carries, and why.
final class RequestValueException {
  const RequestValueException({
    required this.pointer,
    required this.value,
    required this.platforms,
    required this.reason,
    required this.source,
  });

  /// The rows of the file of the repository at [repoRoot]; none when there is no file.
  static List<RequestValueException> load(String repoRoot) {
    final file = File('$repoRoot/$path');
    return file.existsSync() ? parse(file.readAsStringSync()) : const [];
  }

  /// The rows of [text], the YAML of the file.
  static List<RequestValueException> parse(String text) {
    final list = plainYaml(text);
    if (list == null) return const [];
    if (list is! List<Object?>) throw const FormatException('$path: not a list of rows');
    return [for (final (index, row) in list.indexed) _row('$path row ${index + 1}', row)];
  }

  static const _keys = {'pointer', 'value', 'platforms', 'reason', 'source'};

  static RequestValueException _row(String where, Object? row) {
    if (row is! Map<String, Object?>) throw FormatException('$where: not a map');
    for (final key in row.keys) {
      if (!_keys.contains(key)) throw FormatException('$where: unknown key "$key"');
    }
    if (!row.containsKey('value')) throw FormatException('$where: no value');
    final pointer = row['pointer'];
    if (pointer is! String) throw FormatException('$where: pointer is not a text');
    final platforms = switch (row['platforms']) {
      final List<Object?> names when names.isNotEmpty && names.every((n) => n is String) => {
        for (final name in names.cast<String>()) ContractPlatform.parse(name),
      },
      _ => throw FormatException('$where: platforms is not a list of platforms'),
    };
    return RequestValueException(
      pointer: pointer,
      value: row['value'],
      platforms: platforms,
      reason: row['reason'] is String ? row['reason']! as String : '',
      source: row['source'] is String ? row['source']! as String : '',
    );
  }

  /// The file relative to the repository root.
  static const path = 'contract/request_value_exceptions.yaml';

  final String pointer;
  final Object? value;
  final Set<ContractPlatform> platforms;
  final String reason;
  final String source;

  /// The item of the row, as [coverageItem] writes it.
  String get item => coverageItem(pointer, hasValue: true, value: value);
}

/// The values a golden request of [platform] has to carry: every value of an `enum` reachable by
/// `$ref` from the request of a method the SDK sends ([sentMethods]) and [platform] handles, as
/// [coverageItem] writes it. A field or a branch of another platform is left out with everything
/// under it.
Set<String> requestValueUniverse(ContractSchema schema, ContractPlatform platform, {required Set<String> sentMethods}) {
  final validator = schema.validator;
  final items = <String>{};
  final walked = <String>{};
  void walk(Map<String, Object?> node, String pointer) {
    if (!walked.add(pointer)) return;
    if (node[r'$ref'] case final String ref) walk(validator.resolve(ref)! as Map<String, Object?>, ref);
    for (final value in (node['enum'] as List<Object?>?) ?? const []) {
      items.add(coverageItem(pointer, hasValue: true, value: value));
    }
    final view = validator.objectView(node, pointer, platform, ValidationMode.requestClosed);
    for (final (propertyPointer, property) in view.properties.values) {
      if (validator.foreignOwners(propertyPointer, platform) != null) continue;
      walk(property, propertyPointer);
    }
    for (final keyword in const ['items', 'additionalProperties']) {
      if (node[keyword] case final Map<String, Object?> inner) walk(inner, '$pointer/$keyword');
    }
    for (final combinator in const ['oneOf', 'anyOf']) {
      for (final (index, branch) in ((node[combinator] as List<Object?>?) ?? const []).indexed) {
        final branchPointer = '$pointer/$combinator/$index';
        if (validator.foreignOwners(branchPointer, platform) != null) continue;
        walk(branch! as Map<String, Object?>, branchPointer);
      }
    }
  }

  for (final MapEntry(key: method, value: platforms) in schema.methodPlatforms.entries) {
    if (!platforms.contains(platform) || !sentMethods.contains(method)) continue;
    final entry = schema.requestEntry(method);
    walk(schema.resolve(entry.pointer)! as Map<String, Object?>, entry.pointer);
  }
  return items;
}

/// The values the golden requests of [corpus] carry on [platform]: its own and the ones both
/// platforms share, of a method the SDK sends ([sentMethods]) and [platform] handles, at the nodes
/// the request matched.
Set<String> requestValuesSent(
  Corpus corpus,
  ContractSchema schema,
  ContractPlatform platform, {
  required Set<String> sentMethods,
}) {
  final items = <String>{};
  for (final fixture in corpus.fixtures) {
    if (fixture.isNegative || fixture.kind != CorpusKind.request || !sentMethods.contains(fixture.name)) continue;
    if (fixture.platform != null && fixture.platform != platform) continue;
    if (!(schema.methodPlatforms[fixture.name] ?? const {}).contains(platform)) continue;
    schema.validate(
      schema.requestEntry(fixture.name),
      fixture.payload,
      platform: platform,
      onVisit: (pointer, _, {value}) {
        final node = schema.resolve(pointer)! as Map<String, Object?>;
        if (node.containsKey('enum')) items.add(coverageItem(pointer, hasValue: true, value: value));
      },
    );
  }
  return items;
}

/// Every value of a platform no golden request carries and no row of [exceptions] explains, and
/// every row that is wrong; one line each. A row is wrong when its reason or source is not there
/// (`source` as [sourceProblems] reads it, under [refs] and with the files of this repository under
/// [root]), when its pointer is no node of the schema, when its value is not one its platform has to
/// send, when a golden request of its platform carries the value, and when another row has the same
/// value on a platform.
List<String> requestValueProblems(
  Corpus corpus,
  ContractSchema schema,
  List<RequestValueException> exceptions, {
  required Set<String> sentMethods,
  required Set<String> refs,
  String root = '.',
}) {
  final problems = <String>[];
  final missingNode = <String>{};
  for (final row in exceptions) {
    final where = 'exception ${row.item}';
    for (final problem in sourceProblems(row.reason, row.source, refs: refs, root: root)) {
      problems.add('$where: $problem');
    }
    try {
      schema.resolve(row.pointer);
    } on ArgumentError {
      problems.add('$where: no such schema node');
      missingNode.add(row.item);
    }
  }
  for (final platform in ContractPlatform.values) {
    final universe = requestValueUniverse(schema, platform, sentMethods: sentMethods);
    final sent = requestValuesSent(corpus, schema, platform, sentMethods: sentMethods);
    final excepted = <String>{};
    for (final row in exceptions) {
      if (!row.platforms.contains(platform)) continue;
      final where = 'exception ${row.item}';
      if (!excepted.add(row.item)) problems.add('$where: more than one row on ${platform.name}');
      if (missingNode.contains(row.item)) continue;
      if (!universe.contains(row.item)) {
        problems.add('$where: not a value ${platform.name} has to send');
      } else if (sent.contains(row.item)) {
        problems.add('$where: in a golden request of ${platform.name} now, remove the row');
      }
    }
    for (final item in universe.difference(sent).difference(excepted).toList()..sort()) {
      problems.add('${platform.name} $item: in no golden request');
    }
  }
  return problems;
}

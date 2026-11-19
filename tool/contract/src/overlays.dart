/// What the contract schema does not say by itself: which fields, methods and events belong to one
/// platform, where a payload may carry null, and the known defects of the schema copy. One YAML
/// file per kind under `contract/overlays/`; every row names its `source`.
library;

import 'dart:io';

import 'package:yaml/yaml.dart';

/// A platform of the bridge.
enum ContractPlatform {
  ios,
  android;

  static ContractPlatform parse(String name) =>
      values.firstWhere((p) => p.name == name, orElse: () => throw FormatException('unknown platform "$name"'));
}

/// A field (or a `oneOf` branch, or a `$defs` entry) of one platform: `platform_required.yaml` and
/// `platform_fields.yaml`.
final class PlatformFieldRow {
  const PlatformFieldRow({
    required this.pointer,
    required this.platforms,
    required this.source,
    this.coveredBy,
    this.finding,
    this.reason,
  });

  /// JSON Pointer of the schema node.
  final String pointer;
  final Set<ContractPlatform> platforms;
  final String source;

  /// The pointer of a field of the same platform this row is nested in. The validator does not
  /// apply such a row: the outer field already belongs to the platform.
  final String? coveredBy;

  /// Set only on a row the schema has no marker for: what is wrong or missing in the schema.
  final String? finding;
  final String? reason;
}

/// A method or an event only some platforms handle: `platform_methods.yaml`.
final class PlatformMethodRow {
  const PlatformMethodRow({
    required this.name,
    required this.isEvent,
    required this.platforms,
    required this.source,
    this.reason,
  });

  /// The `method` of a request or the `id` of an event.
  final String name;
  final bool isEvent;
  final Set<ContractPlatform> platforms;
  final String source;
  final String? reason;
}

/// A row of `lenient_required.yaml` or `nullable.yaml`.
final class PointerNoteRow {
  const PointerNoteRow({required this.pointer, required this.reason, required this.source, required this.finding});

  final String pointer;
  final String reason;
  final String source;
  final String finding;
}

enum SchemaFixKind {
  /// The `oneOf` at the pointer is read as `anyOf`: its branches overlap.
  oneOfToAnyOf('oneOf_to_anyOf'),

  /// The property at the pointer is added to its object: the natives read it, the schema lacks it.
  addProperty('add_property');

  const SchemaFixKind(this.wireName);

  final String wireName;
}

/// A row of `schema_fixes.yaml`.
final class SchemaFixRow {
  const SchemaFixRow({
    required this.pointer,
    required this.kind,
    required this.reason,
    required this.source,
    required this.finding,
    this.schema,
    this.platforms = const {ContractPlatform.ios, ContractPlatform.android},
  });

  final String pointer;
  final SchemaFixKind kind;
  final String reason;
  final String source;
  final String finding;

  /// The schema of the added property ([SchemaFixKind.addProperty] only).
  final Map<String, Object?>? schema;

  /// The platforms the added property is allowed on ([SchemaFixKind.addProperty] only).
  final Set<ContractPlatform> platforms;
}

/// A schema node no rejected payload can be derived for: `no_negative_variants.yaml`.
final class NoNegativeVariantsRow {
  const NoNegativeVariantsRow({required this.pointer, required this.reason});

  final String pointer;
  final String reason;
}

/// All overlays of the contract.
final class ContractOverlays {
  const ContractOverlays({
    this.platformRequired = const [],
    this.platformFields = const [],
    this.platformMethods = const [],
    this.lenientRequired = const [],
    this.nullable = const [],
    this.schemaFixes = const [],
    this.noNegativeVariants = const [],
  });

  /// Directory of the overlay files relative to the repository root.
  static const directory = 'contract/overlays';

  /// Required on the listed platforms only, whatever `required` of the schema says.
  final List<PlatformFieldRow> platformRequired;

  /// Belongs to the listed platforms: a request carrying it on another platform is reported.
  final List<PlatformFieldRow> platformFields;
  final List<PlatformMethodRow> platformMethods;

  /// Required by the schema, but a response may leave it out.
  final List<PointerNoteRow> lenientRequired;

  /// May be null in a payload.
  final List<PointerNoteRow> nullable;
  final List<SchemaFixRow> schemaFixes;
  final List<NoNegativeVariantsRow> noNegativeVariants;

  /// Reads the overlay files of the repository at [repoRoot].
  static ContractOverlays load(String repoRoot) {
    String? read(String name) {
      final file = File('$repoRoot/$directory/$name.yaml');
      return file.existsSync() ? file.readAsStringSync() : null;
    }

    return parse(
      platformRequired: read('platform_required'),
      platformFields: read('platform_fields'),
      platformMethods: read('platform_methods'),
      lenientRequired: read('lenient_required'),
      nullable: read('nullable'),
      schemaFixes: read('schema_fixes'),
      noNegativeVariants: read('no_negative_variants'),
    );
  }

  /// Parses overlay files given as YAML text; a missing file is an empty overlay.
  static ContractOverlays parse({
    String? platformRequired,
    String? platformFields,
    String? platformMethods,
    String? lenientRequired,
    String? nullable,
    String? schemaFixes,
    String? noNegativeVariants,
  }) {
    PlatformFieldRow platformField(_Row r) => PlatformFieldRow(
      pointer: r.string('pointer'),
      platforms: r.platforms('platforms'),
      source: r.string('source'),
      coveredBy: r.optionalString('covered_by'),
      finding: r.optionalString('finding'),
      reason: r.optionalString('reason'),
    );
    PointerNoteRow note(_Row r) => PointerNoteRow(
      pointer: r.string('pointer'),
      reason: r.string('reason'),
      source: r.string('source'),
      finding: r.string('finding'),
    );
    const platformFieldKeys = {'pointer', 'platforms', 'source', 'covered_by', 'finding', 'reason'};
    const noteKeys = {'pointer', 'reason', 'source', 'finding'};

    return ContractOverlays(
      platformRequired: _rows('platform_required', platformRequired, platformFieldKeys, platformField),
      platformFields: _rows('platform_fields', platformFields, platformFieldKeys, platformField),
      platformMethods: _rows(
        'platform_methods',
        platformMethods,
        {'name', 'kind', 'platforms', 'source', 'reason'},
        (r) => PlatformMethodRow(
          name: r.string('name'),
          isEvent: switch (r.string('kind')) {
            'method' => false,
            'event' => true,
            final other => throw FormatException('${r.where}: kind "$other" is neither method nor event'),
          },
          platforms: r.platforms('platforms'),
          source: r.string('source'),
          reason: r.optionalString('reason'),
        ),
      ),
      lenientRequired: _rows('lenient_required', lenientRequired, noteKeys, note),
      nullable: _rows('nullable', nullable, noteKeys, note),
      schemaFixes: _rows(
        'schema_fixes',
        schemaFixes,
        {'pointer', 'kind', 'schema', 'platforms', 'reason', 'source', 'finding'},
        (r) {
          final kindName = r.string('kind');
          final kind = SchemaFixKind.values.firstWhere(
            (k) => k.wireName == kindName,
            orElse: () => throw FormatException('${r.where}: unknown kind "$kindName"'),
          );
          final schema = r.values['schema'];
          if (kind == SchemaFixKind.addProperty && schema is! Map) {
            throw FormatException('${r.where}: add_property needs a schema');
          }
          return SchemaFixRow(
            pointer: r.string('pointer'),
            kind: kind,
            schema: schema is Map ? _plain(schema) as Map<String, Object?> : null,
            platforms: r.values.containsKey('platforms')
                ? r.platforms('platforms')
                : const {ContractPlatform.ios, ContractPlatform.android},
            reason: r.string('reason'),
            source: r.string('source'),
            finding: r.string('finding'),
          );
        },
      ),
      noNegativeVariants: _rows(
        'no_negative_variants',
        noNegativeVariants,
        {'pointer', 'reason'},
        (r) => NoNegativeVariantsRow(pointer: r.string('pointer'), reason: r.string('reason')),
      ),
    );
  }

  static List<T> _rows<T>(String file, String? text, Set<String> keys, T Function(_Row) row) {
    if (text == null) return const [];
    final list = loadYaml(text);
    if (list == null) return const [];
    if (list is! YamlList) throw FormatException('$file: not a list of rows');
    return [
      for (final (index, item) in list.indexed)
        if (item is! YamlMap)
          throw FormatException('$file row ${index + 1}: not a map')
        else
          row(_Row('$file row ${index + 1}', item, keys)),
    ];
  }
}

final class _Row {
  _Row(this.where, YamlMap map, Set<String> keys) : values = {for (final e in map.entries) '${e.key}': e.value} {
    for (final key in values.keys) {
      if (!keys.contains(key)) throw FormatException('$where: unknown key "$key"');
    }
  }

  final String where;
  final Map<String, Object?> values;

  String string(String key) => optionalString(key) ?? (throw FormatException('$where: $key is missing'));

  String? optionalString(String key) {
    final value = values[key];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) throw FormatException('$where: $key is not a text');
    return value;
  }

  Set<ContractPlatform> platforms(String key) {
    final value = values[key];
    if (value is! YamlList || value.isEmpty) throw FormatException('$where: $key is not a list of platforms');
    return {for (final name in value) ContractPlatform.parse('$name')};
  }
}

/// A YAML node as plain Dart maps, lists and scalars.
Object? _plain(Object? node) => switch (node) {
  YamlMap() => {for (final e in node.nodes.entries) '${(e.key as YamlNode).value}': _plain(e.value)},
  YamlList() => [for (final v in node.nodes) _plain(v)],
  YamlScalar() => node.value,
  Map() => {for (final e in node.entries) '${e.key}': _plain(e.value)},
  List() => [for (final v in node) _plain(v)],
  _ => node,
};

/// The parsed YAML document as plain Dart maps, lists and scalars.
Object? plainYaml(String text) => _plain(loadYamlNode(text));

/// Where a platform marker of the schema text sits.
enum MarkerTarget {
  /// A request or an event as a whole.
  entry,

  /// A `$defs` entry as a whole.
  definition,

  /// A property.
  property,

  /// An item of a `required` list.
  requiredItem,

  /// The first line of a `oneOf`/`anyOf` branch.
  branch,
}

/// A platform marker in the raw schema text: `# iOS Only`, `description: "Android Only…"`,
/// `# Required for Android` (case and quotes do not matter).
final class PlatformMarker {
  const PlatformMarker({
    required this.line,
    required this.platform,
    required this.pointer,
    required this.target,
    required this.requiredFor,
  });

  /// 1-based line of the schema text.
  final int line;
  final ContractPlatform platform;

  /// The schema node the marker is about.
  final String pointer;
  final MarkerTarget target;

  /// `Required for <platform>`: required on that platform although not in `required`.
  final bool requiredFor;
}

/// Every platform marker of the schema text, in text order.
List<PlatformMarker> scanPlatformMarkers(String schemaText) {
  final index = _LineIndex(loadYamlNode(schemaText));
  final lines = schemaText.split('\n');
  final markers = <PlatformMarker>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (_requiredForMarker.firstMatch(line) case final match?) {
      final pointer = index.keys[i];
      if (pointer != null) markers.add(_marker(i, match, pointer, requiredFor: true));
    }
    if (_descriptionMarker.firstMatch(line) case final match?) {
      final pointer = index.descriptionOwners[i];
      if (pointer != null) markers.add(_marker(i, match, pointer));
    }
    if (_commentMarker.firstMatch(line) case final match?) {
      // A line that starts a branch may also hold its required list: the marker is the branch's.
      if (index.branches[i] case final branch?) {
        markers.add(_marker(i, match, branch));
      } else if (index.requiredItems[i] case final item?) {
        markers.add(_marker(i, match, item, requiredItem: true));
      } else if (index.keys[i] case final pointer?) {
        markers.add(_marker(i, match, pointer));
      }
    }
  }
  return markers;
}

final _commentMarker = RegExp(r'#\s*(ios|android)\s+only\b', caseSensitive: false);
final _descriptionMarker = RegExp(r'''description:\s*["']?(ios|android)\s+only\b''', caseSensitive: false);
final _requiredForMarker = RegExp(r'#\s*required\s+for\s+(ios|android)\b', caseSensitive: false);
final _branchPointer = RegExp(r'/(oneOf|anyOf)/\d+$');

PlatformMarker _marker(
  int line,
  RegExpMatch match,
  String pointer, {
  bool requiredFor = false,
  bool requiredItem = false,
}) {
  final segments = pointer.split('/');
  final MarkerTarget target;
  if (requiredItem) {
    target = MarkerTarget.requiredItem;
  } else if (_branchPointer.hasMatch(pointer)) {
    target = MarkerTarget.branch;
  } else if (segments.length == 3) {
    target = segments[1] == r'$requests' || segments[1] == r'$events' ? MarkerTarget.entry : MarkerTarget.definition;
  } else {
    target = MarkerTarget.property;
  }
  return PlatformMarker(
    line: line + 1,
    platform: ContractPlatform.parse(match.group(1)!.toLowerCase()),
    pointer: pointer,
    target: target,
    requiredFor: requiredFor,
  );
}

/// What starts on each 0-based line of the schema text.
final class _LineIndex {
  _LineIndex(YamlNode root) {
    _visit(root, '#');
  }

  /// The node of the first mapping key on the line.
  final keys = <int, String>{};

  /// The node a `description` key on the line describes.
  final descriptionOwners = <int, String>{};

  /// The property a `required` list item on the line names.
  final requiredItems = <int, String>{};

  /// The `oneOf`/`anyOf` branch that starts on the line.
  final branches = <int, String>{};

  void _visit(YamlNode node, String pointer) {
    if (node is YamlMap) {
      for (final MapEntry(:key, :value) in node.nodes.entries) {
        final name = '${(key as YamlNode).value}';
        final line = key.span.start.line;
        final child = '$pointer/${name.replaceAll('~', '~0').replaceAll('/', '~1')}';
        keys.putIfAbsent(line, () => child);
        if (name == 'description') descriptionOwners[line] = pointer;
        if (name == 'required' && value is YamlList) {
          for (final item in value.nodes) {
            requiredItems[item.span.start.line] =
                '$pointer/properties/${'${item.value}'.replaceAll('~', '~0').replaceAll('/', '~1')}';
          }
        }
        if ((name == 'oneOf' || name == 'anyOf') && value is YamlList) {
          for (final (i, branch) in value.nodes.indexed) {
            branches.putIfAbsent(branch.span.start.line, () => '$child/$i');
          }
        }
        _visit(value, child);
      }
    } else if (node is YamlList) {
      for (final (i, item) in node.nodes.indexed) {
        _visit(item, '$pointer/$i');
      }
    }
  }
}

/// The overlay row a group of markers asks for.
final class MarkedRow {
  const MarkedRow(this.overlay, this.key, this.platforms);

  /// `platform_methods`, `platform_required` or `platform_fields`.
  final String overlay;

  /// The method or event name for `platform_methods`, the schema pointer otherwise.
  final String key;
  final Set<ContractPlatform> platforms;

  @override
  bool operator ==(Object other) =>
      other is MarkedRow &&
      other.overlay == overlay &&
      other.key == key &&
      other.platforms.length == platforms.length &&
      other.platforms.containsAll(platforms);

  @override
  int get hashCode => Object.hash(overlay, key, Object.hashAllUnordered(platforms));

  @override
  String toString() => '$overlay $key [${(platforms.map((p) => p.name).toList()..sort()).join(', ')}]';
}

/// The overlay rows the markers of the schema text ask for, one per node: several markers of one
/// field make one row.
List<MarkedRow> rowsForMarkers(String schemaText) {
  final root = plainYaml(schemaText);
  Object? at(String pointer) {
    Object? node = root;
    for (final raw in pointer.substring(2).split('/')) {
      final segment = raw.replaceAll('~1', '/').replaceAll('~0', '~');
      node = node is List ? node[int.parse(segment)] : (node as Map)[segment];
    }
    return node;
  }

  final rows = <(String, String), Set<ContractPlatform>>{};
  for (final marker in scanPlatformMarkers(schemaText)) {
    final (overlay, key) = switch (marker.target) {
      MarkerTarget.entry => ('platform_methods', _entryName(at(marker.pointer)! as Map, marker.pointer)),
      MarkerTarget.definition || MarkerTarget.branch => ('platform_fields', marker.pointer),
      MarkerTarget.requiredItem => ('platform_required', marker.pointer),
      MarkerTarget.property when marker.requiredFor => ('platform_required', marker.pointer),
      MarkerTarget.property => (
        _isRequired(at, marker.pointer) ? 'platform_required' : 'platform_fields',
        marker.pointer,
      ),
    };
    (rows[(overlay, key)] ??= {}).add(marker.platform);
  }
  return [
    for (final MapEntry(key: (overlay, key), value: platforms) in rows.entries) MarkedRow(overlay, key, platforms),
  ];
}

String _entryName(Map<Object?, Object?> entry, String pointer) {
  final properties = entry['properties'] as Map?;
  final name = (properties?['method'] ?? properties?['id']) as Map?;
  return name?['const'] as String? ?? (throw FormatException('$pointer has no method or id constant'));
}

bool _isRequired(Object? Function(String) at, String propertyPointer) {
  final at_ = propertyPointer.lastIndexOf('/properties/');
  final object = at(propertyPointer.substring(0, at_)) as Map;
  final name = propertyPointer.substring(at_ + '/properties/'.length).replaceAll('~1', '/').replaceAll('~0', '~');
  return ((object['required'] as List?) ?? const []).contains(name);
}

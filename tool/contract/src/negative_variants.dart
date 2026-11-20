/// Payloads the contract must reject, derived from a valid one: each breaks exactly one rule of the
/// schema by construction, so the validator has to report it.
library;

import 'contract_schema.dart';
import 'schema_validator.dart';

/// How a payload is broken.
enum MutantKind {
  /// A key required on the platform is removed.
  removeRequired('remove_required'),

  /// A value is replaced by one of a JSON type no branch of its node allows.
  swapType('swap_type'),

  /// A value of a node that allows only constants is replaced by an unknown string.
  foreignEnum('foreign_enum'),

  /// An unknown key is added to an object of a request.
  extraKey('extra_key');

  const MutantKind(this.wireName);

  final String wireName;

  static const all = {removeRequired, swapType, foreignEnum, extraKey};
}

/// A payload derived from a valid one that breaks one rule.
final class NegativeVariant {
  const NegativeVariant({
    required this.kind,
    required this.instance,
    required this.instancePath,
    required this.expectedPointer,
  });

  final MutantKind kind;
  final Object? instance;

  /// Where the payload was changed.
  final String instancePath;

  /// The schema node a violation is expected at (see [Violation.pointsAt]): the field for a
  /// changed value, the object for a removed or an added key, and for anything under a
  /// `oneOf`/`anyOf` the node of the outermost combinator.
  final String expectedPointer;

  @override
  String toString() => '${kind.wireName} ${instancePath.isEmpty ? '(payload)' : instancePath} -> $expectedPointer';
}

/// The payloads derived from [validInstance] of [entry] on [platform] that the contract must reject.
/// The `method` of a request is never changed: it comes from the channel call. Throws
/// [ArgumentError] when [validInstance] itself is not valid.
List<NegativeVariant> negativeVariants(
  SchemaEntry entry,
  Object? validInstance,
  ContractPlatform platform, {
  Set<MutantKind> kinds = MutantKind.all,
}) {
  validInstance = normalizeJson(validInstance);
  final report = entry.schema.validate(entry, validInstance, platform: platform);
  if (!report.isValid) throw ArgumentError.value(validInstance, 'validInstance', report.describe());
  final walker = _Walker(entry, platform, kinds, validInstance);
  walker.walk(
    validInstance,
    entry.pointer,
    entry.schema.resolve(entry.pointer) as Map<String, Object?>,
    const [],
    null,
  );
  return walker.out;
}

/// The schema nodes of values (properties, items, values of dictionaries) no negative variant can
/// be derived for, whatever the payload.
List<String> nodesWithoutNegativeVariants(ContractSchema schema) {
  final out = <String>[];
  void visit(Map<String, Object?> node, String pointer, {required bool isValue}) {
    if (isValue && _swapValue(schema, node) == null && !_takesForeignConstant(schema, node)) out.add(pointer);
    if (node['properties'] case final Map<String, Object?> properties) {
      for (final MapEntry(:key, :value) in properties.entries) {
        visit(value as Map<String, Object?>, '$pointer/properties/${escapePointerSegment(key)}', isValue: true);
      }
    }
    for (final keyword in const ['items', 'additionalProperties']) {
      if (node[keyword] case final Map<String, Object?> child) visit(child, '$pointer/$keyword', isValue: true);
    }
    for (final keyword in const ['oneOf', 'anyOf']) {
      if (node[keyword] case final List<Object?> branches) {
        for (final (i, branch) in branches.indexed) {
          visit(branch as Map<String, Object?>, '$pointer/$keyword/$i', isValue: false);
        }
      }
    }
  }

  for (final section in const [r'$requests', r'$events', r'$defs', r'$assets']) {
    final entries = (schema.resolve('#') as Map<String, Object?>)[section] as Map<String, Object?>? ?? const {};
    for (final MapEntry(:key, :value) in entries.entries) {
      visit(value as Map<String, Object?>, '#/$section/${escapePointerSegment(key)}', isValue: false);
    }
  }
  return out;
}

/// The value to put in place of a value of [node]: of a JSON type no branch of the node allows.
/// An integer is never swapped for a number without a fraction: that is an integer too.
Object? _swapValue(ContractSchema schema, Map<String, Object?> node) {
  final types = _typesOf(schema, node);
  if (types == null) return null;
  for (final (type, value) in _swapCandidates) {
    if (types.contains(type) || (type == 'integer' && types.contains('number'))) continue;
    return value;
  }
  return null;
}

const _swapCandidates = [
  ('string', 'swapped value'),
  ('integer', 7),
  ('boolean', true),
  ('array', <Object?>[]),
  ('object', <String, Object?>{}),
];

/// The JSON types [node] allows, or null when it does not say.
Set<String>? _typesOf(ContractSchema schema, Map<String, Object?> node) {
  node = _deref(schema, node);
  if (node['type'] case final String type) return {type};
  if (node.containsKey('const')) return {_jsonType(node['const'])};
  if (node['enum'] case final List<Object?> values) return {for (final v in values) _jsonType(v)};
  for (final keyword in const ['oneOf', 'anyOf']) {
    if (node[keyword] case final List<Object?> branches) {
      final types = <String>{};
      for (final branch in branches) {
        final branchTypes = _typesOf(schema, branch as Map<String, Object?>);
        if (branchTypes == null) return null;
        types.addAll(branchTypes);
      }
      return types;
    }
  }
  if (node.containsKey('properties') || node.containsKey('additionalProperties')) return {'object'};
  if (node.containsKey('items')) return {'array'};
  return null;
}

/// Whether [node] allows strings only from constants, so an unknown string breaks it.
bool _takesForeignConstant(ContractSchema schema, Map<String, Object?> node) =>
    _hasConstant(schema, node) &&
    !_hasFreeString(schema, node) &&
    (_typesOf(schema, node)?.contains('string') ?? false);

bool _hasConstant(ContractSchema schema, Map<String, Object?> node) {
  node = _deref(schema, node);
  if (node.containsKey('const') || node.containsKey('enum')) return true;
  return _branches(node).any((b) => _hasConstant(schema, b));
}

bool _hasFreeString(ContractSchema schema, Map<String, Object?> node) {
  node = _deref(schema, node);
  if (node.containsKey('pattern')) return true;
  final branches = _branches(node);
  if (node['type'] == 'string' && !node.containsKey('const') && !node.containsKey('enum') && branches.isEmpty) {
    return true;
  }
  return branches.any((b) => _hasFreeString(schema, b));
}

List<Map<String, Object?>> _branches(Map<String, Object?> node) => [
  for (final keyword in const ['oneOf', 'anyOf'])
    ...((node[keyword] as List<Object?>?) ?? const []).cast<Map<String, Object?>>(),
];

Map<String, Object?> _deref(ContractSchema schema, Map<String, Object?> node) {
  var ref = node[r'$ref'];
  while (ref is String) {
    node = schema.resolve(ref) as Map<String, Object?>;
    ref = node[r'$ref'];
  }
  return node;
}

String _jsonType(Object? x) => switch (x) {
  bool _ => 'boolean',
  int _ => 'integer',
  double _ => 'number',
  String _ => 'string',
  List _ => 'array',
  Map _ => 'object',
  _ => 'null',
};

const _extraKey = 'key_not_in_the_contract';
const _foreignConstant = 'value not in the contract';

/// Walks a valid payload along its schema and collects the variants.
final class _Walker {
  _Walker(this.entry, this.platform, this.kinds, this.root);

  final SchemaEntry entry;
  final ContractPlatform platform;
  final Set<MutantKind> kinds;
  final Object? root;
  final out = <NegativeVariant>[];

  ContractSchema get schema => entry.schema;
  SchemaValidator get validator => schema.validator;

  /// [x] is the value at [path], checked by [node] at [pointer] (the node as the parent names it,
  /// before any `$ref`). [outer] is the node of the outermost combinator above, if any.
  void walk(Object? x, String pointer, Map<String, Object?> node, List<Object> path, String? outer) {
    final layers = <(String, Map<String, Object?>)>[(pointer, node)];
    var ref = node[r'$ref'];
    while (ref is String) {
      final target = schema.resolve(ref) as Map<String, Object?>;
      layers.add((ref, target));
      ref = target[r'$ref'];
    }
    final matched = <(String, Map<String, Object?>)>[];
    var hasCombinator = false;
    for (final (layerPointer, layer) in layers) {
      for (final keyword in const ['oneOf', 'anyOf']) {
        if (layer[keyword] case final List<Object?> branches) {
          hasCombinator = true;
          for (var i = 0; i < branches.length; i++) {
            final branchPointer = '$layerPointer/$keyword/$i';
            final violations = validator.validate(
              x,
              branchPointer,
              mode: ValidationMode.responseOpen,
              platform: platform,
            );
            if (violations.isEmpty) {
              matched.add((branchPointer, branches[i] as Map<String, Object?>));
              break;
            }
          }
        }
      }
    }
    final objectNode = outer ?? pointer;

    if (x is List<Object?>) {
      final items = [
        for (final (layerPointer, layer) in layers)
          if (layer['items'] case final Map<String, Object?> items) ('$layerPointer/items', items, false),
        for (final (branchPointer, branch) in matched)
          if (branch['items'] case final Map<String, Object?> items) ('$branchPointer/items', items, true),
      ].firstOrNull;
      if (items == null) return;
      // An item of an array a matched branch declares is checked inside that branch: breaking it
      // breaks the combinator of this node.
      final itemOuter = outer ?? (items.$3 ? pointer : null);
      for (var i = 0; i < x.length; i++) {
        _value(x[i], items.$1, items.$2, [...path, i], itemOuter ?? items.$1);
        walk(x[i], items.$1, items.$2, [...path, i], itemOuter);
      }
      return;
    }
    if (x is! Map<String, Object?>) return;

    final required = <String>{};
    final properties = <String, (String, Map<String, Object?>, bool)>{};
    (String, Map<String, Object?>)? additional;
    for (final (layerPointer, layer, fromBranch) in [
      for (final (p, l) in layers) (p, l, false),
      for (final (p, l) in matched) (p, l, true),
    ]) {
      final view = validator.objectView(layer, layerPointer, platform, entry.mode);
      required.addAll(view.required);
      for (final MapEntry(key: name, value: (propertyPointer, propertyNode)) in view.properties.entries) {
        properties.putIfAbsent(name, () => (propertyPointer, propertyNode, fromBranch));
      }
      if (layer['additionalProperties'] case final Map<String, Object?> node) {
        additional ??= ('$layerPointer/additionalProperties', node);
      }
    }
    final isTop = path.isEmpty;
    bool isMethod(String key) => isTop && entry.method != null && key == 'method';

    if (kinds.contains(MutantKind.removeRequired)) {
      for (final name in required) {
        if (isMethod(name) || !x.containsKey(name)) continue;
        _add(MutantKind.removeRequired, [...path, name], objectNode, (object) => (object as Map)..remove(name), path);
      }
    }
    final closed = entry.mode != ValidationMode.responseOpen && properties.isNotEmpty && additional == null;
    if (kinds.contains(MutantKind.extraKey) && closed) {
      _add(MutantKind.extraKey, path, objectNode, (object) => (object as Map)..[_extraKey] = 1, path);
    }
    for (final MapEntry(:key, :value) in x.entries) {
      if (isMethod(key)) continue;
      final property = properties[key];
      final (String, Map<String, Object?>)? child = property == null ? additional : (property.$1, property.$2);
      if (child == null) continue;
      // A key a matched branch declares is checked inside that branch: breaking it breaks the
      // combinator of this node.
      final childOuter = outer ?? (property != null && property.$3 && hasCombinator ? pointer : null);
      _value(value, child.$1, child.$2, [...path, key], childOuter ?? child.$1);
      walk(value, child.$1, child.$2, [...path, key], childOuter);
    }
  }

  void _value(Object? x, String pointer, Map<String, Object?> node, List<Object> path, String expected) {
    if (kinds.contains(MutantKind.swapType)) {
      final swapped = _swapValue(schema, node);
      if (swapped != null) _replace(MutantKind.swapType, path, expected, swapped);
    }
    if (kinds.contains(MutantKind.foreignEnum) && _takesForeignConstant(schema, node)) {
      _replace(MutantKind.foreignEnum, path, expected, _foreignConstant);
    }
  }

  void _replace(MutantKind kind, List<Object> path, String expected, Object? value) {
    final parent = path.sublist(0, path.length - 1);
    final last = path.last;
    _add(kind, path, expected, (object) {
      if (object is Map) object[last] = value;
      if (object is List) object[last as int] = value;
      return object;
    }, parent);
  }

  /// Adds a variant changed at [path]: [change] gets a copy of the value at [target].
  void _add(
    MutantKind kind,
    List<Object> path,
    String expected,
    Object? Function(Object?) change,
    List<Object> target,
  ) {
    final copy = _deepCopy(root);
    Object? holder = copy;
    for (final segment in target) {
      holder = holder is Map ? holder[segment] : (holder as List)[segment as int];
    }
    change(holder);
    out.add(NegativeVariant(kind: kind, instance: copy, instancePath: _instancePath(path), expectedPointer: expected));
  }

  static String _instancePath(List<Object> path) => path.map((s) => '/${escapePointerSegment('$s')}').join();

  static Object? _deepCopy(Object? x) => switch (x) {
    Map() => {for (final e in x.entries) '${e.key}': _deepCopy(e.value)},
    List() => [for (final v in x) _deepCopy(v)],
    _ => x,
  };
}

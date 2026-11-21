/// A validator of the JSON Schema subset the bridge contract uses, with the platform rules of the
/// overlays.
library;

import 'json_pointer.dart';
import 'overlays.dart';

/// How strict a payload is checked.
enum ValidationMode {
  /// What Dart sends: an object may carry only the keys its schema declares (the
  /// `unevaluatedProperties: false` reading: the keys of the node, of its `$ref` target and of the
  /// matched `oneOf`/`anyOf` branch), and a field of another platform is reported.
  requestClosed('request-closed'),

  /// What the native side sends: unknown keys and fields of the other platform are allowed.
  responseOpen('response-open'),

  /// What a fixture of the contract corpus says one native sends: read as a response, but closed
  /// like a request, and a field that belongs to the other platform (a `platform_fields` or a
  /// `platform_required` row without this platform) is reported, since that native never writes it.
  /// This reads a `platform_required` row as "the other native does not write the field", which is
  /// more than "required on this platform only"; every row's source says so, and
  /// `test/contract/overlays_test.dart` keeps it that way.
  nativeFixture('native-fixture');

  const ValidationMode(this.label);

  final String label;
}

/// The schema uses something this validator does not support, or is broken.
final class ContractShapeError extends Error {
  ContractShapeError(this.message);

  final String message;

  @override
  String toString() => 'ContractShapeError: $message';
}

/// One way a payload breaks the schema.
final class Violation {
  const Violation({
    required this.instancePath,
    required this.keyword,
    required this.schemaPointer,
    this.via = const [],
    this.detail = '',
  });

  /// JSON Pointer into the payload; empty for the payload itself.
  final String instancePath;

  /// The schema keyword that failed, or `platform_field`.
  final String keyword;

  /// The schema node the keyword belongs to; for `oneOf`/`anyOf`, the combinator itself.
  final String schemaPointer;

  /// The nodes with a `$ref` the check came through, nearest first.
  final List<String> via;
  final String detail;

  /// Whether this violation is about the schema node at [pointer]: the node of the keyword, that
  /// node without a trailing `/oneOf` or `/anyOf`, or the nearest node of [via]. Farther nodes of
  /// [via] do not count.
  bool pointsAt(String pointer) =>
      pointer == schemaPointer ||
      pointer == schemaPointer.replaceFirst(_combinatorTail, '') ||
      (via.isNotEmpty && pointer == via.first);

  Violation _through(String refNode) => Violation(
    instancePath: instancePath,
    keyword: keyword,
    schemaPointer: schemaPointer,
    via: [...via, refNode],
    detail: detail,
  );

  @override
  String toString() =>
      '${instancePath.isEmpty ? '(payload)' : instancePath}: $keyword at $schemaPointer'
      '${detail.isEmpty ? '' : ' ($detail)'}';
}

final _combinatorTail = RegExp(r'/(oneOf|anyOf)$');

/// The keywords the validator checks.
const supportedKeywords = {
  'type',
  'properties',
  'required',
  r'$ref',
  'const',
  'enum',
  'oneOf',
  'anyOf',
  'items',
  'additionalProperties',
  'pattern',
  'minimum',
  'propertyNames',
};

/// The keywords that do not constrain a value. `nullable` is accepted only as `false`.
const annotationKeywords = {'description', 'default', 'example', 'format', 'title', 'contentEncoding', 'nullable'};

/// [x] with every map whose keys are all strings typed as `Map<String, Object?>` and every list
/// as `List<Object?>`, whatever their static types were (a `{}` literal in an `Object?` position,
/// a decoded message). A map with a key that is not a string keeps its keys, and the validator
/// reports it as not an object.
Object? normalizeJson(Object? x) => switch (x) {
  Map() when x.keys.every((k) => k is String) => <String, Object?>{
    for (final e in x.entries) e.key as String: normalizeJson(e.value),
  },
  Map() => {for (final e in x.entries) e.key: normalizeJson(e.value)},
  List() => <Object?>[for (final v in x) normalizeJson(v)],
  _ => x,
};

/// The pointer of the object a property pointer (`…/properties/<name>`) belongs to, and the name.
(String, String)? splitPropertyPointer(String pointer) {
  final at = pointer.lastIndexOf('/properties/');
  if (at < 0) return null;
  final name = pointer.substring(at + '/properties/'.length);
  if (name.contains('/')) return null;
  return (pointer.substring(0, at), unescapePointerSegment(name));
}

/// A schema node a payload matched: [schemaPointer] is the node, [instancePath] where in the payload,
/// [value] the value checked there.
typedef SchemaVisit = void Function(String schemaPointer, String instancePath, {Object? value});

/// Validates instances against the schema nodes of one parsed schema document.
final class SchemaValidator {
  SchemaValidator(this.root, this.overlays) {
    for (final row in overlays.platformRequired) {
      if (row.coveredBy == null) _platformRequired[row.pointer] = (row.platforms, row.direction);
    }
    for (final row in overlays.platformFields) {
      if (row.coveredBy == null) _platformFields[row.pointer] = row.platforms;
    }
    _lenient.addAll(overlays.lenientRequired.map((r) => r.pointer));
    for (final row in overlays.nullable) {
      (_nullable[row.pointer] ??= []).add((row.platforms, row.direction));
    }
    for (final fix in overlays.schemaFixes) {
      switch (fix.kind) {
        case SchemaFixKind.oneOfToAnyOf:
          _anyOf.add(fix.pointer);
        case SchemaFixKind.addProperty:
          final (object, name) =
              splitPropertyPointer(fix.pointer) ??
              (throw ContractShapeError('an added property needs a …/properties/<name> pointer: ${fix.pointer}'));
          final schema = fix.schema ?? (throw ContractShapeError('an added property has no schema: ${fix.pointer}'));
          (_addedProperties[object] ??= {})[name] = (schema, fix.platforms);
      }
    }
  }

  /// The parsed schema document.
  final Map<String, Object?> root;
  final ContractOverlays overlays;

  final _platformRequired = <String, (Set<ContractPlatform>, OverlayDirection)>{};
  final _platformFields = <String, Set<ContractPlatform>>{};
  final _lenient = <String>{};
  final _nullable = <String, List<(Set<ContractPlatform>, OverlayDirection)>>{};
  final _anyOf = <String>{};
  final _addedProperties = <String, Map<String, (Map<String, Object?>, Set<ContractPlatform>)>>{};

  static const _sections = [r'$requests', r'$events', r'$defs', r'$assets'];

  /// Checks the schema document: every keyword is supported and every `$ref` resolves.
  void checkShape() {
    for (final section in _sections) {
      final entries = root[section];
      if (entries == null) continue;
      if (entries is! Map<String, Object?>) throw ContractShapeError('$section is not a map');
      for (final MapEntry(:key, :value) in entries.entries) {
        _checkNode(value, '#/$section/${escapePointerSegment(key)}');
      }
    }
    for (final MapEntry(key: object, value: added) in _addedProperties.entries) {
      for (final MapEntry(key: name, value: (schema, _)) in added.entries) {
        _checkNode(schema, '$object/properties/${escapePointerSegment(name)}');
      }
    }
  }

  void _checkNode(Object? node, String pointer) {
    if (node is! Map<String, Object?>) throw ContractShapeError('schema node is not a map at $pointer');
    for (final MapEntry(key: keyword, :value) in node.entries) {
      if (keyword == 'nullable' && value != false) {
        throw ContractShapeError("unsupported schema keyword 'nullable: $value' at $pointer");
      }
      if (!supportedKeywords.contains(keyword) && !annotationKeywords.contains(keyword)) {
        throw ContractShapeError("unsupported schema keyword '$keyword' at $pointer");
      }
      switch (keyword) {
        case 'properties':
          for (final MapEntry(:key, value: property) in (value as Map<String, Object?>).entries) {
            _checkNode(property, '$pointer/properties/${escapePointerSegment(key)}');
          }
        case 'items' || 'additionalProperties':
          _checkNode(value, '$pointer/$keyword');
        case 'propertyNames':
          final names = value as Map<String, Object?>;
          for (final inner in names.keys) {
            if (!annotationKeywords.contains(inner)) {
              throw ContractShapeError("unsupported schema keyword '$inner' at $pointer/propertyNames");
            }
          }
        case 'oneOf' || 'anyOf':
          final branches = value as List<Object?>;
          for (var i = 0; i < branches.length; i++) {
            _checkNode(branches[i], '$pointer/$keyword/$i');
          }
        case r'$ref':
          final ref = value as String;
          if (!_tryResolve(ref).$1) throw ContractShapeError("unresolvable \$ref '$ref' at $pointer");
          // Only the four sections are walked here, so a target elsewhere would never be checked.
          if (!_sections.any((section) => ref.startsWith('#/$section/'))) {
            throw ContractShapeError(
              "\$ref '$ref' at $pointer is outside ${_sections.take(3).join(', ')} and ${_sections.last}",
            );
          }
        case 'type':
          if (value is! String || !_types.contains(value)) {
            throw ContractShapeError("unsupported type '$value' at $pointer");
          }
        // The validator reads these by the kind of their value: one of another kind would switch the
        // check off without a word.
        case 'enum':
          if (value is! List<Object?> || !value.every(_isScalar)) {
            throw ContractShapeError('enum is not a list of scalars at $pointer');
          }
        case 'const':
          if (!_isScalar(value)) throw ContractShapeError('const is not a scalar at $pointer');
        case 'pattern':
          if (value is! String || !_compiles(value)) {
            throw ContractShapeError('pattern is not a regular expression at $pointer');
          }
        case 'minimum':
          if (value is! num) throw ContractShapeError('minimum is not a number at $pointer');
        case 'required':
          if (value is! List<Object?> || !value.every((name) => name is String)) {
            throw ContractShapeError('required is not a list of names at $pointer');
          }
      }
    }
  }

  static bool _isScalar(Object? value) => value == null || value is String || value is num || value is bool;

  static bool _compiles(String pattern) {
    try {
      RegExp(pattern);
      return true;
    } on FormatException {
      return false;
    }
  }

  static const _types = {'object', 'array', 'string', 'integer', 'number', 'boolean', 'null'};

  /// The node at a local JSON Pointer (`#/…`).
  Object? resolve(String pointer) {
    final (found, node) = _tryResolve(pointer);
    if (!found) throw ArgumentError.value(pointer, 'pointer', 'no such schema node');
    return node;
  }

  (bool, Object?) _tryResolve(String pointer) {
    if (pointer == '#') return (true, root);
    if (!pointer.startsWith('#/')) return (false, null);
    Object? node = root;
    for (final raw in pointer.substring(2).split('/')) {
      final segment = unescapePointerSegment(raw);
      final index = int.tryParse(segment);
      if (node is Map<String, Object?> && node.containsKey(segment)) {
        node = node[segment];
      } else if (node is List<Object?> && index != null && index >= 0 && index < node.length) {
        node = node[index];
      } else {
        final added = splitPropertyPointer(pointer);
        final schema = added == null ? null : _addedProperties[added.$1]?[added.$2]?.$1;
        return schema == null ? (false, null) : (true, schema);
      }
    }
    return (true, node);
  }

  /// The violations of [instance] against the node at [pointer]. With [asBranch], the node is read as
  /// a branch of a `oneOf`/`anyOf`: the keys of an object at [pointer] are left to the node that holds
  /// it, as the validator does when it chooses a branch.
  List<Violation> validate(
    Object? instance,
    String pointer, {
    required ValidationMode mode,
    required ContractPlatform platform,
    bool asBranch = false,
    SchemaVisit? onVisit,
  }) {
    final out = <Violation>[];
    final check = _Check(this, mode, platform)..visits = onVisit == null ? null : [];
    check.node(
      normalizeJson(instance),
      resolve(pointer) as Map<String, Object?>,
      pointer,
      '',
      out,
      outermost: !asBranch,
    );
    for (final (schemaPointer, instancePath, value) in check.visits ?? const <_Visit>[]) {
      onVisit!(schemaPointer, instancePath, value: value);
    }
    return out;
  }

  /// The required keys of the object node at [pointer] on [platform] (the platform overlay
  /// applied, lenient keys left out in responses), and its declared properties with the added ones.
  ({Set<String> required, Map<String, (String, Map<String, Object?>)> properties}) objectView(
    Map<String, Object?> node,
    String pointer,
    ContractPlatform platform,
    ValidationMode mode,
  ) {
    final properties = <String, (String, Map<String, Object?>)>{
      for (final MapEntry(:key, :value) in ((node['properties'] as Map<String, Object?>?) ?? const {}).entries)
        key: ('$pointer/properties/${escapePointerSegment(key)}', value as Map<String, Object?>),
    };
    for (final MapEntry(key: name, value: (schema, platforms)) in (_addedProperties[pointer] ?? const {}).entries) {
      if (platforms.contains(platform))
        properties[name] = ('$pointer/properties/${escapePointerSegment(name)}', schema);
    }
    final required = {...((node['required'] as List<Object?>?) ?? const []).cast<String>()};
    for (final MapEntry(key: name, value: (propertyPointer, _)) in properties.entries) {
      final platforms = _platformRequiredIn(propertyPointer, mode);
      if (platforms == null) continue;
      platforms.contains(platform) ? required.add(name) : required.remove(name);
    }
    if (mode != ValidationMode.requestClosed) {
      required.removeWhere((name) => _lenient.contains('$pointer/properties/${escapePointerSegment(name)}'));
    }
    return (required: required, properties: properties);
  }

  /// The platforms the node at [pointer] belongs to, when [platform] is not one of them: by a
  /// `platform_fields` row, and with [withRequired] also by a `platform_required` row about what a
  /// native writes.
  Set<ContractPlatform>? foreignOwners(String pointer, ContractPlatform platform, {bool withRequired = false}) {
    final owners =
        _platformFields[pointer] ?? (withRequired ? _platformRequiredIn(pointer, ValidationMode.nativeFixture) : null);
    return owners == null || owners.contains(platform) ? null : owners;
  }

  /// The platforms of the `platform_required` row at [pointer] when the row is about payloads read
  /// in [mode]: what the SDK sends in [ValidationMode.requestClosed], what a native sends otherwise.
  Set<ContractPlatform>? _platformRequiredIn(String pointer, ValidationMode mode) {
    final (platforms, direction) = _platformRequired[pointer] ?? (null, OverlayDirection.both);
    final skipped = mode == ValidationMode.requestClosed ? OverlayDirection.response : OverlayDirection.request;
    return direction == skipped ? null : platforms;
  }

  /// Whether a `nullable` row allows null at [pointer] on [platform] in [mode]: a row about what the
  /// SDK sends applies in [ValidationMode.requestClosed], one about what a native sends in the other
  /// modes.
  bool isNullable(String pointer, ContractPlatform platform, ValidationMode mode) {
    final skipped = mode == ValidationMode.requestClosed ? OverlayDirection.response : OverlayDirection.request;
    return (_nullable[pointer] ?? const []).any((row) => row.$1.contains(platform) && row.$2 != skipped);
  }

  /// Whether the `oneOf` at [pointer] is read as `anyOf`.
  bool readsAsAnyOf(String pointer) => _anyOf.contains(pointer);
}

/// A schema node, an instance path and the value checked there.
typedef _Visit = (String, String, Object?);

/// One validation run: a mode and a platform.
final class _Check {
  _Check(this.validator, this.mode, this.platform);

  final SchemaValidator validator;
  final ValidationMode mode;
  final ContractPlatform platform;

  /// The schema nodes the payload matched so far, when someone asked for them.
  List<_Visit>? visits;

  bool get _closed => mode != ValidationMode.responseOpen;

  Set<ContractPlatform>? _foreignOwners(String pointer) =>
      validator.foreignOwners(pointer, platform, withRequired: mode == ValidationMode.nativeFixture);

  /// Checks [x] against [s] at schema pointer [sp] and instance path [ip]; returns the property
  /// names of an object instance this node evaluated. [outermost] is false for a `$ref` target and
  /// a branch: those report their keys to the node that holds the object, which closes it.
  /// [inForeign] is set inside a subtree that already gave a `platform_field` violation.
  Set<String> node(
    Object? x,
    Map<String, Object?> s,
    String sp,
    String ip,
    List<Violation> out, {
    bool outermost = true,
    bool inForeign = false,
  }) {
    final evaluated = <String>{};
    visits?.add((sp, ip, x));
    if (x == null && validator.isNullable(sp, platform, mode)) return evaluated;
    if (_closed && !inForeign && !_isBranch(sp)) {
      final owners = _foreignOwners(sp);
      if (owners != null) {
        out.add(_platformField(ip, sp, owners));
        inForeign = true;
      }
    }

    if (s[r'$ref'] case final String ref) {
      final inner = <Violation>[];
      evaluated.addAll(
        node(x, validator.resolve(ref) as Map<String, Object?>, ref, ip, inner, outermost: false, inForeign: inForeign),
      );
      out.addAll(inner.map((v) => v._through(sp)));
    }
    if (s['type'] case final String type when !_hasType(type, x)) {
      final keysNotStrings = x is Map && x is! Map<String, Object?>;
      out.add(
        Violation(
          instancePath: ip,
          keyword: 'type',
          schemaPointer: sp,
          detail: keysNotStrings
              ? 'object keys must be strings, got ${x.keys.firstWhere((k) => k is! String)}'
              : 'expected $type, got ${_jsonType(x)}',
        ),
      );
      return evaluated;
    }
    if (s.containsKey('const') && s['const'] != x) {
      out.add(
        Violation(instancePath: ip, keyword: 'const', schemaPointer: sp, detail: 'expected ${s['const']}, got $x'),
      );
    }
    if (s['enum'] case final List<Object?> values when !values.contains(x)) {
      out.add(Violation(instancePath: ip, keyword: 'enum', schemaPointer: sp, detail: 'got $x'));
    }
    if (s['pattern'] case final String pattern when x is String && !RegExp(pattern).hasMatch(x)) {
      out.add(Violation(instancePath: ip, keyword: 'pattern', schemaPointer: sp, detail: 'got "$x"'));
    }
    if (s['minimum'] case final num minimum when x is num && x < minimum) {
      out.add(Violation(instancePath: ip, keyword: 'minimum', schemaPointer: sp, detail: 'got $x'));
    }
    if (x is List<Object?> && s['items'] is Map<String, Object?>) {
      final items = s['items'] as Map<String, Object?>;
      for (var i = 0; i < x.length; i++) {
        node(x[i], items, '$sp/items', '$ip/$i', out, inForeign: inForeign);
      }
    }
    if (x is Map<String, Object?>) {
      evaluated.addAll(_object(x, s, sp, ip, out, inForeign));
    }
    for (final combinator in const ['oneOf', 'anyOf']) {
      if (s[combinator] case final List<Object?> branches) {
        evaluated.addAll(_combinator(x, combinator, branches, sp, ip, out, inForeign));
      }
    }
    if (outermost && _closed && x is Map<String, Object?> && _isObjectSchema(s) && evaluated.isNotEmpty) {
      for (final key in x.keys) {
        if (!evaluated.contains(key)) {
          out.add(
            Violation(
              instancePath: '$ip/${escapePointerSegment(key)}',
              keyword: 'additionalProperties',
              schemaPointer: sp,
              detail: 'unexpected key "$key"',
            ),
          );
        }
      }
    }
    return evaluated;
  }

  Set<String> _object(
    Map<String, Object?> x,
    Map<String, Object?> s,
    String sp,
    String ip,
    List<Violation> out,
    bool inForeign,
  ) {
    final evaluated = <String>{};
    final view = validator.objectView(s, sp, platform, mode);
    final missing = [
      for (final name in view.required)
        if (!x.containsKey(name)) name,
    ];
    if (missing.isNotEmpty) {
      out.add(
        Violation(
          instancePath: ip,
          keyword: 'required',
          schemaPointer: sp,
          detail: 'missing ${missing.map((m) => '"$m"').join(', ')}',
        ),
      );
    }
    for (final MapEntry(key: name, value: (propertyPointer, propertySchema)) in view.properties.entries) {
      evaluated.add(name);
      if (!x.containsKey(name)) continue;
      node(x[name], propertySchema, propertyPointer, '$ip/${escapePointerSegment(name)}', out, inForeign: inForeign);
    }
    if (s['additionalProperties'] case final Map<String, Object?> additional) {
      for (final MapEntry(:key, :value) in x.entries) {
        if (view.properties.containsKey(key)) continue;
        evaluated.add(key);
        node(
          value,
          additional,
          '$sp/additionalProperties',
          '$ip/${escapePointerSegment(key)}',
          out,
          inForeign: inForeign,
        );
      }
    }
    return evaluated;
  }

  Set<String> _combinator(
    Object? x,
    String combinator,
    List<Object?> branches,
    String sp,
    String ip,
    List<Violation> out,
    bool inForeign,
  ) {
    final isAnyOf = combinator == 'anyOf' || validator.readsAsAnyOf(sp);
    final results = <({int index, List<Violation> violations, Set<String> evaluated})>[];
    // Every branch is tried, so the nodes each one matched wait until it is known which branches
    // match: the others must not look matched.
    final outerVisits = visits;
    final branchVisits = <List<_Visit>?>[];
    for (var i = 0; i < branches.length; i++) {
      final violations = <Violation>[];
      visits = outerVisits == null ? null : [];
      final evaluated = node(
        x,
        branches[i] as Map<String, Object?>,
        '$sp/$combinator/$i',
        ip,
        violations,
        outermost: false,
        inForeign: inForeign,
      );
      branchVisits.add(visits);
      results.add((index: i, violations: violations, evaluated: evaluated));
    }
    visits = outerVisits;
    // A field of the other platform does not decide which branch matches; it is reported once the
    // branch is chosen.
    bool matches(List<Violation> violations) => violations.every((v) => v.keyword == 'platform_field');
    final matched = results.where((r) => matches(r.violations)).toList();
    final keyword = isAnyOf ? 'anyOf' : 'oneOf';
    final pointer = '$sp/$combinator';
    if (matched.isEmpty) {
      final nearest = results.reduce((a, b) => _closer(b, a) ? b : a);
      out.add(
        Violation(
          instancePath: ip,
          keyword: keyword,
          schemaPointer: pointer,
          detail: 'no branch matched; nearest branch ${nearest.index}: ${nearest.violations.join('; ')}',
        ),
      );
    } else if (!isAnyOf && matched.length > 1) {
      out.add(
        Violation(
          instancePath: ip,
          keyword: keyword,
          schemaPointer: pointer,
          detail: 'branches ${matched.map((r) => r.index).join(', ')} all match',
        ),
      );
    } else {
      final evaluated = <String>{};
      for (final branch in matched) {
        evaluated.addAll(branch.evaluated);
        out.addAll(branch.violations);
        outerVisits?.addAll(branchVisits[branch.index]!);
        final branchPointer = '$pointer/${branch.index}';
        final owners = _foreignOwners(branchPointer);
        if (_closed && !inForeign && owners != null) out.add(_platformField(ip, branchPointer, owners));
      }
      return evaluated;
    }
    // A combinator that failed is reported once: the keys of all its branches count as evaluated.
    return {for (final r in results) ...r.evaluated};
  }

  /// A branch is nearer when no constant of it failed, then when it has fewer violations.
  static bool _closer(
    ({int index, List<Violation> violations, Set<String> evaluated}) a,
    ({int index, List<Violation> violations, Set<String> evaluated}) b,
  ) {
    bool constFailed(List<Violation> v) => v.any((x) => x.keyword == 'const' || x.keyword == 'enum');
    final aConst = constFailed(a.violations), bConst = constFailed(b.violations);
    if (aConst != bConst) return !aConst;
    return a.violations.length < b.violations.length;
  }

  Violation _platformField(String ip, String sp, Set<ContractPlatform> owners) => Violation(
    instancePath: ip,
    keyword: 'platform_field',
    schemaPointer: sp,
    detail: 'belongs to ${owners.map((p) => p.name).join(', ')}',
  );

  static final _branchPointer = RegExp(r'/(oneOf|anyOf)/\d+$');

  static bool _isBranch(String sp) => _branchPointer.hasMatch(sp);

  static bool _isObjectSchema(Map<String, Object?> s) =>
      s['type'] == 'object' ||
      s.containsKey('properties') ||
      s.containsKey(r'$ref') ||
      s.containsKey('oneOf') ||
      s.containsKey('anyOf');

  static bool _hasType(String type, Object? x) => switch (type) {
    // A map with a key that is not a string is not a JSON object; normalizeJson typed the others.
    'object' => x is Map<String, Object?>,
    'array' => x is List,
    'string' => x is String,
    'boolean' => x is bool,
    // JSON has one kind of number: an integer is a number without a fraction, so 3.0 is one.
    'integer' => x is int || (x is double && x.isFinite && x == x.truncateToDouble()),
    'number' => x is num,
    'null' => x == null,
    _ => throw ContractShapeError("unsupported type '$type'"),
  };

  static String _jsonType(Object? x) => switch (x) {
    null => 'null',
    bool _ => 'boolean',
    int _ => 'integer',
    double _ => 'number',
    String _ => 'string',
    List _ => 'array',
    Map _ => 'object',
    _ => '${x.runtimeType}',
  };
}

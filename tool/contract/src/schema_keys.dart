/// Which keys of a payload the contract describes, and which are data.
library;

import 'contract_schema.dart';
import 'json_pointer.dart';
import 'schema_validator.dart';

/// The keys and objects of one payload as its schema entry sees them on one platform, as JSON Pointer
/// instance paths.
final class SchemaKeys {
  const SchemaKeys({
    required this.described,
    required this.pointers,
    required this.data,
    required this.undescribed,
    required this.closed,
  });

  /// The keys a `properties` of the schema names (with the properties a schema fix adds on the platform).
  final Set<String> described;

  /// The schema pointer of the property each described key is (`#/$defs/AdaptyProfile/properties/profile_id`).
  final Map<String, String> pointers;

  /// The keys of dictionaries (`additionalProperties`): data, not names of fields.
  final Set<String> data;

  /// The keys neither: the schema has no place for them.
  final Set<String> undescribed;

  /// The objects with described keys and no dictionary keys: an unknown key added to one is a key the
  /// contract does not know.
  final Set<String> closed;
}

/// The keys of [instance] read against [entry] on [platform]: under a `oneOf` or an `anyOf`, by the
/// branches the instance matches.
SchemaKeys schemaKeys(SchemaEntry entry, Object? instance, ContractPlatform platform) {
  final pointers = <String, String>{};
  final described = <String>{}, data = <String>{}, undescribed = <String>{}, closed = <String>{};
  final validator = entry.schema.validator;

  /// The node at [pointer], the targets of its `$ref`s and, for each `oneOf`/`anyOf` among them, the
  /// branches [x] matches, with theirs.
  List<(String, Map<String, Object?>)> layersOf(Object? x, String pointer, Map<String, Object?> node) {
    final layers = <(String, Map<String, Object?>)>[(pointer, node)];
    if (node[r'$ref'] case final String ref) {
      layers.addAll(layersOf(x, ref, validator.resolve(ref) as Map<String, Object?>));
    }
    for (final keyword in const ['oneOf', 'anyOf']) {
      if (node[keyword] case final List<Object?> branches) {
        for (var i = 0; i < branches.length; i++) {
          final branchPointer = '$pointer/$keyword/$i';
          final violations = validator.validate(
            x,
            branchPointer,
            mode: ValidationMode.responseOpen,
            platform: platform,
          );
          if (violations.isEmpty) layers.addAll(layersOf(x, branchPointer, branches[i] as Map<String, Object?>));
        }
      }
    }
    return layers;
  }

  void walk(Object? x, String pointer, Map<String, Object?> node, String path) {
    final layers = layersOf(x, pointer, node);
    if (x is List<Object?>) {
      for (final (layerPointer, layer) in layers) {
        if (layer['items'] case final Map<String, Object?> items) {
          for (var i = 0; i < x.length; i++) {
            walk(x[i], '$layerPointer/items', items, '$path/$i');
          }
          return;
        }
      }
      return;
    }
    if (x is! Map<String, Object?>) return;

    final properties = <String, (String, Map<String, Object?>)>{};
    (String, Map<String, Object?>)? additional;
    for (final (layerPointer, layer) in layers) {
      final view = validator.objectView(layer, layerPointer, platform, entry.mode);
      for (final MapEntry(:key, :value) in view.properties.entries) {
        properties.putIfAbsent(key, () => value);
      }
      if (layer['additionalProperties'] case final Map<String, Object?> node) {
        additional ??= ('$layerPointer/additionalProperties', node);
      }
    }
    if (properties.isNotEmpty && additional == null) closed.add(path);
    for (final MapEntry(:key, :value) in x.entries) {
      final keyPath = '$path/${escapePointerSegment(key)}';
      final property = properties[key];
      if (property != null) {
        described.add(keyPath);
        pointers[keyPath] = property.$1;
        walk(value, property.$1, property.$2, keyPath);
      } else if (additional != null) {
        data.add(keyPath);
        walk(value, additional.$1, additional.$2, keyPath);
      } else {
        undescribed.add(keyPath);
      }
    }
  }

  final normalized = normalizeJson(instance);
  walk(normalized, entry.pointer, validator.resolve(entry.pointer) as Map<String, Object?>, '');
  return SchemaKeys(described: described, pointers: pointers, data: data, undescribed: undescribed, closed: closed);
}

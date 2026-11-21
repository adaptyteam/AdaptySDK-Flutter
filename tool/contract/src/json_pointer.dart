/// JSON Pointers of the contract tools: the paths into a payload (`/a/0/b`) and into the schema
/// (`#/a/b`), with `~` and `/` of a key written as `~0` and `~1`.
library;

import 'dart:convert';

/// Escapes one segment of a JSON Pointer.
String escapePointerSegment(String segment) => segment.replaceAll('~', '~0').replaceAll('/', '~1');

/// The key one escaped segment of a JSON Pointer names.
String unescapePointerSegment(String segment) => segment.replaceAll('~1', '/').replaceAll('~0', '~');

/// The keys and indexes [pointer] goes through, unescaped: none for the whole document (`''` or `#`).
List<String> pointerSegments(String pointer) {
  final path = pointer.startsWith('#') ? pointer.substring(1) : pointer;
  return path.split('/').skip(1).map(unescapePointerSegment).toList();
}

/// A copy of [json] without the object keys at [pointers]; a pointer to the whole document or to an item
/// of a list takes nothing away.
Object? withoutPointers(Object? json, Iterable<String> pointers) {
  final copy = jsonDecode(jsonEncode(json));
  for (final pointer in pointers) {
    final segments = pointerSegments(pointer);
    if (segments.isEmpty) continue;
    Object? node = copy;
    for (final segment in segments.take(segments.length - 1)) {
      node = node is List ? node[int.parse(segment)] : (node! as Map)[segment];
    }
    if (node is Map) node.remove(segments.last);
  }
  return copy;
}

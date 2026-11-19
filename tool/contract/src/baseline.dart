/// The known discrepancies of `contract/baseline/known_discrepancies.yaml` as the violations they
/// take away.
library;

import 'corpus.dart' show BaselineEntry;
import 'overlays.dart' show ContractPlatform;
import 'schema_validator.dart' show Violation;

/// One violation the baseline takes away: the [keyword] at [path] of a payload of [entry] on
/// [platform], with the [caseName] that still shows it. A batch entry gives one item per element
/// of its `items`.
final class BaselineItem {
  const BaselineItem({
    required this.id,
    required this.entry,
    required this.path,
    required this.keyword,
    required this.platform,
    required this.caseName,
  });

  /// The id of the baseline entry the item comes from.
  final String id;

  /// The schema entry, `Activate.Request`.
  final String entry;

  /// The JSON Pointer into the payload; empty for the payload itself.
  final String path;
  final String keyword;
  final ContractPlatform platform;
  final String caseName;

  /// Whether this item takes away [violation] of a payload of [entryName] on [onPlatform].
  bool matches(String entryName, ContractPlatform onPlatform, Violation violation) =>
      entryName == entry && onPlatform == platform && violation.instancePath == path && violation.keyword == keyword;

  @override
  String toString() => '$id: $keyword at $entry${path.isEmpty ? '' : ' $path'} on ${platform.name} (case $caseName)';
}

/// The items of [entries], in order. Throws a [FormatException] naming the entry when one lacks a
/// field an item needs or carries an item key the format does not know.
List<BaselineItem> baselineItems(Iterable<BaselineEntry> entries) => [
  for (final entry in entries)
    if (entry.fields['items'] case final List<Object?> items)
      for (final (index, item) in items.indexed)
        _item(entry, item, 'item ${index + 1}', keyword: _text(entry, entry.fields, 'keyword', 'the entry'))
    else
      _item(entry, entry.fields, 'the entry'),
];

/// The keys of an element of `items`.
const _itemKeys = {'entry', 'path', 'platform', 'case'};

BaselineItem _item(BaselineEntry entry, Object? fields, String where, {String? keyword}) {
  if (fields is! Map<String, Object?>) throw FormatException('baseline entry ${entry.id}: $where is not a map');
  if (keyword != null) {
    for (final key in fields.keys) {
      if (!_itemKeys.contains(key))
        throw FormatException('baseline entry ${entry.id}: $where has an unknown key "$key"');
    }
  }
  final platform = _text(entry, fields, 'platform', where);
  return BaselineItem(
    id: entry.id,
    entry: _text(entry, fields, 'entry', where),
    path: _text(entry, fields, 'path', where, mayBeEmpty: true),
    keyword: keyword ?? _text(entry, fields, 'keyword', where),
    platform: ContractPlatform.values.firstWhere(
      (p) => p.name == platform,
      orElse: () => throw FormatException('baseline entry ${entry.id}: $where has an unknown platform "$platform"'),
    ),
    caseName: _text(entry, fields, 'case', where),
  );
}

String _text(BaselineEntry entry, Map<String, Object?> fields, String key, String where, {bool mayBeEmpty = false}) {
  final value = fields[key];
  if (value is String && (mayBeEmpty || value.trim().isNotEmpty)) return value;
  throw FormatException('baseline entry ${entry.id}: $where has no $key');
}

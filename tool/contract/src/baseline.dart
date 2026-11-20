/// The known discrepancies of `contract/baseline/known_discrepancies.yaml` as the violations they
/// take away.
library;

import 'corpus.dart' show BaselineEntry;
import 'overlays.dart' show ContractPlatform;
import 'schema_validator.dart' show Violation;

/// One violation the baseline takes away: the [keyword] at [path] of a payload of [entry] on
/// [platform], with the [caseName] that still shows it and the [decision] of its entry. A batch
/// entry gives one item per element of its `items`.
final class BaselineItem {
  const BaselineItem({
    required this.id,
    required this.entry,
    required this.path,
    required this.keyword,
    required this.platform,
    required this.caseName,
    required this.decision,
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

  /// `fix_dart`, `ask_native` or `accepted`.
  final String decision;

  /// Whether the entry of the item is accepted: what it takes away stays as it is.
  bool get isAccepted => decision == 'accepted';

  /// Whether this item takes away [violation] of a payload of [entryName] on [onPlatform].
  bool matches(String entryName, ContractPlatform onPlatform, Violation violation) =>
      entryName == entry && onPlatform == platform && violation.instancePath == path && violation.keyword == keyword;

  @override
  String toString() => '$id: $keyword at $entry${path.isEmpty ? '' : ' $path'} on ${platform.name} (case $caseName)';
}

/// The item of [baseline] that takes away [violation] of a payload of [entryName] on [platform], if
/// any. In a payload declared as the case [declaredCase] (`<method>/<case>`) an item of that case
/// takes it; failing that, an accepted item of another case of the same method, never one of an
/// embedded view or of another method, so that every item stays the one that holds its case. In a
/// payload that is not declared an accepted item of any case takes it. An item that is not accepted
/// takes nothing away from a payload that is not declared as its case: what it stands for is still to
/// be decided, and only its case shows it.
BaselineItem? takingItem(
  Iterable<BaselineItem> baseline,
  String entryName,
  ContractPlatform platform,
  Violation violation, {
  String? declaredCase,
}) {
  final matching = baseline.where((item) => item.matches(entryName, platform, violation));
  if (declaredCase == null) return matching.where((item) => item.isAccepted).firstOrNull;
  final method = '${declaredCase.split('/').first}/';
  return matching.where((item) => item.caseName == declaredCase).firstOrNull ??
      matching.where((item) => item.isAccepted && item.caseName.startsWith(method)).firstOrNull;
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
    decision: entry.decision,
  );
}

String _text(BaselineEntry entry, Map<String, Object?> fields, String key, String where, {bool mayBeEmpty = false}) {
  final value = fields[key];
  if (value is String && (mayBeEmpty || value.trim().isNotEmpty)) return value;
  throw FormatException('baseline entry ${entry.id}: $where has no $key');
}

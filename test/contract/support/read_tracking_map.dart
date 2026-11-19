// A decoded JSON payload that records which keys a decoder looks up.
import 'dart:collection';

import '../../../tool/contract/src/schema_validator.dart' show escapePointerSegment;

/// Records the keys of one JSON payload a decoder looks up, as JSON Pointer instance paths
/// (`/success/profile_id`).
///
/// Only a lookup marks a key: `[]` and `containsKey`. Going over a map (`forEach`, `entries`, `keys`,
/// `values`, `map`, and so `Map.from`) marks nothing, but hands out the values wrapped, so a lookup
/// inside them is still seen. A list hands out its items wrapped. Nothing can be written.
final class ReadTracker {
  final _read = <String>{};

  /// The instance paths of the keys looked up so far.
  Set<String> get read => Set.unmodifiable(_read);

  /// [json] with every map and list in it wrapped; anything else as it is.
  Object? track(Object? json) => _wrap(json, '');

  Object? _wrap(Object? value, String path) => switch (value) {
    Map<String, Object?>() => _TrackingMap(this, value, path),
    List<Object?>() => _TrackingList(this, value, path),
    _ => value,
  };
}

final class _TrackingMap extends MapBase<String, dynamic> {
  _TrackingMap(this._tracker, this._inner, this._path);

  final ReadTracker _tracker;
  final Map<String, Object?> _inner;
  final String _path;

  String _pathOf(String key) => '$_path/${escapePointerSegment(key)}';

  Object? _value(String key) => _tracker._wrap(_inner[key], _pathOf(key));

  @override
  dynamic operator [](Object? key) {
    if (key is! String) return null;
    _tracker._read.add(_pathOf(key));
    return _value(key);
  }

  @override
  bool containsKey(Object? key) {
    if (key is String) _tracker._read.add(_pathOf(key));
    return _inner.containsKey(key);
  }

  @override
  Iterable<String> get keys => _inner.keys;

  @override
  int get length => _inner.length;

  @override
  Iterable<dynamic> get values => _inner.keys.map(_value);

  @override
  Iterable<MapEntry<String, dynamic>> get entries => _inner.keys.map((key) => MapEntry(key, _value(key)));

  @override
  void forEach(void Function(String key, dynamic value) action) {
    for (final key in _inner.keys) {
      action(key, _value(key));
    }
  }

  @override
  Map<K2, V2> map<K2, V2>(MapEntry<K2, V2> Function(String key, dynamic value) convert) =>
      Map.fromEntries(_inner.keys.map((key) => convert(key, _value(key))));

  @override
  bool containsValue(Object? value) => values.contains(value);

  @override
  void operator []=(String key, dynamic value) => throw UnsupportedError('a tracked payload cannot be written');

  @override
  dynamic remove(Object? key) => throw UnsupportedError('a tracked payload cannot be written');

  @override
  void clear() => throw UnsupportedError('a tracked payload cannot be written');
}

final class _TrackingList extends ListBase<dynamic> {
  _TrackingList(this._tracker, this._inner, this._path);

  final ReadTracker _tracker;
  final List<Object?> _inner;
  final String _path;

  @override
  int get length => _inner.length;

  @override
  set length(int newLength) => throw UnsupportedError('a tracked payload cannot be written');

  @override
  dynamic operator [](int index) => _tracker._wrap(_inner[index], '$_path/$index');

  @override
  void operator []=(int index, dynamic value) => throw UnsupportedError('a tracked payload cannot be written');

  @override
  void add(dynamic element) => throw UnsupportedError('a tracked payload cannot be written');
}

// The JSON Pointers of the contract tools: how a segment is escaped and read back, which keys a pointer goes
// through, and a payload without the keys at some pointers.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/json_pointer.dart';

void main() {
  group('a segment', () {
    test('reads ~1 as a slash before it reads ~0 as a tilde', () {
      expect(unescapePointerSegment('~01'), '~1');
      expect(unescapePointerSegment('a~1b'), 'a/b');
      expect(unescapePointerSegment('a~0b'), 'a~b');
      expect(unescapePointerSegment('plain'), 'plain');
    });

    test('reads back what escaping wrote', () {
      expect(escapePointerSegment('~'), '~0');
      expect(escapePointerSegment('/'), '~1');
      expect(escapePointerSegment('~1'), '~01');
      for (final key in ['~', '/', '~1', '~0', 'a/b~c', '/~/', '']) {
        expect(unescapePointerSegment(escapePointerSegment(key)), key, reason: key);
      }
    });
  });

  group('the segments of a pointer', () {
    test('are none for the whole document', () {
      expect(pointerSegments(''), isEmpty);
      expect(pointerSegments('#'), isEmpty);
    });

    test('are the keys after each slash, unescaped, in a payload path and in a schema pointer', () {
      expect(pointerSegments('/a/b'), ['a', 'b']);
      expect(pointerSegments('#/a/b'), ['a', 'b']);
      expect(pointerSegments('/items/0/a~1b/c~0d'), ['items', '0', 'a/b', 'c~d']);
      expect(pointerSegments('/'), ['']);
    });
  });

  group('a payload without the keys at some pointers', () {
    Map<String, Object?> payload() => {
      'a': {'b': 1, 'c': 2},
      'items': [
        {'x': 1, 'y': 2},
        {'x': 3, 'y': 4},
      ],
      'a/b': {'c~d': 1, 'e': 2},
    };

    test('loses a nested key, a key under an item of a list and a key with escaped characters', () {
      expect(withoutPointers(payload(), ['/a/b', '/items/1/x', '/a~1b/c~0d']), {
        'a': {'c': 2},
        'items': [
          {'x': 1, 'y': 2},
          {'y': 4},
        ],
        'a/b': {'e': 2},
      });
    });

    test('is a copy: the payload it was made from keeps every key', () {
      final original = payload();
      final before = jsonEncode(original);
      final result = withoutPointers(original, ['/a/b', '/items/0/x']);
      expect(jsonEncode(original), before);
      expect(identical(result, original), isFalse);
    });

    test('keeps the whole document for an empty pointer and still applies the other pointers', () {
      expect(withoutPointers(payload(), ['']), payload());
      expect(withoutPointers(payload(), ['', '/a']), {...payload()}..remove('a'));
    });

    test('keeps an item a pointer names in a list', () {
      expect(withoutPointers(payload(), ['/items/0']), payload());
    });
  });
}

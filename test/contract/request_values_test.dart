/// What the golden requests have to show of the schema: every value of an enum a request of the SDK can
/// carry on a platform, in a golden request of that platform, unless a row of the exceptions says why
/// none does.
import 'package:adapty_flutter/src/constants/method.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/contract_schema.dart';
import '../../tool/contract/src/contract_source.dart';
import '../../tool/contract/src/corpus.dart';
import '../../tool/contract/src/overlays.dart';
import '../../tool/contract/src/request_values.dart';
import '../../tool/contract/src/source_refs.dart';
import '../support/contract/temp_schema.dart';

const ios = ContractPlatform.ios;
const android = ContractPlatform.android;

/// A small contract: `set` sends a level, a mode, and on Android a mode of its own; `only_ios` sends a
/// preference and is handled by iOS only; `unsent` is never sent by the SDK.
final ContractSchema _schema = tempSchema(
  requests: r'''
Set.Request:
  type: object
  required: [method, level]
  properties:
    method: { const: "set" }
    level: { $ref: "#/$defs/Level" }
    mode: { type: string, enum: [a, b] }
    android_mode: { type: string, enum: [x] }
OnlyIos.Request:
  type: object
  required: [method]
  properties:
    method: { const: "only_ios" }
    preference:
      oneOf:
        - { $ref: "#/$defs/Preference" }
        - { type: integer }
Unsent.Request:
  type: object
  required: [method]
  properties:
    method: { const: "unsent" }
    hidden: { type: string, enum: [h] }''',
  defs: '''
Level:
  type: string
  enum: [info, debug]
Preference:
  type: string
  enum: [grant, decline]''',
  overlays: const ContractOverlays(
    platformFields: [
      PlatformFieldRow(
        pointer: r'#/$requests/Set.Request/properties/android_mode',
        platforms: {android},
        source: 'test',
      ),
    ],
    platformMethods: [
      PlatformMethodRow(name: 'only_ios', isEvent: false, platforms: {ios}, source: 'test'),
    ],
  ),
);

const _sent = {'set', 'only_ios'};
const _refs = {'ios@test', 'android@test'};

const _level = r'#/$defs/Level';
const _mode = r'#/$requests/Set.Request/properties/mode';
const _androidMode = r'#/$requests/Set.Request/properties/android_mode';
const _preference = r'#/$defs/Preference';

CorpusFixture _golden(
  String name,
  String caseName,
  Object? payload, {
  ContractPlatform? platform,
  bool negative = false,
}) => CorpusFixture(
  kind: CorpusKind.request,
  name: name,
  caseName: caseName,
  platform: platform,
  path: 'contract/requests/$name/$caseName${platform == null ? '' : '.${platform.name}'}.json',
  provenance: {'source': 'golden', 'native': platform == null ? 'both' : '${platform.name}@test'},
  expect: negative
      ? {
          'violation': {'keyword': 'enum', 'pointer': '#'},
        }
      : null,
  notes: 'written by hand for this test',
  payload: payload,
);

/// Golden requests that carry every value of [_schema] on both platforms, keyed by `<name>/<case>[.<platform>]`.
Map<String, CorpusFixture> _complete() => {
  'set/default': _golden('set', 'default', {'level': 'info', 'mode': 'a'}),
  'set/other.ios': _golden('set', 'other', {'level': 'debug', 'mode': 'b'}, platform: ios),
  'set/other.android': _golden('set', 'other', {'level': 'debug', 'mode': 'b', 'android_mode': 'x'}, platform: android),
  'only_ios/grant': _golden('only_ios', 'grant', {'preference': 'grant'}),
  'only_ios/decline': _golden('only_ios', 'decline', {'preference': 'decline'}, platform: ios),
};

List<String> _problems(Map<String, CorpusFixture> fixtures, {List<RequestValueException> exceptions = const []}) =>
    requestValueProblems(
      Corpus(fixtures: fixtures.values.toList(), baseline: const [], problems: const []),
      _schema,
      exceptions,
      sentMethods: _sent,
      refs: _refs,
    );

RequestValueException _exception(
  String pointer,
  Object? value,
  Set<ContractPlatform> platforms, {
  String reason = 'the SDK never sends it',
  String source = 'ios@test Sources/Set.swift:12',
}) => RequestValueException(pointer: pointer, value: value, platforms: platforms, reason: reason, source: source);

void main() {
  group('the values a golden request has to carry', () {
    test('are the values of every enum the requests of a platform reach, by reference and in branches', () {
      expect(requestValueUniverse(_schema, ios, sentMethods: _sent), {
        '$_level = "info"',
        '$_level = "debug"',
        '$_mode = "a"',
        '$_mode = "b"',
        '$_preference = "grant"',
        '$_preference = "decline"',
      });
      expect(requestValueUniverse(_schema, android, sentMethods: _sent), {
        '$_level = "info"',
        '$_level = "debug"',
        '$_mode = "a"',
        '$_mode = "b"',
        '$_androidMode = "x"',
      });
    });

    test('leave out a branch of another platform with the values under it', () {
      final schema = tempSchema(
        requests: r'''
Pick.Request:
  type: object
  required: [method]
  properties:
    method: { const: "pick" }
    kind:
      oneOf:
        - { type: string, enum: [shared] }
        - { type: string, enum: [android_only] }''',
        overlays: const ContractOverlays(
          platformFields: [
            PlatformFieldRow(
              pointer: r'#/$requests/Pick.Request/properties/kind/oneOf/1',
              platforms: {android},
              source: 'test',
            ),
          ],
        ),
      );
      const kind = r'#/$requests/Pick.Request/properties/kind';
      expect(requestValueUniverse(schema, ios, sentMethods: {'pick'}), {'$kind/oneOf/0 = "shared"'});
      expect(requestValueUniverse(schema, android, sentMethods: {'pick'}), {
        '$kind/oneOf/0 = "shared"',
        '$kind/oneOf/1 = "android_only"',
      });
    });

    test('leave out a method the SDK does not send', () {
      expect(requestValueUniverse(_schema, ios, sentMethods: {'set'}).where((i) => i.contains('Preference')), isEmpty);
    });
  });

  group('the golden requests', () {
    test('that carry every value on both platforms have no problem', () {
      expect(_problems(_complete()), isEmpty);
    });

    test('miss a value no golden request of a platform carries', () {
      final fixtures = _complete()..remove('only_ios/decline');
      expect(_problems(fixtures), ['ios $_preference = "decline": in no golden request']);
    });

    test('carry a value of one platform only in a file of that platform', () {
      final fixtures = _complete()
        ..['set/other.android'] = _golden('set', 'other', {
          'level': 'info',
          'mode': 'a',
          'android_mode': 'x',
        }, platform: android);
      expect(_problems(fixtures), [
        'android $_level = "debug": in no golden request',
        'android $_mode = "b": in no golden request',
      ]);
    });

    test('carry nothing in a negative case', () {
      final fixtures = _complete()
        ..['only_ios/decline'] = _golden('only_ios', 'decline', {'preference': 'decline'}, negative: true);
      expect(_problems(fixtures), ['ios $_preference = "decline": in no golden request']);
    });

    test('carry the values of the requests of a platform only', () {
      final fixtures = _complete()
        ..['only_ios/x'] = _golden('only_ios', 'x', {'preference': 'grant'}, platform: android);
      expect(_problems(fixtures), isEmpty);
      expect(
        requestValuesSent(
          Corpus(fixtures: fixtures.values.toList(), baseline: const [], problems: const []),
          _schema,
          android,
          sentMethods: _sent,
        ).where((i) => i.contains('Preference')),
        isEmpty,
      );
    });
  });

  group('a row of the exceptions', () {
    test('explains a value no golden request of its platforms carries', () {
      final fixtures = _complete()..remove('only_ios/decline');
      expect(
        _problems(
          fixtures,
          exceptions: [
            _exception(_preference, 'decline', {ios}),
          ],
        ),
        isEmpty,
      );
    });

    test('is wrong when a golden request of its platform carries the value', () {
      expect(
        _problems(
          _complete(),
          exceptions: [
            _exception(_preference, 'decline', {ios}),
          ],
        ),
        ['exception $_preference = "decline": in a golden request of ios now, remove the row'],
      );
    });

    test('is wrong when its platform does not reach the value, or the schema has no such node', () {
      expect(
        _problems(
          _complete(),
          exceptions: [
            _exception(_preference, 'decline', {android}),
          ],
        ),
        ['exception $_preference = "decline": not a value android has to send'],
      );
      expect(
        _problems(
          _complete(),
          exceptions: [
            _exception(r'#/$defs/Nothing', 'a', {ios}),
          ],
        ),
        ['exception #/\$defs/Nothing = "a": no such schema node'],
      );
    });

    test('is wrong without a reason or a source under a fixed ref, or twice on a platform', () {
      final fixtures = _complete()..remove('only_ios/decline');
      expect(
        _problems(
          fixtures,
          exceptions: [
            _exception(_preference, 'decline', {ios}, reason: ''),
            _exception(_preference, 'decline', {ios}, source: 'ios@other Sources/Set.swift:12'),
          ],
        ),
        [
          'exception $_preference = "decline": no reason',
          'exception $_preference = "decline": ios@other Sources/Set.swift:12: ios@other is not a ref the contract is fixed to',
          'exception $_preference = "decline": more than one row on ios',
        ],
      );
    });

    test('reads from YAML with its pointer, value, platforms, reason and source, and nothing else', () {
      final rows = RequestValueException.parse('''
- pointer: '#/\$defs/Preference'
  value: decline
  platforms: [ios]
  reason: why
  source: 'ios@test Sources/Set.swift:12'
''');
      expect(rows.single.item, '$_preference = "decline"');
      expect(rows.single.platforms, {ios});
      expect(
        () => RequestValueException.parse("- {pointer: '#/a', value: b, platforms: [ios], reason: r, source: s, x: 1}"),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('unknown key "x"'))),
      );
      expect(
        () => RequestValueException.parse("- {pointer: '#/a', value: b, platforms: [], reason: r, source: s}"),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('platforms'))),
      );
      expect(
        () => RequestValueException.parse("- {pointer: '#/a', platforms: [ios], reason: r, source: s}"),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('no value'))),
      );
      expect(
        () => RequestValueException.parse("- {pointer: '#/a', value: b, platforms: [ios], source: s}"),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', endsWith('row 1: no reason'))),
      );
      expect(
        () => RequestValueException.parse("- {pointer: '#/a', value: b, platforms: [ios], reason: r, source: ' '}"),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', endsWith('row 1: no source'))),
      );
    });
  });

  test('every value of an enum a request of the SDK can carry is in a golden request of its platform', () {
    final source = ContractSource.load('.');
    expect(
      requestValueProblems(
        Corpus.load('.'),
        ContractSchema.load('.'),
        RequestValueException.load('.'),
        sentMethods: {for (final m in NativeMethod.values) m.wireName},
        refs: NativeRefs.of(source).all,
      ),
      isEmpty,
    );
  });
}

/// The contract corpus: how its files are read, what makes a fixture wrong for the schema and its
/// platform, and that the corpus of this repository is valid and has every case it needs.
import 'dart:convert';
import 'dart:io';

import 'package:adapty_flutter/src/constants/method.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/contract_schema.dart';
import '../../tool/contract/src/corpus.dart';
import '../../tool/contract/src/overlays.dart';
import '../support/contract/temp_schema.dart';

const ios = ContractPlatform.ios;
const android = ContractPlatform.android;

/// The file of one case with the given payload.
Map<String, Object?> _case(
  Object? payload, {
  String native = 'both',
  Map<String, Object?>? expect,
  String source = 'hand',
}) => {
  'provenance': {'source': source, 'native': native},
  'expect': expect,
  'notes': 'written by hand for this test',
  'payload': payload,
};

Map<String, Object?> _violation(String keyword, String pointer) => {
  'violation': {'keyword': keyword, 'pointer': pointer},
};

/// A repository root in a fresh temporary directory with the given files under `contract/`: a map is
/// written as JSON, a string as it is.
String _repo(Map<String, Object> files) {
  final root = Directory.systemTemp.createTempSync('contract_corpus_').path;
  addTearDown(() => Directory(root).deleteSync(recursive: true));
  for (final MapEntry(key: path, value: content) in files.entries) {
    File('$root/contract/$path')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content is String ? content : jsonEncode(content));
  }
  return root;
}

const _item = {'id': 'item-1', 'shared': true};
const _androidItem = {'id': 'item-1', 'plan': 'base'};

/// A small contract: `ping` answers true, `get` answers an item, `only_ios` is handled by iOS only,
/// `unsent` is never sent by the SDK; the event `seen` carries an item, `ios_seen` comes from iOS only.
/// An item has `shared` on iOS only and `plan` on Android only.
final ContractSchema _schema = tempSchema(
  requests: r'''
Ping.Request:
  type: object
  required: [method]
  properties:
    method: { const: "ping" }
    note: { type: string }
Ping.Response:
  type: object
  oneOf:
    - required: [error]
      properties:
        error: { $ref: "#/$defs/Error" }
    - required: [success]
      properties:
        success: { const: true }
Get.Request:
  type: object
  required: [method]
  properties:
    method: { const: "get" }
Get.Response:
  type: object
  oneOf:
    - required: [error]
      properties:
        error: { $ref: "#/$defs/Error" }
    - required: [success]
      properties:
        success: { $ref: "#/$defs/Item" }
OnlyIos.Request:
  type: object
  required: [method]
  properties:
    method: { const: "only_ios" }
OnlyIos.Response:
  type: object
  oneOf:
    - required: [success]
      properties:
        success: { const: true }
Unsent.Request:
  type: object
  required: [method]
  properties:
    method: { const: "unsent" }
Unsent.Response:
  type: object
  oneOf:
    - required: [success]
      properties:
        success: { const: true }''',
  events: r'''
Event.Seen:
  type: object
  required: [id, item]
  properties:
    id: { const: "seen" }
    item: { $ref: "#/$defs/Item" }
Event.IosSeen:
  type: object
  required: [id]
  properties:
    id: { const: "ios_seen" }''',
  defs: '''
Error:
  type: object
  required: [adapty_code, message]
  properties:
    adapty_code: { type: integer }
    message: { type: string }
Item:
  type: object
  required: [id, shared, plan]
  properties:
    id: { type: string }
    shared: { type: boolean }
    plan: { type: string }''',
  overlays: const ContractOverlays(
    platformRequired: [
      PlatformFieldRow(pointer: r'#/$defs/Item/properties/shared', platforms: {ios}, source: 'test'),
      PlatformFieldRow(pointer: r'#/$defs/Item/properties/plan', platforms: {android}, source: 'test'),
    ],
    platformMethods: [
      PlatformMethodRow(name: 'only_ios', isEvent: false, platforms: {ios}, source: 'test'),
      PlatformMethodRow(name: 'ios_seen', isEvent: true, platforms: {ios}, source: 'test'),
    ],
  ),
);

const _sent = {'ping', 'get', 'only_ios'};

/// A corpus with every case [_schema] needs, valid on every platform.
Map<String, Object> _complete() => {
  'responses/ping/default.json': _case({'success': true}),
  'responses/ping/not_true.json': _case({
    'success': false,
  }, expect: _violation('const', r'#/$requests/Ping.Response/oneOf/1/properties/success')),
  'responses/get/default.ios.json': _case({'success': _item}, native: 'ios@test'),
  'responses/get/default.android.json': _case({'success': _androidItem}, native: 'android@test'),
  'responses/get/without_id.ios.json': _case(
    {
      'success': {'shared': true},
    },
    native: 'ios@test',
    expect: _violation('required', r'#/$defs/Item'),
  ),
  'responses/only_ios/default.json': _case({'success': true}),
  'responses/only_ios/not_true.json': _case({
    'success': 1,
  }, expect: _violation('const', r'#/$requests/OnlyIos.Response/oneOf/0/properties/success')),
  'events/seen/default.ios.json': _case({'id': 'seen', 'item': _item}, native: 'ios@test'),
  'events/seen/default.android.json': _case({'id': 'seen', 'item': _androidItem}, native: 'android@test'),
  'events/seen/without_item.json': _case({'id': 'seen'}, expect: _violation('required', r'#/$events/Event.Seen')),
  'events/ios_seen/default.json': _case({'id': 'ios_seen'}),
  'events/ios_seen/wrong_id.json': _case({
    'id': 'seen',
  }, expect: _violation('const', r'#/$events/Event.IosSeen/properties/id')),
  'baseline/known_discrepancies.yaml': '[]\n',
};

List<String> _fixtureProblems(Map<String, Object> files) =>
    fixtureProblems(Corpus.load(_repo(files)), _schema, sentMethods: _sent);

List<String> _coverageProblems(Map<String, Object> files) =>
    coverageProblems(Corpus.load(_repo(files)), _schema, sentMethods: _sent);

void main() {
  group('reading the corpus', () {
    test('a case is found by kind, name, case and platform, else in the file both platforms share', () {
      final corpus = Corpus.load(_repo(_complete()));
      expect(corpus.problems, isEmpty);
      expect(
        corpus.fixture(CorpusKind.response, 'ping', 'default', android)?.path,
        'contract/responses/ping/default.json',
      );
      expect(
        corpus.fixture(CorpusKind.response, 'get', 'default', ios)?.path,
        'contract/responses/get/default.ios.json',
      );
      expect(corpus.fixture(CorpusKind.response, 'get', 'default', ios)?.platform, ios);
      expect(corpus.fixture(CorpusKind.response, 'get', 'default', android)?.payload, {'success': _androidItem});
      expect(corpus.fixture(CorpusKind.response, 'get', 'without_id', android), isNull);
      expect(corpus.fixture(CorpusKind.event, 'seen', 'default', android)?.notes, 'written by hand for this test');
      expect(corpus.fixture(CorpusKind.request, 'ping', 'default', ios), isNull);
    });

    test('a case with an expect is negative, one without is positive', () {
      final corpus = Corpus.load(_repo(_complete()));
      expect(corpus.fixture(CorpusKind.response, 'get', 'without_id', ios)?.isNegative, isTrue);
      expect(corpus.fixture(CorpusKind.response, 'get', 'default', ios)?.isNegative, isFalse);
    });

    test('a file whose name, JSON or fields do not make a case is a problem of the corpus', () {
      final corpus = Corpus.load(
        _repo({
          'responses/ping/Bad-name.json': _case({'success': true}),
          'responses/ping/broken.json': '{"provenance": ',
          'responses/ping/no_notes.json': {
            ..._case({'success': true}),
          }..remove('notes'),
          'responses/ping/extra_key.json': {
            ..._case({'success': true}),
            'payloads': 1,
          },
          'responses/ping/wrong_native.ios.json': _case({'success': true}),
          'responses/ping/wrong_source.json': _case({'success': true}, source: 'recorded'),
          'responses/ping/empty_expect.json': _case({'success': true}, expect: {}),
          'responses/ping/default.json': _case({'success': true}),
        }),
      );
      expect(corpus.problems, hasLength(7));
      for (final name in [
        'Bad-name.json',
        'broken.json',
        'no_notes.json',
        'extra_key.json',
        'wrong_native.ios.json',
        'wrong_source.json',
        'empty_expect.json',
      ]) {
        expect(corpus.problems, contains(startsWith('contract/responses/ping/$name: ')));
      }
      expect(corpus.fixtures.map((f) => f.caseName), ['default']);
    });

    test('values from recorded RN samples and golden files are accepted sources', () {
      final corpus = Corpus.load(
        _repo({
          'responses/ping/default.json': _case({'success': true}, source: 'rn-sample@v4.3.10'),
          'responses/ping/golden.json': _case({'success': true}, source: 'golden'),
        }),
      );
      expect(corpus.problems, isEmpty);
    });

    test('a case with a file both platforms share and a file of one platform is a problem', () {
      final corpus = Corpus.load(
        _repo({
          'responses/ping/default.json': _case({'success': true}),
          'responses/ping/default.ios.json': _case({'success': true}, native: 'ios@test'),
        }),
      );
      expect(corpus.problems, [
        'contract/responses/ping/default.ios.json: the case "default" also has a file both platforms share',
      ]);
    });

    test('the baseline is read as entries with an id, a reason and a known decision', () {
      final corpus = Corpus.load(
        _repo({
          'baseline/known_discrepancies.yaml': '''
- id: extra-key
  direction: dart_sends_extra
  decision: accepted
  reason: both natives ignore it
''',
        }),
      );
      expect(corpus.problems, isEmpty);
      expect(corpus.baseline.single.id, 'extra-key');
      expect(corpus.baseline.single.decision, 'accepted');
      expect(corpus.baseline.single.fields['direction'], 'dart_sends_extra');
      expect(Corpus.load(_repo({'baseline/known_discrepancies.yaml': '[]\n'})).baseline, isEmpty);
    });

    test('a baseline entry without a decision it knows is a problem of the corpus', () {
      final corpus = Corpus.load(
        _repo({
          'baseline/known_discrepancies.yaml': '''
- id: extra-key
  decision: ignore
  reason: both natives ignore it
''',
        }),
      );
      expect(corpus.problems, [
        'contract/baseline/known_discrepancies.yaml entry 1: decision "ignore" is not fix_dart, ask_native or accepted',
      ]);
    });
  });

  group('checking the fixtures', () {
    test('a corpus with every case, each valid on its platform, has no problems', () {
      expect(_fixtureProblems(_complete()), isEmpty);
      expect(_coverageProblems(_complete()), isEmpty);
    });

    test('a fixture of a method or an event the contract does not have is a problem', () {
      expect(
        _fixtureProblems({
          ..._complete(),
          'responses/pong/default.json': _case({'success': true}),
          'events/unseen/default.json': _case({'id': 'unseen'}),
        }),
        [
          'contract/events/unseen/default.json: the contract has no event unseen',
          'contract/responses/pong/default.json: the contract has no method pong',
        ],
      );
    });

    test('a fixture of a platform that does not handle the method or send the event is a problem', () {
      expect(
        _fixtureProblems({
          ..._complete(),
          'responses/only_ios/other.android.json': _case({'success': true}, native: 'android@test'),
          'events/ios_seen/other.android.json': _case({'id': 'ios_seen'}, native: 'android@test'),
        }),
        [
          'contract/events/ios_seen/other.android.json: android does not send ios_seen',
          'contract/responses/only_ios/other.android.json: android does not handle only_ios',
        ],
      );
    });

    test('a response of a method the SDK does not send is a problem', () {
      expect(
        _fixtureProblems({
          ..._complete(),
          'responses/unsent/default.json': _case({'success': true}),
        }),
        ['contract/responses/unsent/default.json: the SDK does not send unsent'],
      );
    });

    test('a positive fixture both platforms share must be valid on each', () {
      final files = _complete()
        ..remove('responses/get/default.ios.json')
        ..remove('responses/get/default.android.json')
        ..['responses/get/default.json'] = _case({
          'success': {'id': 'item-1', 'shared': true, 'plan': 'base'},
        });
      final problems = _fixtureProblems(files);
      expect(problems, hasLength(2));
      expect(problems[0], startsWith('contract/responses/get/default.json: not what ios sends: '));
      expect(problems[0], contains('/success/plan: platform_field at #/\$defs/Item/properties/plan'));
      expect(problems[1], startsWith('contract/responses/get/default.json: not what android sends: '));
      expect(problems[1], contains('/success/shared: platform_field at #/\$defs/Item/properties/shared'));
    });

    test('a positive fixture without a field its platform requires is not valid', () {
      final problems = _fixtureProblems({
        ..._complete(),
        'responses/get/default.android.json': _case({
          'success': {'id': 'item-1'},
        }, native: 'android@test'),
      });
      expect(problems.single, startsWith('contract/responses/get/default.android.json: not valid on android: '));
      expect(problems.single, contains('/success: required at #/\$defs/Item (missing "plan")'));
    });

    test('a positive fixture with a key the schema lacks is not what a native sends', () {
      final problems = _fixtureProblems({
        ..._complete(),
        'events/seen/default.ios.json': _case({
          'id': 'seen',
          'item': {..._item, 'shraed': true},
        }, native: 'ios@test'),
      });
      expect(problems.single, startsWith('contract/events/seen/default.ios.json: not what ios sends: '));
      expect(problems.single, contains('/item/shraed: additionalProperties at #/\$events/Event.Seen/properties/item'));
    });

    test('a request fixture is checked in the closed request world', () {
      expect(
        _fixtureProblems({
          ..._complete(),
          'requests/ping/default.json': _case({'note': 'n'}),
        }),
        isEmpty,
      );
      final problems = _fixtureProblems({
        ..._complete(),
        'requests/ping/default.json': _case({'note': 'n', 'nite': 'typo'}),
      });
      expect(problems, hasLength(2));
      expect(problems[0], startsWith('contract/requests/ping/default.json: not valid on ios: '));
      expect(problems[0], contains('/nite: additionalProperties at #/\$requests/Ping.Request'));
    });

    test('a negative fixture must be invalid on each of its platforms', () {
      final problems = _fixtureProblems({
        ..._complete(),
        'responses/ping/still_true.json': _case({
          'success': true,
        }, expect: _violation('const', r'#/$requests/Ping.Response/oneOf/1/properties/success')),
      });
      expect(problems, [
        'contract/responses/ping/still_true.json: a negative case, but valid on ios',
        'contract/responses/ping/still_true.json: a negative case, but valid on android',
      ]);
    });

    test('a negative fixture must break what its expect names', () {
      final problems = _fixtureProblems({
        ..._complete(),
        'responses/get/without_id.ios.json': _case(
          {
            'success': {'shared': true},
          },
          native: 'ios@test',
          expect: _violation('type', r'#/$defs/Item/properties/id'),
        ),
      });
      expect(
        problems.single,
        startsWith(
          'contract/responses/get/without_id.ios.json: a negative case without type at #/\$defs/Item/properties/id on ios: ',
        ),
      );
    });

    test('a negative fixture without a violation in its expect only has to be invalid', () {
      expect(
        _fixtureProblems({
          ..._complete(),
          'responses/ping/declined.json': _case({'success': false}, expect: {'native': 'decodingFailed'}),
        }),
        isEmpty,
      );
    });
  });

  group('checking the coverage', () {
    test('every response and event lacking a positive default per platform or a negative case is listed', () {
      final files = _complete()
        ..remove('responses/get/default.android.json')
        ..remove('responses/only_ios/not_true.json')
        ..remove('events/seen/default.ios.json')
        ..remove('events/ios_seen/default.json');
      expect(_coverageProblems(files), [
        'contract/responses/get: no positive default for android',
        'contract/responses/only_ios: no negative case',
        'contract/events/seen: no positive default for ios',
        'contract/events/ios_seen: no positive default for ios',
      ]);
    });

    test('a negative default does not count as the positive one', () {
      final files = _complete()
        ..['responses/ping/default.json'] = _case({
          'success': 2,
        }, expect: _violation('const', r'#/$requests/Ping.Response/oneOf/1/properties/success'));
      expect(_coverageProblems(files), [
        'contract/responses/ping: no positive default for ios',
        'contract/responses/ping: no positive default for android',
      ]);
    });
  });

  group('the corpus of this repository', () {
    late final schema = ContractSchema.load('.');
    late final corpus = Corpus.load('.');
    final sent = {
      for (final m in NativeMethod.values) m.wireName,
      for (final r in NativeEventResponse.values) r.wireName,
    };

    test('every fixture reads, belongs to a method or an event its platform has, and is valid there', () {
      expect(fixtureProblems(corpus, schema, sentMethods: sent), isEmpty);
    });

    test('the baseline of known discrepancies reads', () {
      expect(corpus.problems, isEmpty);
      expect(File('contract/baseline/known_discrepancies.yaml').existsSync(), isTrue);
    });
  });
}

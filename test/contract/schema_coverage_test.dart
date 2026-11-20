/// What the corpus of the contract has to show of the schema: every property, branch and value a
/// native writes in a response the SDK reads or in an event, in a positive fixture of that platform,
/// unless a row of the coverage exceptions says why no fixture does.
///
/// The check asks for a value to be there; it does not ask for one to be absent. That a native leaves
/// an optional field out is kept by the fixtures that leave it out and the projections of their models.
import 'package:adapty_flutter/src/constants/method.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/contract_schema.dart';
import '../../tool/contract/src/contract_source.dart';
import '../../tool/contract/src/corpus.dart';
import '../../tool/contract/src/overlays.dart';
import '../../tool/contract/src/schema_coverage.dart';
import '../../tool/contract/src/source_refs.dart';
import '../support/contract/temp_schema.dart';

const ios = ContractPlatform.ios;
const android = ContractPlatform.android;

/// A small contract: `get` answers an item or an error, `only_ios` is handled by iOS only and answers an
/// item too, `unsent` is never sent by the SDK; the event `seen` carries a dictionary of levels, `failed`
/// an error. `plan` of an item is written by Android only.
final ContractSchema _schema = tempSchema(
  requests: r'''
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
        error: { $ref: "#/$defs/AdaptyError" }
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
        item: { $ref: "#/$defs/Item" }
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
        success: { $ref: "#/$defs/Hidden" }''',
  events: r'''
Event.Seen:
  type: object
  required: [id]
  properties:
    id: { const: "seen" }
    levels:
      type: object
      additionalProperties: { $ref: "#/$defs/Level" }
Event.Failed:
  type: object
  required: [id, error]
  properties:
    id: { const: "failed" }
    error: { $ref: "#/$defs/AdaptyError" }''',
  defs: '''
AdaptyError:
  type: object
  required: [adapty_code, message]
  properties:
    adapty_code: { type: integer }
    message: { type: string }
    detail: { type: string }
Item:
  type: object
  required: [id]
  properties:
    id: { type: string }
    mode: { \$ref: "#/\$defs/Mode" }
    note: { type: string }
    plan: { type: string }
    identifier:
      oneOf:
        - type: object
          required: [type]
          properties:
            type: { const: "intro" }
        - type: object
          required: [type, id]
          properties:
            type: { const: "promo" }
            id: { type: string }
Mode:
  type: string
  enum: [trial, paid]
Level:
  type: object
  required: [active]
  properties:
    active: { type: boolean }
Hidden:
  type: object
  properties:
    secret: { type: string }''',
  overlays: const ContractOverlays(
    platformFields: [
      PlatformFieldRow(pointer: r'#/$defs/Item/properties/plan', platforms: {android}, source: 'test'),
    ],
    platformMethods: [
      PlatformMethodRow(name: 'only_ios', isEvent: false, platforms: {ios}, source: 'test'),
    ],
  ),
);

const _sent = {'get', 'only_ios'};
const _refs = {'ios@test', 'android@test'};

const _note = r'#/$defs/Item/properties/note';

CorpusFixture _fixture(
  CorpusKind kind,
  String name,
  String caseName,
  Object? payload, {
  ContractPlatform? platform,
  bool negative = false,
}) => CorpusFixture(
  kind: kind,
  name: name,
  caseName: caseName,
  platform: platform,
  path: 'contract/${kind.directory}/$name/$caseName${platform == null ? '' : '.${platform.name}'}.json',
  provenance: {'source': 'hand', 'native': platform == null ? 'both' : '${platform.name}@test'},
  expect: negative
      ? {
          'violation': {'keyword': 'required', 'pointer': '#'},
        }
      : null,
  notes: 'written by hand for this test',
  payload: payload,
);

const _error = {'adapty_code': 1, 'message': 'failed', 'detail': 'why'};

/// Fixtures that show every item of [_schema] on both platforms, keyed by `<name>/<case>[.<platform>]`.
Map<String, CorpusFixture> _complete() => {
  'get/default.ios': _fixture(CorpusKind.response, 'get', 'default', {
    'success': {
      'id': 'item-1',
      'mode': 'trial',
      'note': 'a note',
      'identifier': {'type': 'intro'},
    },
  }, platform: ios),
  'get/default.android': _fixture(CorpusKind.response, 'get', 'default', {
    'success': {
      'id': 'item-1',
      'mode': 'trial',
      'note': 'a note',
      'plan': 'base',
      'identifier': {'type': 'intro'},
    },
  }, platform: android),
  'get/paid': _fixture(CorpusKind.response, 'get', 'paid', {
    'success': {
      'id': 'item-2',
      'mode': 'paid',
      'identifier': {'type': 'promo', 'id': 'promo-1'},
    },
  }),
  'only_ios/default': _fixture(CorpusKind.response, 'only_ios', 'default', {
    'success': true,
    'item': {'id': 'item-3'},
  }),
  'seen/default': _fixture(CorpusKind.event, 'seen', 'default', {
    'id': 'seen',
    'levels': {
      'premium': {'active': true},
    },
  }),
  'seen/minimal': _fixture(CorpusKind.event, 'seen', 'minimal', {'id': 'seen'}),
  'failed/default': _fixture(CorpusKind.event, 'failed', 'default', {'id': 'failed', 'error': _error}),
};

List<String> _problems(Map<String, CorpusFixture> fixtures, {List<CoverageException> exceptions = const []}) =>
    schemaCoverageProblems(
      Corpus(fixtures: fixtures.values.toList(), baseline: const [], problems: const []),
      _schema,
      exceptions,
      sentMethods: _sent,
      refs: _refs,
    );

CoverageException _exception(
  String pointer,
  Set<ContractPlatform> platforms, {
  String source = 'ios@test Sources/Item.swift:12',
  bool hasValue = false,
  Object? value,
  CoverageExceptionKind kind = CoverageExceptionKind.notWritten,
}) => CoverageException(
  pointer: pointer,
  platforms: platforms,
  kind: kind,
  reason: 'the native never writes it',
  source: source,
  hasValue: hasValue,
  value: value,
);

void main() {
  group('the items of a corpus', () {
    test('a corpus that shows every item on both platforms has no problem', () {
      expect(_problems(_complete()), isEmpty);
    });

    test('a property no fixture of a platform shows is a problem of that platform', () {
      final fixtures = _complete()
        ..['get/default.ios'] = _fixture(CorpusKind.response, 'get', 'default', {
          'success': {
            'id': 'item-1',
            'mode': 'trial',
            'identifier': {'type': 'intro'},
          },
        }, platform: ios);

      expect(_problems(fixtures), ['ios $_note: in no positive fixture']);
    });

    test('a value of an enum no fixture shows is a problem', () {
      final fixtures = _complete()
        ..['get/paid'] = _fixture(CorpusKind.response, 'get', 'paid', {
          'success': {
            'id': 'item-2',
            'mode': 'trial',
            'identifier': {'type': 'promo', 'id': 'promo-1'},
          },
        });

      expect(_problems(fixtures), [
        'ios #/\$defs/Mode = "paid": in no positive fixture',
        'android #/\$defs/Mode = "paid": in no positive fixture',
      ]);
    });

    test('a branch the payload does not match shows nothing, though the validator tries it', () {
      final fixtures = _complete()
        ..['get/paid'] = _fixture(CorpusKind.response, 'get', 'paid', {
          'success': {
            'id': 'item-2',
            'mode': 'paid',
            'identifier': {'type': 'intro'},
          },
        });

      const branch = r'#/$defs/Item/properties/identifier/oneOf/1';
      expect(_problems(fixtures), [
        for (final platform in ['ios', 'android']) ...[
          '$platform $branch: in no positive fixture',
          '$platform $branch/properties/id: in no positive fixture',
          '$platform $branch/properties/type: in no positive fixture',
          '$platform $branch/properties/type = "promo": in no positive fixture',
        ],
      ]);
    });

    test('a property of the value of a dictionary has to be shown; a key of the dictionary is data', () {
      final fixtures = _complete()
        ..['seen/default'] = _fixture(CorpusKind.event, 'seen', 'default', {
          'id': 'seen',
          'levels': <String, Object?>{},
        });

      expect(_problems(fixtures), [
        'ios #/\$defs/Level/properties/active: in no positive fixture',
        'android #/\$defs/Level/properties/active: in no positive fixture',
      ]);
    });

    test('a field of one platform is an item of that platform only', () {
      final fixtures = _complete()
        ..['get/default.android'] = _fixture(CorpusKind.response, 'get', 'default', {
          'success': {
            'id': 'item-1',
            'mode': 'trial',
            'note': 'a note',
            'identifier': {'type': 'intro'},
          },
        }, platform: android);

      expect(_problems(fixtures), ['android #/\$defs/Item/properties/plan: in no positive fixture']);
    });

    test('a method the SDK does not send, and a method or an event of another platform, have no items', () {
      final onIos = coverageUniverse(_schema, ios, sentMethods: _sent);
      final onAndroid = coverageUniverse(_schema, android, sentMethods: _sent);

      expect(onIos, contains(r'#/$requests/OnlyIos.Response/oneOf/0/properties/success = true'));
      expect(onIos.where((item) => item.contains('Hidden') || item.contains('Unsent')), isEmpty);
      expect(onAndroid.where((item) => item.contains('OnlyIos')), isEmpty);
      expect(coverageUniverse(_schema, ios, sentMethods: {'get'}).where((item) => item.contains('OnlyIos')), isEmpty);
    });

    test('a fixture both platforms share, of a method one platform handles, shows nothing on the other', () {
      final fixtures = _complete()
        ..['get/default.android'] = _fixture(CorpusKind.response, 'get', 'default', {
          'success': {
            'id': 'item-1',
            'mode': 'trial',
            'plan': 'base',
            'identifier': {'type': 'intro'},
          },
        }, platform: android)
        ..['only_ios/default'] = _fixture(CorpusKind.response, 'only_ios', 'default', {
          'success': true,
          'item': {'id': 'item-3', 'note': 'a note'},
        });

      expect(_problems(fixtures), ['android $_note: in no positive fixture']);
    });

    test('a fixture with a violation shows nothing', () {
      final fixtures = _complete()
        ..['seen/default'] = _fixture(CorpusKind.event, 'seen', 'default', {
          'id': 'seen',
          'levels': {
            'premium': {'active': 'yes'},
          },
        });

      expect(_problems(fixtures), [
        for (final platform in ['ios', 'android']) ...[
          '$platform #/\$defs/Level/properties/active: in no positive fixture',
          '$platform #/\$events/Event.Seen/properties/levels: in no positive fixture',
        ],
      ]);
    });

    test('a negative fixture shows nothing', () {
      final fixtures = _complete()
        ..['seen/default'] = _fixture(CorpusKind.event, 'seen', 'default', {
          'id': 'seen',
          'levels': {
            'premium': {'active': true},
          },
        }, negative: true);

      expect(_problems(fixtures), [
        for (final platform in ['ios', 'android']) ...[
          '$platform #/\$defs/Level/properties/active: in no positive fixture',
          '$platform #/\$events/Event.Seen/properties/levels: in no positive fixture',
        ],
      ]);
    });

    test('the error branch of a response is shown when every property of the error is shown somewhere', () {
      final fixtures = _complete()
        ..['failed/default'] = _fixture(CorpusKind.event, 'failed', 'default', {
          'id': 'failed',
          'error': {'adapty_code': 1, 'message': 'failed'},
        });

      expect(_problems(fixtures), [
        for (final platform in ['ios', 'android']) ...[
          '$platform #/\$defs/AdaptyError/properties/detail: in no positive fixture',
          '$platform #/\$requests/Get.Response/oneOf/0: in no positive fixture',
          '$platform #/\$requests/Get.Response/oneOf/0/properties/error: in no positive fixture',
        ],
      ]);
    });
  });

  group('the rows of the coverage exceptions', () {
    Map<String, CorpusFixture> withoutNoteOnIos() =>
        _complete()
          ..['get/default.ios'] = _fixture(CorpusKind.response, 'get', 'default', {
            'success': {
              'id': 'item-1',
              'mode': 'trial',
              'identifier': {'type': 'intro'},
            },
          }, platform: ios);

    test('a row with a reason and a source explains an item no fixture of its platform shows', () {
      expect(
        _problems(
          withoutNoteOnIos(),
          exceptions: [
            _exception(_note, {ios}),
          ],
        ),
        isEmpty,
      );
    });

    test('a row with a value explains that value', () {
      final fixtures = _complete()
        ..['get/paid'] = _fixture(CorpusKind.response, 'get', 'paid', {
          'success': {
            'id': 'item-2',
            'mode': 'trial',
            'identifier': {'type': 'promo', 'id': 'promo-1'},
          },
        });

      expect(
        _problems(
          fixtures,
          exceptions: [
            _exception(
              r'#/$defs/Mode',
              {ios, android},
              hasValue: true,
              value: 'paid',
              source: 'ios@test Sources/Mode.swift:3; android@test Mode.kt:4',
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('a row of what a native does not write names a coder of that native', () {
      expect(
        _problems(
          withoutNoteOnIos(),
          exceptions: [
            _exception(_note, {ios}, source: 'lib/src/adapty.dart:1'),
          ],
        ),
        ['exception $_note: a not_written row names a native coder under its ref'],
      );
    });

    test('a row of a call the SDK never makes names the code of the SDK only', () {
      final row = _exception(_note, {ios}, kind: CoverageExceptionKind.notCalled);
      expect(_problems(withoutNoteOnIos(), exceptions: [row]), [
        'exception $_note: a not_called row names only files of lib/',
      ]);
      final inLib = _exception(_note, {ios}, kind: CoverageExceptionKind.notCalled, source: 'lib/src/adapty.dart:1');
      expect(_problems(withoutNoteOnIos(), exceptions: [inLib]), isEmpty);
      final alsoNative = _exception(
        _note,
        {ios},
        kind: CoverageExceptionKind.notCalled,
        source: 'lib/src/adapty.dart:1; ios@test Sources/Mode.swift:3',
      );
      expect(_problems(withoutNoteOnIos(), exceptions: [alsoNative]), [
        'exception $_note: a not_called row names only files of lib/',
      ]);
    });

    test('two rows of the same item on a platform are a problem', () {
      expect(
        _problems(
          withoutNoteOnIos(),
          exceptions: [
            _exception(_note, {ios}),
            _exception(_note, {ios}, source: 'ios@test Sources/Other.swift:3'),
          ],
        ),
        ['exception $_note: more than one row on ios'],
      );
    });

    test('a row without a source is a problem', () {
      expect(
        _problems(
          withoutNoteOnIos(),
          exceptions: [
            _exception(_note, {ios}, source: ' '),
          ],
        ),
        ['exception $_note: no source'],
      );
    });

    test('a row of an item a fixture of its platform shows is a problem: the row is to go', () {
      expect(
        _problems(
          _complete(),
          exceptions: [
            _exception(_note, {ios}),
          ],
        ),
        ['exception $_note: in a positive fixture of ios now, remove the row'],
      );
    });

    test('a row whose pointer is no node of the schema is a problem', () {
      expect(
        _problems(
          _complete(),
          exceptions: [
            _exception(r'#/$defs/Item/properties/gone', {ios}),
          ],
        ),
        ['exception #/\$defs/Item/properties/gone: no such schema node'],
      );
    });

    test('a row of an item its platform does not have to show is a problem', () {
      expect(
        _problems(
          _complete(),
          exceptions: [
            _exception(r'#/$defs/Item/properties/plan', {ios}),
          ],
        ),
        ['exception #/\$defs/Item/properties/plan: not an item ios has to show'],
      );
    });

    test('the file reads into rows, a value only where the row has one', () {
      final rows = CoverageException.parse(r'''
- pointer: '#/$defs/Mode'
  value: paid
  platforms: [android]
  kind: not_written
  reason: the native has no paid mode
  source: 'android@test Mode.kt:4'
- pointer: '#/$defs/Item/properties/note'
  platforms: [ios, android]
  kind: not_called
  reason: the SDK never asks for it
  source: 'lib/src/item.dart:3'
''');

      expect(
        [
          for (final r in rows) [r.item, r.platforms, r.kind, r.reason, r.source],
        ],
        [
          [
            r'#/$defs/Mode = "paid"',
            {android},
            CoverageExceptionKind.notWritten,
            'the native has no paid mode',
            'android@test Mode.kt:4',
          ],
          [
            _note,
            {ios, android},
            CoverageExceptionKind.notCalled,
            'the SDK never asks for it',
            'lib/src/item.dart:3',
          ],
        ],
      );
    });

    test('a row with an unknown key or kind, or without platforms, does not read', () {
      const row = "- pointer: '#/\$defs/Mode'\n  reason: r\n  source: s\n";
      expect(() => CoverageException.parse('${row}  platforms: [ios]\n  kind: maybe\n'), throwsFormatException);
      expect(() => CoverageException.parse('${row}  kind: not_written\n'), throwsFormatException);
      expect(
        () => CoverageException.parse('${row}  platforms: [ios]\n  kind: not_written\n  why: x\n'),
        throwsFormatException,
      );
    });
  });

  group('the corpus of this repository', () {
    test('shows every property, branch and value each native writes, or a row says why not', () {
      expect(
        schemaCoverageProblems(
          Corpus.load('.'),
          ContractSchema.load('.'),
          CoverageException.load('.'),
          sentMethods: {
            for (final m in NativeMethod.values) m.wireName,
            for (final r in NativeEventResponse.values) r.wireName,
          },
          refs: NativeRefs.of(ContractSource.load('.')).all,
        ),
        isEmpty,
      );
    });
  });
}

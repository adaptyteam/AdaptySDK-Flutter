// The validator against every payload the corpus can be broken into: each broken payload is rejected at the node it
// was broken at. The self-tests run the sweep on a small contract; the last group sweeps the corpus of this
// repository.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/contract_schema.dart';
import '../../tool/contract/src/corpus.dart';
import '../../tool/contract/src/overlays.dart';
import '../support/contract/temp_schema.dart';
import 'support/validator_sweep.dart';

const ios = ContractPlatform.ios;
const android = ContractPlatform.android;

/// `set` takes a value and answers a count; `os` of its request belongs to Android. The event `ping` carries a count.
final ContractSchema _schema = tempSchema(
  requests: r'''
Set.Request:
  type: object
  required: [method, value]
  properties:
    method: { const: "set" }
    value: { type: string }
    os: { type: string }
Set.Response:
  type: object
  oneOf:
    - required: [error]
      properties:
        error: { $ref: "#/$defs/Error" }
    - required: [success]
      properties:
        success: { type: integer }''',
  events: r'''
Event.Ping:
  type: object
  required: [id, count]
  properties:
    id: { const: "ping" }
    count: { type: integer }''',
  defs: '''
Error:
  type: object
  required: [adapty_code, message]
  properties:
    adapty_code: { type: integer }
    message: { type: string }''',
  overlays: const ContractOverlays(
    platformFields: [
      PlatformFieldRow(pointer: r'#/$requests/Set.Request/properties/os', platforms: {android}, source: 'test'),
    ],
  ),
);

Map<String, Object?> _case(Object? payload, {String native = 'both', Map<String, Object?>? expect}) => {
  'provenance': {'source': 'hand', 'native': native},
  'expect': expect,
  'notes': 'written by hand for this test',
  'payload': payload,
};

const _baseline = '''
- id: os-everywhere
  direction: request
  entry: Set.Request
  path: /os
  keyword: platform_field
  platform: ios
  case: set/default
  reason: r
  decision: accepted
''';

/// A corpus in a fresh temporary repository with the given files under `contract/`.
Corpus _corpus(Map<String, Object> files) {
  final root = Directory.systemTemp.createTempSync('validator_sweep_').path;
  addTearDown(() => Directory(root).deleteSync(recursive: true));
  for (final MapEntry(key: path, value: content) in files.entries) {
    File('$root/contract/$path')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content is String ? content : jsonEncode(content));
  }
  final corpus = Corpus.load(root);
  expect(corpus.problems, isEmpty);
  return corpus;
}

Map<String, Object> _files() => {
  'requests/set/default.ios.json': _case({'value': 'v', 'os': 'o'}, native: 'ios@test'),
  'responses/set/default.json': _case({'success': 1}),
  'responses/set/error.json': _case({
    'error': {'adapty_code': 1, 'message': 'm'},
  }),
  'responses/set/not_a_count.json': _case(
    {'success': 'one'},
    expect: {
      'violation': {'keyword': 'type', 'pointer': r'#/$requests/Set.Response/oneOf/1/properties/success'},
    },
  ),
  'events/ping/default.json': _case({'id': 'ping', 'count': 1}),
  'baseline/known_discrepancies.yaml': _baseline,
};

void main() {
  group('the sweep', () {
    test('every broken payload of a valid corpus is rejected where it was broken', () {
      final result = sweepCorpus(_schema, _corpus(_files()));

      expect(result.missed, isEmpty);
      expect(result.withoutMutants, isEmpty);
      for (final kind in CorpusKind.values) {
        expect(result.mutants[kind], greaterThan(0), reason: kind.name);
      }
    });

    test('a check that rejects nothing misses every broken payload, named with its case, platform and node', () {
      final result = sweepCorpus(_schema, _corpus(_files()), check: (entry, instance, platform) => const []);

      expect(result.missed, hasLength(result.total));
      expect(
        result.missed,
        containsAll([
          allOf(startsWith('contract/responses/set/default.json on ios: '), contains('/oneOf/1/properties/success')),
          allOf(
            startsWith('contract/responses/set/default.json on android: '),
            contains(r'-> #/$requests/Set.Response '),
          ),
          allOf(startsWith('contract/responses/set/error.json on ios: '), contains(r'-> #/$requests/Set.Response ')),
          allOf(startsWith('contract/requests/set/default.ios.json on ios: '), contains(r'#/$requests/Set.Request')),
          allOf(startsWith('contract/events/ping/default.json on android: '), contains(r'#/$events/Event.Ping')),
        ]),
      );
    });

    test('a broken payload rejected at another node is missed', () {
      final result = sweepCorpus(
        _schema,
        _corpus(_files()),
        check: (entry, instance, platform) => const [
          Violation(instancePath: '', keyword: 'type', schemaPointer: r'#/$defs/Error'),
        ],
      );

      expect(result.missed, hasLength(result.total));
    });

    test(
      'a response is broken by its success value and by an envelope without both keys, or a success with an error',
      () {
        final seen = <(String, Object?)>[];
        sweepCorpus(
          _schema,
          _corpus({
            'responses/set/default.json': _case({'success': 1}),
            'responses/set/error.json': _case({
              'error': {'adapty_code': 1, 'message': 'm'},
            }),
          }),
          check: (entry, instance, platform) {
            if (platform == ios) seen.add((entry.pointer, instance));
            return _schema.validate(entry, instance, platform: platform).violations;
          },
        );

        final values = [
          for (final (pointer, instance) in seen)
            if (pointer == r'#/$requests/Set.Response/oneOf/1') instance,
        ];
        expect(values, isNotEmpty);
        expect(values.map((v) => (v! as Map).keys), everyElement(anyOf(isEmpty, ['success'])));
        expect(values.where((v) => (v! as Map)['success'] is int), isEmpty);
        final envelopes = [
          for (final (pointer, instance) in seen)
            if (pointer == r'#/$requests/Set.Response') ((instance! as Map).keys.toList()..sort()).join(','),
        ];
        expect(envelopes, unorderedEquals(['', 'error,success', '']));
        expect(seen, hasLength(values.length + envelopes.length));
      },
    );

    test('a golden request is broken without the keys the baseline accepts on its platform', () {
      final payloads = <Object?>[];
      final result = sweepCorpus(
        _schema,
        _corpus({
          'requests/set/default.ios.json': _case({'value': 'v', 'os': 'o'}, native: 'ios@test'),
          'baseline/known_discrepancies.yaml': _baseline,
        }),
        check: (entry, instance, platform) {
          payloads.add(instance);
          return _schema.validate(entry, instance, platform: platform).violations;
        },
      );

      expect(result.missed, isEmpty);
      expect(payloads, isNotEmpty);
      expect(payloads.whereType<Map<String, Object?>>().where((p) => p.containsKey('os')), isEmpty);
    });

    test('a golden request the baseline does not make valid is a case without broken payloads', () {
      final result = sweepCorpus(
        _schema,
        _corpus({
          'requests/set/default.ios.json': _case({'value': 'v', 'os': 'o'}, native: 'ios@test'),
        }),
      );

      expect(result.withoutMutants, [startsWith('contract/requests/set/default.ios.json on ios: ')]);
      expect(result.total, 0);
    });

    test('a negative case is not broken further', () {
      final result = sweepCorpus(
        _schema,
        _corpus({
          'responses/set/not_a_count.json': _case(
            {'success': 'one'},
            expect: {
              'violation': {'keyword': 'type', 'pointer': r'#/$requests/Set.Response/oneOf/1/properties/success'},
            },
          ),
        }),
      );

      expect(result.total, 0);
      expect(result.withoutMutants, isEmpty);
    });
  });

  group('the corpus of this repository', () {
    test('every payload broken from a golden request, a response or an event is rejected where it was broken', () {
      final watch = Stopwatch()..start();
      final result = sweepCorpus(ContractSchema.load('.'), Corpus.load('.'));
      watch.stop();
      // ignore: avoid_print
      print(
        'validator sweep: ${result.total} broken payloads '
        '(${CorpusKind.values.map((k) => '${k.directory} ${result.mutants[k]}').join(', ')}) '
        'in ${watch.elapsedMilliseconds} ms',
      );

      expect(result.missed, isEmpty);
      expect(result.withoutMutants, isEmpty);
      for (final kind in CorpusKind.values) {
        expect(result.mutants[kind], greaterThan(0), reason: kind.name);
      }
    });
  });
}

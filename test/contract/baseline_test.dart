/// The entries of the baseline of known discrepancies turn into the violations they take away: one
/// per single entry, one per element of a batch entry, each taking away only its exact violation.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/baseline.dart';
import '../../tool/contract/src/contract_schema.dart';
import '../../tool/contract/src/contract_source.dart';
import '../../tool/contract/src/corpus.dart';
import '../../tool/contract/src/request_check.dart';
import '../../tool/contract/src/source_refs.dart';

const ios = ContractPlatform.ios;
const android = ContractPlatform.android;

BaselineEntry _entry(Map<String, Object?> fields) => BaselineEntry(
  id: fields['id']! as String,
  decision: fields['decision']! as String,
  reason: fields['reason']! as String,
  fields: fields,
);

const _single = {
  'id': 'single',
  'direction': 'request',
  'entry': 'GetProfile.Request',
  'path': '/bogus',
  'keyword': 'additionalProperties',
  'platform': 'android',
  'case': 'get_profile/bogus',
  'reason': 'r',
  'decision': 'accepted',
};

const _batch = {
  'id': 'batch',
  'direction': 'request',
  'keyword': 'platform_field',
  'items': [
    {'entry': 'Identify.Request', 'path': '/parameters/obfuscated_account_id', 'platform': 'ios', 'case': 'a'},
    {'entry': 'Identify.Request', 'path': '/parameters/app_account_token', 'platform': 'android', 'case': 'b'},
  ],
  'reason': 'r',
  'decision': 'accepted',
  'source': ['s'],
};

Violation _violation(String path, String keyword) =>
    Violation(instancePath: path, keyword: keyword, schemaPointer: r'#/$requests/X.Request');

void main() {
  test('a single entry is one item with its fields', () {
    final item = baselineItems([_entry(_single)]).single;
    expect(
      (item.id, item.entry, item.path, item.keyword, item.platform, item.caseName),
      ('single', 'GetProfile.Request', '/bogus', 'additionalProperties', android, 'get_profile/bogus'),
    );
  });

  test('a batch entry is one item per element, with the keyword of the entry', () {
    final items = baselineItems([_entry(_batch)]);
    expect(
      [for (final i in items) (i.id, i.entry, i.path, i.keyword, i.platform, i.caseName)],
      [
        ('batch', 'Identify.Request', '/parameters/obfuscated_account_id', 'platform_field', ios, 'a'),
        ('batch', 'Identify.Request', '/parameters/app_account_token', 'platform_field', android, 'b'),
      ],
    );
  });

  test('a platform_method item has the empty path of the payload', () {
    final item = baselineItems([
      _entry({..._single, 'entry': 'GetLogLevel.Request', 'path': '', 'keyword': 'platform_method'}),
    ]).single;
    expect(item.matches('GetLogLevel.Request', android, _violation('', 'platform_method')), isTrue);
  });

  test('an entry without a field an item needs is rejected with its id and the field', () {
    for (final field in ['entry', 'path', 'keyword', 'platform', 'case']) {
      expect(
        () => baselineItems([
          _entry({..._single}..remove(field)),
        ]),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', allOf(contains('single'), contains(field)))),
        reason: field,
      );
    }
  });

  test('an entry whose decision the format does not know is rejected with its id and the decision', () {
    for (final fields in [
      {..._single, 'decision': 'acepted'},
      {..._batch, 'decision': 'ignore'},
    ]) {
      expect(
        () => baselineItems([_entry(fields)]),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains(fields['id']! as String), contains(fields['decision']! as String)),
          ),
        ),
        reason: '${fields['decision']}',
      );
    }
  });

  test('a batch element with a key the format does not know or without a field is rejected', () {
    final items = _batch['items']! as List<Object?>;
    final withUnknown = {
      ..._batch,
      'items': [
        {...items.first! as Map<String, Object?>, 'keyword': 'required'},
      ],
    };
    expect(
      () => baselineItems([_entry(withUnknown)]),
      throwsA(
        isA<FormatException>().having((e) => e.message, 'message', allOf(contains('batch'), contains('keyword'))),
      ),
    );
    final withoutCase = {
      ..._batch,
      'items': [
        {...items.first! as Map<String, Object?>}..remove('case'),
      ],
    };
    expect(
      () => baselineItems([_entry(withoutCase)]),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', allOf(contains('batch'), contains('case')))),
    );
  });

  test('an item takes away only the violation of its entry, path, keyword and platform', () {
    final item = baselineItems([_entry(_single)]).single;
    final cases = {
      ('GetProfile.Request', android, '/bogus', 'additionalProperties'): true,
      ('GetFlow.Request', android, '/bogus', 'additionalProperties'): false,
      ('GetProfile.Request', ios, '/bogus', 'additionalProperties'): false,
      ('GetProfile.Request', android, '/other', 'additionalProperties'): false,
      ('GetProfile.Request', android, '/bogus/inner', 'additionalProperties'): false,
      ('GetProfile.Request', android, '/bogus', 'platform_field'): false,
    };
    for (final MapEntry(key: (entry, platform, path, keyword), :value) in cases.entries) {
      expect(
        item.matches(entry, platform, _violation(path, keyword)),
        value,
        reason: '$entry $platform $path $keyword',
      );
    }
  });

  test('every entry of the baseline names a native only under the ref the contract record is fixed to', () {
    final refs = NativeRefs.of(ContractSource.load('.'));
    expect([
      for (final entry in Corpus.load('.').baseline)
        for (final source in switch (entry.fields['source']) {
          final List<Object?> list => list.map((s) => '$s'),
          final Object source => ['$source'],
          null => const <String>[],
        })
          for (final ref in foreignRefs(source, refs)) '${entry.id}: $ref',
    ], isEmpty);
  });

  test('every item of a request case is held by that case: without it the golden request of the case is not valid', () {
    final schema = ContractSchema.load('.');
    final corpus = Corpus.load('.');
    final items = baselineItems(corpus.baseline);
    for (final item in items.where((i) => !i.caseName.startsWith('pseudo/'))) {
      final [method, caseName] = item.caseName.split('/');
      final golden = corpus.fixture(CorpusKind.request, method, caseName, item.platform);
      expect(golden, isNotNull, reason: '$item: no golden request');
      final check = checkRequest(
        schema,
        [...items.where((i) => !identical(i, item))],
        method: method,
        arguments: golden!.payload! as Map<String, Object?>,
        platform: item.platform,
        declaredCase: item.caseName,
      )!;
      expect(
        check.kept.where((v) => item.matches(check.entry.name, item.platform, v)),
        isNotEmpty,
        reason: '$item: its case is valid without it',
      );
    }
  });
}

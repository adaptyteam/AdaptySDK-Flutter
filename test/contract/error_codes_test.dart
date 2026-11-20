/// The error codes of the SDK against the natives: `contract/error_codes.yaml` gives every constant of
/// `AdaptyErrorCode` its value and the natives that declare it, with their lines under the refs the
/// contract is fixed to. The constants and the table agree both ways, every code a native answers in
/// the probe expectations or the corpus is a code of that platform in the table, and no code the table
/// lists as one the SDK has no constant for has a constant.
///
/// The natives are not read here: the table is what they declare at the refs of
/// `contract/CONTRACT_SOURCE`, and it moves with them.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/contract_source.dart';
import '../../tool/contract/src/corpus.dart';
import '../../tool/contract/src/error_codes.dart';
import '../../tool/contract/src/overlays.dart';
import '../../tool/contract/src/source_refs.dart';

const _expectationsPath = 'integration_test_app/l2a_expectations.yaml';

void main() {
  group('the checks of the table', () {
    test('read every integer constant of the class, and stop at one they cannot read', () {
      expect(constantsOf('  static const int a = 1;\n  static const int b = 20;\n'), {'a': 1, 'b': 20});
      expect(() => constantsOf('  static const int a = 1;\n  static const int b = 0x14;\n'), throwsFormatException);
    });

    test('find a changed value, a constant without a row and a row without a constant', () {
      final table = ErrorCodeTable.parse(_table(codes: [_row('a', 1), _row('b', 2), _row('c', 3)]));
      expect(constantProblems({'a': 1, 'b': 5, 'd': 4}, table), [
        'b: the SDK says 5, ${ErrorCodeTable.path} says 2',
        'd = 4: no row in ${ErrorCodeTable.path}',
        'c = 3: no constant in ${ErrorCodeTable.constantsPath}',
      ]);
    });

    test('ask a constant no native declares for a reason', () {
      final table = ErrorCodeTable.parse(
        _table(
          codes: [
            _row('a', 1, platforms: '[]'),
            _row('b', 2, platforms: '[]', reason: 'kept'),
          ],
        ),
      );
      expect(table.problems, ['codes[0] (a): declared by no native and no reason']);
    });

    test('ask every native that declares a code for the name it gives the code, and no other native', () {
      final table = ErrorCodeTable.parse(
        _table(
          codes: [
            _row('a', 1, native: ''),
            _row('b', 2, platforms: '[ios]', native: 'ios: b, android: B'),
            _row('c', 3, platforms: '[]', reason: 'kept', native: 'ios: c'),
            _row('d', 4, native: 'ios: d, android: 4'),
          ],
        ),
      );
      expect(table.problems, [
        'codes[0] (a): no native name on ios',
        'codes[0] (a): no native name on android',
        'codes[1] (b): a native name on android, which does not declare the code',
        'codes[2] (c): a native name on ios, which does not declare the code',
        'codes[3] (d): no native name on android',
      ]);
      expect(table.codes[1].native, {ContractPlatform.ios: 'b'});
    });

    test('ask a row for a reason and a source that say something', () {
      final table = ErrorCodeTable.parse(
        _table(
          codes: [
            _row('a', 1, reason: "' '"),
            _row('b', 2).replaceFirst('source: s', "source: ''"),
          ],
        ),
      );
      expect(table.problems, ['codes[0] (a): an empty reason', 'codes[1] (b): no source']);
    });

    test('find a name or a code twice, an unknown platform and an unknown key', () {
      final table = ErrorCodeTable.parse(
        _table(
          codes: [
            _row('a', 1),
            _row('a', 2),
            _row('b', 1, platforms: '[ios, web]'),
            '  - {name: c, code: 3, x: 1}\n',
          ],
        ),
      );
      expect(table.problems, [
        'codes[1] (a): the name is listed twice',
        'codes[2] (b): the code 1 is listed twice',
        'codes[2] (b): unknown platform web',
        'codes[3]: unknown keys x',
        'codes[3] (c): no source',
      ]);
    });

    test('take the codes of a platform from the rows that name it', () {
      final table = ErrorCodeTable.parse(
        _table(
          codes: [
            _row('a', 1, platforms: '[ios]'),
            _row('b', 2),
            _row('c', 3, platforms: '[]', reason: 'r'),
          ],
        ),
      );
      expect(table.codesOf(ContractPlatform.ios), {1, 2});
      expect(table.codesOf(ContractPlatform.android), {2});
    });

    test('read the codes of the probe expectations with the platform of their row', () {
      const yaml = '''
defaults:
  not_activated:
    ios: {code: 2002}
    android: {code: 20}
expectations:
  - {method: m, platform: ios, outcome: {error: {code: 4003, class: other}}}
  - {method: m, platform: android, outcome: success}
after_probe:
  - {id: x, platform: android, outcome: {error: {code: 3001, class: other}}}
''';
      expect(expectedCodes(plainYaml(yaml)), {
        (ContractPlatform.ios, 2002),
        (ContractPlatform.android, 20),
        (ContractPlatform.ios, 4003),
        (ContractPlatform.android, 3001),
      });
    });
  });

  group('the error codes of the SDK', () {
    final table = ErrorCodeTable.parse(File(ErrorCodeTable.path).readAsStringSync());
    final constants = constantsOf(File(ErrorCodeTable.constantsPath).readAsStringSync());

    test('the table reads', () {
      expect(table.problems, isEmpty);
    });

    test('every constant has a row with its value, and every row a constant', () {
      expect(constantProblems(constants, table), isEmpty);
    });

    test('every row names the native lines, or the code of the SDK, it stands on', () {
      final refs = NativeRefs.of(ContractSource.load('.')).all;
      expect([
        for (final row in [...table.codes, ...table.notInSdk])
          for (final problem in sourceProblems(row.reason ?? 'declared by the native', row.source, refs: refs))
            '${row.where}: $problem',
      ], isEmpty);
    });

    test('no code a native declares without a constant has one', () {
      expect([
        for (final row in table.notInSdk)
          for (final MapEntry(key: name, value: code) in constants.entries)
            if (code == row.code) '${row.where}: $code is the constant $name',
      ], isEmpty);
    });

    test('every code the probe expects is a code of its platform', () {
      expect([
        for (final (platform, code) in expectedCodes(plainYaml(File(_expectationsPath).readAsStringSync())))
          if (!table.codesOf(platform).contains(code)) '$_expectationsPath: $code on ${platform.name}',
      ], isEmpty);
    });

    test('every code a positive fixture of the corpus carries is a code of its platform', () {
      final corpus = Corpus.load('.');
      expect(corpus.problems, isEmpty);
      final problems = <String>[];
      for (final fixture in corpus.fixtures) {
        if (fixture.isNegative) continue;
        for (final code in adaptyCodesOf(fixture.payload)) {
          for (final platform in fixture.platform == null ? ContractPlatform.values : [fixture.platform!]) {
            if (!table.codesOf(platform).contains(code)) problems.add('${fixture.path}: $code on ${platform.name}');
          }
        }
      }
      expect(problems, isEmpty);
    });
  });
}

/// A row of the table; unless [native] is given, each known platform of [platforms] names the code after the row.
String _row(String name, int code, {String platforms = '[ios, android]', String? reason, String? native}) {
  final names =
      native ??
      [
        for (final p in ['ios', 'android'])
          if (platforms.contains(p)) '$p: ${name}_$p',
      ].join(', ');
  return '  - name: $name\n    code: $code\n    platforms: $platforms\n'
      '${names.isEmpty ? '' : '    native: {$names}\n'}'
      '${reason == null ? '' : '    reason: $reason\n'}    source: s\n';
}

String _table({required List<String> codes}) => 'codes:\n${codes.join()}';

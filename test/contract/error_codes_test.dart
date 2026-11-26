/// The error codes of the SDK against the natives: `contract/error_codes.yaml` gives every constant of
/// `AdaptyErrorCode` its value and the natives that declare it, with their lines under the refs the
/// contract is fixed to, and the line of the Flutter plugin of a platform that sends a code itself. The
/// constants and the table agree both ways, every code a platform answers in the probe expectations or
/// the corpus is a code of that platform in the table, and no code the table lists as one the SDK has no
/// constant for has a constant.
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

    test('ask every native that declares a code for a part of the source under its ref, and no other native', () {
      final table = ErrorCodeTable.parse(
        _table(
          codes: [
            _row('a', 1, platforms: '[ios]', source: 'android@ref A.kt:9'),
            _row('b', 2, source: 'ios@ref B.swift:1'),
            _row('c', 3, platforms: '[]', reason: 'kept', source: 'lib/c.dart:1; ios@ref C.swift:1'),
          ],
        ),
      );
      expect(table.problems, [
        'codes[0] (a): no part of the source under ios@',
        'codes[0] (a): a part of the source under android@, which does not declare the code',
        'codes[1] (b): no part of the source under android@',
        'codes[2] (c): a part of the source under ios@, which does not declare the code',
      ]);
    });

    test('ask a row for a reason and a source that say something', () {
      final table = ErrorCodeTable.parse(
        _table(
          codes: [
            _row('a', 1, reason: "' '"),
            _row('b', 2, source: ''),
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

    test('take a code the plugin of a platform sends itself, with no native declaring it there, as a code of that '
        'platform', () {
      final table = ErrorCodeTable.parse(
        _table(
          codes: [
            _row('a', 1, platforms: '[ios]', plugin: "{android: 'android/src/main/kotlin/A.kt:3'}"),
            _row('b', 2, platforms: '[android]', plugin: "{ios: 'ios/adapty_flutter/Sources/B.swift:5'}"),
            _row('c', 3, platforms: '[ios]'),
          ],
        ),
      );
      expect(table.problems, isEmpty);
      expect(table.codes[0].plugin, {ContractPlatform.android: 'android/src/main/kotlin/A.kt:3'});
      expect(table.codes[0].native, {ContractPlatform.ios: 'a_ios'});
      expect(table.codesOf(ContractPlatform.android), {1, 2});
      expect(table.codesOf(ContractPlatform.ios), {1, 2, 3});
    });

    test("ask the plugin entry of a platform for a line of that platform's plugin", () {
      final table = ErrorCodeTable.parse(
        _table(
          codes: [
            _row('a', 1, platforms: '[ios]', plugin: "{android: 'ios/adapty_flutter/A.swift:1'}"),
            _row('b', 2, platforms: '[android]', plugin: "{ios: 'android/src/main/kotlin/B.kt:1'}"),
            _row('c', 3, platforms: '[ios]', plugin: "{android: 'lib/src/c.dart:1'}"),
            _row('d', 4, platforms: '[ios]', plugin: "{android: 'android/src/D.kt:1, lib/d.dart:1'}"),
            _row('e', 5, platforms: '[ios]', plugin: "{web: 'android/src/E.kt:1'}"),
            _row('f', 6, platforms: '[ios]', plugin: "{android: ' '}"),
            _row('g', 7, platforms: '[ios]', plugin: "'android/src/G.kt:1'"),
            _row('h', 8, platforms: '[ios]', plugin: '{android: 53}'),
          ],
        ),
      );
      expect(table.problems, [
        'codes[0] (a): the plugin line on android is not under android/src/: ios/adapty_flutter/A.swift:1',
        'codes[1] (b): the plugin line on ios is not under ios/adapty_flutter/: android/src/main/kotlin/B.kt:1',
        'codes[2] (c): the plugin line on android is not under android/src/: lib/src/c.dart:1',
        'codes[3] (d): the plugin line on android is not under android/src/: android/src/D.kt:1, lib/d.dart:1',
        'codes[4] (e): a plugin line on unknown platform web',
        'codes[5] (f): an empty plugin line on android',
        'codes[6] (g): plugin is not a map of platforms to lines',
        'codes[7] (h): the plugin line on android is not a path with its lines: 53',
      ]);
      expect(table.codesOf(ContractPlatform.android), {2});
      expect([for (final row in table.codes) row.plugin], everyElement(isEmpty));
    });

    test('read the codes a native declares without a constant from their own list', () {
      final table = ErrorCodeTable.parse(
        '${_table(codes: [_row('a', 1)])}'
        'not_in_sdk:\n'
        "  - {code: 7, platforms: [ios], native: {ios: seven}, reason: r, source: 'ios@ref S.swift:7'}\n",
      );
      expect(table.problems, isEmpty);
      expect([for (final row in table.notInSdk) row.code], [7]);
      expect(table.notInSdk.single.native, {ContractPlatform.ios: 'seven'});
    });

    test('take a plugin line only on the row of a constant, not on a code the SDK has no constant for', () {
      final table = ErrorCodeTable.parse(
        '${_table(codes: [_row('a', 1, platforms: '[ios]')])}'
        'not_in_sdk:\n'
        "  - {code: 9, platforms: [ios], native: {ios: nine}, reason: r, source: 'ios@ref N.swift:9', "
        "plugin: {android: 'android/src/main/kotlin/N.kt:1'}}\n",
      );
      expect(table.problems, ['not_in_sdk[0]: unknown keys plugin']);
      expect(table.notInSdk.single.plugin, isEmpty);
      expect(table.codesOf(ContractPlatform.android), isEmpty);
    });

    test('find the code of an error at any depth of a payload, and only a code that is a number', () {
      expect(
        adaptyCodesOf({
          'error': {'adapty_code': 2002, 'message': 'm'},
          'items': [
            {
              'error': {'adapty_code': 3001},
            },
            {'adapty_code': '20'},
          ],
        }).toList(),
        [2002, 3001],
      );
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

    test('every row names the native or plugin lines, or the code of the SDK, it stands on', () {
      final refs = NativeRefs.of(ContractSource.load('.')).all;
      expect([
        for (final row in [...table.codes, ...table.notInSdk]) ...[
          for (final problem in sourceProblems(row.reason ?? 'declared by the native', row.source, refs: refs))
            '${row.where}: $problem',
          for (final MapEntry(key: platform, value: line) in row.plugin.entries)
            for (final problem in sourceProblems('sent by the plugin', line, refs: refs))
              '${row.where}: the plugin line on ${platform.name}: $problem',
        ],
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

/// A row of the table; unless [native] is given, each known platform of [platforms] names the code after the row, and
/// unless [source] is given, each known platform has a part of the source under its ref; [plugin], when given, is the
/// value of the row's `plugin` key.
String _row(
  String name,
  int code, {
  String platforms = '[ios, android]',
  String? reason,
  String? native,
  String? source,
  String? plugin,
}) {
  final known = [
    for (final p in ['ios', 'android'])
      if (platforms.contains(p)) p,
  ];
  final names = native ?? [for (final p in known) '$p: ${name}_$p'].join(', ');
  final parts = source ?? (known.isEmpty ? 's' : [for (final p in known) '$p@ref $name.$p:1'].join('; '));
  return '  - name: $name\n    code: $code\n    platforms: $platforms\n'
      '${names.isEmpty ? '' : '    native: {$names}\n'}'
      '${reason == null ? '' : '    reason: $reason\n'}${plugin == null ? '' : '    plugin: $plugin\n'}'
      '    source: \'$parts\'\n';
}

String _table({required List<String> codes}) => 'codes:\n${codes.join()}';

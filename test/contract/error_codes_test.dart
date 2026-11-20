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
import '../../tool/contract/src/overlays.dart';
import '../../tool/contract/src/source_refs.dart';

const _tablePath = 'contract/error_codes.yaml';
const _constantsPath = 'lib/src/models/adapty_error_code.dart';
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
        'b: the SDK says 5, $_tablePath says 2',
        'd = 4: no row in $_tablePath',
        'c = 3: no constant in $_constantsPath',
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
    final table = ErrorCodeTable.parse(File(_tablePath).readAsStringSync());
    final constants = constantsOf(File(_constantsPath).readAsStringSync());

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
        for (final code in _adaptyCodes(fixture.payload)) {
          for (final platform in fixture.platform == null ? ContractPlatform.values : [fixture.platform!]) {
            if (!table.codesOf(platform).contains(code)) problems.add('${fixture.path}: $code on ${platform.name}');
          }
        }
      }
      expect(problems, isEmpty);
    });
  });
}

/// The integer constants of the source of `AdaptyErrorCode`, by name; a constant whose value is not a
/// plain integer is a [FormatException].
Map<String, int> constantsOf(String source) {
  final constants = {
    for (final m in RegExp(r'static const int (\w+) = (\d+);').allMatches(source)) m[1]!: int.parse(m[2]!),
  };
  final declared = RegExp(r'static const ').allMatches(source).length;
  if (declared != constants.length) {
    throw FormatException('$declared constants, ${constants.length} of them read as `static const int <name> = <n>;`');
  }
  return constants;
}

/// Where [constants] (of the SDK) and the codes of [table] differ: a value, a constant without a row, a
/// row without a constant.
List<String> constantProblems(Map<String, int> constants, ErrorCodeTable table) {
  final rows = {for (final row in table.codes) row.name!: row.code};
  return [
    for (final MapEntry(key: name, value: code) in constants.entries)
      if (!rows.containsKey(name))
        '$name = $code: no row in $_tablePath'
      else if (rows[name] != code)
        '$name: the SDK says $code, $_tablePath says ${rows[name]}',
    for (final MapEntry(key: name, value: code) in rows.entries)
      if (!constants.containsKey(name)) '$name = $code: no constant in $_constantsPath',
  ]..sort((a, b) => _order(a).compareTo(_order(b)));
}

int _order(String problem) => problem.contains('no constant') ? 1 : 0;

/// A row of the table: a constant of the SDK ([name]) or a code a native declares without one.
final class ErrorCodeRow {
  const ErrorCodeRow({
    required this.where,
    required this.name,
    required this.code,
    required this.platforms,
    required this.reason,
    required this.source,
  });

  final String where;
  final String? name;
  final int code;
  final Set<ContractPlatform> platforms;
  final String? reason;
  final String source;
}

/// `contract/error_codes.yaml`: the rows of the constants ([codes]) and of the codes without one
/// ([notInSdk]), with what does not read ([problems]).
final class ErrorCodeTable {
  const ErrorCodeTable(this.codes, this.notInSdk, this.problems);

  static ErrorCodeTable parse(String text) {
    final problems = <String>[];
    final root = plainYaml(text);
    if (root is! Map<String, Object?>) return const ErrorCodeTable([], [], ['not a map']);
    final unknown = root.keys.toSet().difference(const {'codes', 'not_in_sdk'});
    if (unknown.isNotEmpty) problems.add('unknown keys ${unknown.join(', ')}');
    final names = <String>{};
    final codes = <int>{};

    List<ErrorCodeRow> rows(String key, {required bool named}) {
      final out = <ErrorCodeRow>[];
      final list = root[key];
      if (list is! List<Object?>) {
        problems.add('$key is not a list');
        return out;
      }
      for (final (i, node) in list.indexed) {
        var where = '$key[$i]';
        if (node is! Map<String, Object?>) {
          problems.add('$where is not a map');
          continue;
        }
        final extra = node.keys.toSet().difference({
          'code',
          'platforms',
          'reason',
          'source',
          if (named) 'name' else 'native',
        });
        if (extra.isNotEmpty) problems.add('$where: unknown keys ${extra.join(', ')}');
        final name = node[named ? 'name' : 'native'];
        if (name is! String || name.isEmpty) {
          problems.add('$where: no ${named ? 'name' : 'native'}');
          continue;
        }
        where = '$where ($name)';
        final code = node['code'];
        if (code is! int) {
          problems.add('$where: no code');
          continue;
        }
        if (named && !names.add(name)) problems.add('$where: the name is listed twice');
        if (!codes.add(code)) problems.add('$where: the code $code is listed twice');
        final platforms = <ContractPlatform>{};
        for (final platform in (node['platforms'] as List<Object?>?) ?? const <Object?>[]) {
          final parsed = ContractPlatform.values.where((p) => p.name == platform).firstOrNull;
          if (parsed == null) {
            problems.add('$where: unknown platform $platform');
          } else {
            platforms.add(parsed);
          }
        }
        final reason = node['reason'];
        if (platforms.isEmpty && node['platforms'] is List<Object?> && reason is! String) {
          problems.add('$where: declared by no native and no reason');
        }
        final source = node['source'];
        if (source is! String) problems.add('$where: no source');
        out.add(
          ErrorCodeRow(
            where: where,
            name: named ? name : null,
            code: code,
            platforms: platforms,
            reason: reason is String ? reason : null,
            source: source is String ? source : '',
          ),
        );
      }
      return out;
    }

    final constants = rows('codes', named: true);
    final notInSdk = root.containsKey('not_in_sdk') ? rows('not_in_sdk', named: false) : const <ErrorCodeRow>[];
    return ErrorCodeTable(constants, notInSdk, problems);
  }

  final List<ErrorCodeRow> codes;
  final List<ErrorCodeRow> notInSdk;
  final List<String> problems;

  /// The codes of the constants that the native of [platform] declares.
  Set<int> codesOf(ContractPlatform platform) => {
    for (final row in codes)
      if (row.platforms.contains(platform)) row.code,
  };
}

/// Every `code` of the probe expectations [root], with the platform of its row: the key of a default, the
/// `platform` of an expectation or of a call after the probe.
Set<(ContractPlatform, int)> expectedCodes(Object? root) {
  final out = <(ContractPlatform, int)>{};
  void walk(Object? node, ContractPlatform? platform) {
    switch (node) {
      case final Map<String, Object?> map:
        final own = switch (map['platform']) {
          final String name => ContractPlatform.parse(name),
          _ => platform,
        };
        for (final MapEntry(:key, :value) in map.entries) {
          final keyPlatform = ContractPlatform.values.where((p) => p.name == key).firstOrNull;
          if (key == 'code' && value is int) {
            if (own == null) throw FormatException('the code $value has no platform');
            out.add((own, value));
          } else {
            walk(value, keyPlatform ?? own);
          }
        }
      case final List<Object?> list:
        for (final item in list) {
          walk(item, platform);
        }
    }
  }

  walk(root, null);
  return out;
}

/// Every integer `adapty_code` in [payload].
Iterable<int> _adaptyCodes(Object? payload) sync* {
  switch (payload) {
    case final Map<String, Object?> map:
      for (final MapEntry(:key, :value) in map.entries) {
        if (key == 'adapty_code' && value is int) {
          yield value;
        } else {
          yield* _adaptyCodes(value);
        }
      }
    case final List<Object?> list:
      for (final item in list) {
        yield* _adaptyCodes(item);
      }
  }
}

String _row(String name, int code, {String platforms = '[ios, android]', String? reason}) =>
    '  - name: $name\n    code: $code\n    platforms: $platforms\n'
    '${reason == null ? '' : '    reason: $reason\n'}    source: s\n';

String _table({required List<String> codes}) => 'codes:\n${codes.join()}';

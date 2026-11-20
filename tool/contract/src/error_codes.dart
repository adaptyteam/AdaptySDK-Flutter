/// The error codes of the SDK against the natives: `contract/error_codes.yaml` gives every constant of
/// `AdaptyErrorCode` its value and the natives that declare it, with their lines under the refs the
/// contract is fixed to, and lists the codes a native declares without a constant.
library;

import 'overlays.dart' show ContractPlatform, plainYaml;

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
        '$name = $code: no row in ${ErrorCodeTable.path}'
      else if (rows[name] != code)
        '$name: the SDK says $code, ${ErrorCodeTable.path} says ${rows[name]}',
    for (final MapEntry(key: name, value: code) in rows.entries)
      if (!constants.containsKey(name)) '$name = $code: no constant in ${ErrorCodeTable.constantsPath}',
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
    required this.native,
  });

  final String where;
  final String? name;
  final int code;
  final Set<ContractPlatform> platforms;
  final String? reason;
  final String source;

  /// The name each native that declares the code gives it.
  final Map<ContractPlatform, String> native;
}

/// `contract/error_codes.yaml`: the rows of the constants ([codes]) and of the codes without one
/// ([notInSdk]), with what does not read ([problems]).
final class ErrorCodeTable {
  const ErrorCodeTable(this.codes, this.notInSdk, this.problems);

  /// The table relative to the repository root.
  static const path = 'contract/error_codes.yaml';

  /// The source of the constants relative to the repository root.
  static const constantsPath = 'lib/src/models/adapty_error_code.dart';

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
          'native',
          'reason',
          'source',
          if (named) 'name',
        });
        if (extra.isNotEmpty) problems.add('$where: unknown keys ${extra.join(', ')}');
        final name = node['name'];
        if (named && (name is! String || name.isEmpty)) {
          problems.add('$where: no name');
          continue;
        }
        final code = node['code'];
        if (code is! int) {
          problems.add('$where: no code');
          continue;
        }
        where = '$where (${named ? name : code})';
        if (named && !names.add(name! as String)) problems.add('$where: the name is listed twice');
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
        final native = <ContractPlatform, String>{};
        final nativeNames = switch (node['native']) {
          final Map<String, Object?> map => map,
          _ => const <String, Object?>{},
        };
        for (final platform in platforms) {
          if (nativeNames[platform.name] case final String nativeName when nativeName.trim().isNotEmpty) {
            native[platform] = nativeName;
          } else {
            problems.add('$where: no native name on ${platform.name}');
          }
        }
        for (final key in nativeNames.keys) {
          if (!platforms.any((p) => p.name == key)) {
            problems.add('$where: a native name on $key, which does not declare the code');
          }
        }
        final reason = node['reason'];
        if (reason is String && reason.trim().isEmpty) problems.add('$where: an empty reason');
        if (platforms.isEmpty && node['platforms'] is List<Object?> && reason is! String) {
          problems.add('$where: declared by no native and no reason');
        }
        final source = node['source'];
        if (source is! String || source.trim().isEmpty) problems.add('$where: no source');
        out.add(
          ErrorCodeRow(
            where: where,
            name: named ? name! as String : null,
            code: code,
            platforms: platforms,
            reason: reason is String ? reason : null,
            source: source is String ? source : '',
            native: native,
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
Iterable<int> adaptyCodesOf(Object? payload) sync* {
  switch (payload) {
    case final Map<String, Object?> map:
      for (final MapEntry(:key, :value) in map.entries) {
        if (key == 'adapty_code' && value is int) {
          yield value;
        } else {
          yield* adaptyCodesOf(value);
        }
      }
    case final List<Object?> list:
      for (final item in list) {
        yield* adaptyCodesOf(item);
      }
  }
}

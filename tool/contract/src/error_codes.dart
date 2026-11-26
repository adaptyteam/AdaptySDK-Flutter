/// The error codes of the SDK against the natives: `contract/error_codes.yaml` gives every constant of
/// `AdaptyErrorCode` its value and the natives that declare it, with their lines under the refs the
/// contract is fixed to, and the line of the Flutter plugin of a platform that sends the code itself, and
/// lists the codes a native declares without a constant.
library;

import 'dart:io';

import 'overlays.dart' show ContractPlatform, plainYaml;
import 'source_refs.dart' show pluginDirectoryOf;

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
    this.plugin = const {},
  });

  final String where;
  final String? name;
  final int code;
  final Set<ContractPlatform> platforms;
  final String? reason;
  final String source;

  /// The name each native that declares the code gives it.
  final Map<ContractPlatform, String> native;

  /// The line of the Flutter plugin of each platform whose plugin sends the code itself.
  final Map<ContractPlatform, String> plugin;
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
          if (named) ...['name', 'plugin'],
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
        final plugin = <ContractPlatform, String>{};
        switch (named ? node['plugin'] : null) {
          case null:
            break;
          case final Map<String, Object?> lines:
            for (final MapEntry(:key, value: line) in lines.entries) {
              final platform = ContractPlatform.values.where((p) => p.name == key).firstOrNull;
              if (platform == null) {
                problems.add('$where: a plugin line on unknown platform $key');
              } else if (line is! String) {
                problems.add('$where: the plugin line on $key is not a path with its lines: $line');
              } else if (line.trim().isEmpty) {
                problems.add('$where: an empty plugin line on $key');
              } else if (!line.split(RegExp(r';|, ')).every((p) => p.trim().startsWith(pluginDirectoryOf(platform)))) {
                problems.add('$where: the plugin line on $key is not under ${pluginDirectoryOf(platform)}: $line');
              } else {
                plugin[platform] = line;
              }
            }
          default:
            problems.add('$where: plugin is not a map of platforms to lines');
        }
        final reason = node['reason'];
        if (reason is String && reason.trim().isEmpty) problems.add('$where: an empty reason');
        if (platforms.isEmpty && node['platforms'] is List<Object?> && reason is! String) {
          problems.add('$where: declared by no native and no reason');
        }
        final source = node['source'];
        if (source is! String || source.trim().isEmpty) {
          problems.add('$where: no source');
        } else {
          final under = {
            for (final part in source.split(';'))
              if (RegExp(r'^\s*(ios|android)@').firstMatch(part) case final match?) match[1]!,
          };
          for (final platform in platforms) {
            if (!under.contains(platform.name)) problems.add('$where: no part of the source under ${platform.name}@');
          }
          for (final name in under) {
            if (!platforms.any((p) => p.name == name)) {
              problems.add('$where: a part of the source under $name@, which does not declare the code');
            }
          }
        }
        out.add(
          ErrorCodeRow(
            where: where,
            name: named ? name! as String : null,
            code: code,
            platforms: platforms,
            reason: reason is String ? reason : null,
            source: source is String ? source : '',
            native: native,
            plugin: plugin,
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

  /// The codes of the constants that [platform] returns: the ones its native declares and the ones its Flutter
  /// plugin sends itself.
  Set<int> codesOf(ContractPlatform platform) => {
    for (final row in codes)
      if (row.platforms.contains(platform) || row.plugin.containsKey(platform)) row.code,
  };
}

/// What is wrong with the plugin lines of [row]: a part of one names lines of which none sends the code, that is, none
/// holds its value as a number, the name of its constant or a name a native gives it, as a whole word. Kotlin and
/// Swift write a code either way: `put("adapty_code", 4001)`, `AdaptyError.ErrorCode.decodingFailed.rawValue`. A part
/// whose file or lines do not read is left to the check of the sources. The files are looked up under [root].
List<String> pluginLineProblems(ErrorCodeRow row, {String root = '.'}) {
  final words = {'${row.code}', ?row.name, ...row.native.values};
  final holds = RegExp('(?<![A-Za-z0-9_])(${words.map(RegExp.escape).join('|')})(?![A-Za-z0-9_])');
  return [
    for (final MapEntry(key: platform, value: line) in row.plugin.entries)
      for (final part in line.split(RegExp(r';|, ')).map((p) => p.trim()))
        if (_namedLines(part, root) case final lines? when !lines.any(holds.hasMatch))
          '${row.where}: the plugin line on ${platform.name} does not send ${row.code}: no line of $part holds '
              '${row.code} or a name of it',
  ];
}

/// The lines [part] (`<path>:<lines>`, as `N`, `N-M` and several of them joined by commas) names in its file under
/// [root], or null if it names no lines or its file does not read.
List<String>? _namedLines(String part, String root) {
  final match = RegExp(r'^(.+):(\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*)$').firstMatch(part);
  final file = File('$root/${match?[1]}');
  if (match == null || !file.existsSync()) return null;
  final lines = file.readAsLinesSync();
  return [
    for (final range in match[2]!.split(','))
      for (var n = int.parse(range.split('-').first); n <= int.parse(range.split('-').last) && n <= lines.length; n++)
        lines[n - 1],
  ];
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

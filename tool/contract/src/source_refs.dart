/// The sources that rows of the contract give for what they say: files of this repository with their
/// lines, and files of a native under the ref the contract is fixed to.
library;

import 'dart:io';

import 'contract_source.dart';
import 'overlays.dart' show ContractPlatform;

/// The refs of the natives a contract record is fixed to, as sources, notes and provenances name
/// them: `ios@<ref>` and `android@<version of the crossplatform library>`.
final class NativeRefs {
  const NativeRefs({required this.ios, required this.android});

  /// The refs of [source].
  factory NativeRefs.of(ContractSource source) =>
      NativeRefs(ios: 'ios@${source.iosRef}', android: 'android@${source.androidCrossplatform}');

  final String ios;
  final String android;

  /// The ref of [platform].
  String of(ContractPlatform platform) => switch (platform) {
    ContractPlatform.ios => ios,
    ContractPlatform.android => android,
  };

  /// Both refs.
  Set<String> get all => {ios, android};
}

/// Every ref of a native that [text] names (`ios@…`, `android@…`) and that is not the one of its
/// platform in [refs], once each, in the order of the text.
List<String> foreignRefs(String text, NativeRefs refs) => {
  for (final match in _ref.allMatches(text))
    if (match[0] != refs.of(ContractPlatform.parse(match[1]!))) match[0]!,
}.toList();

/// A ref of a native in a source: the platform, an at sign and the ref up to a space or punctuation
/// that ends it.
final _ref = RegExp(r"(?<![\w-])(ios|android)@[^\s:;,()'\x22]*");

/// What is wrong with the [reason] and the [source] of a row that explains a decision: both say something; no path of a
/// file steps out of its directory with `..`; every file of this repository the source names (`lib/`, `test/`,
/// `contract/`, and the Flutter plugin under `ios/adapty_flutter/` and `android/src/`) exists and has the lines it
/// names, and names lines that are not the whole file: neither no lines nor one range from the first line to the last;
/// every other part of the source starts with the ref of a native the contract is fixed to ([refs]), followed by its
/// files. The files of this repository are looked up under [root].
List<String> sourceProblems(String reason, String source, {required Set<String> refs, String root = '.'}) {
  if (reason.trim().isEmpty) return ['no reason'];
  if (source.trim().isEmpty) return ['no source'];
  final problems = <String>[];
  final file = RegExp(r'^([A-Za-z0-9_.+/-]+?)(?::(\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*))?$');
  for (final segment in source.split(';').map((s) => s.trim())) {
    if (_repositoryFile.hasMatch(segment)) {
      for (final part in segment.split(', ')) {
        final match = file.firstMatch(part);
        if (match == null) {
          problems.add('$part: not a file with its lines');
          continue;
        }
        if (_stepsOut(match.group(1)!)) {
          problems.add('$part: a path with ..');
          continue;
        }
        final path = File('$root/${match.group(1)}');
        if (!path.existsSync()) {
          problems.add('${match.group(1)}: no such file in this repository');
          continue;
        }
        final last = (match.group(2) ?? '0').split(RegExp('[,-]')).map(int.parse).reduce((a, b) => a > b ? a : b);
        final lines = path.readAsLinesSync().length;
        if (last > lines) problems.add('$part: the file has $lines lines');
        if (_namesWholeFile(match.group(2), lines)) {
          problems.add('$part: names the whole file, not the lines that decide');
        }
      }
      continue;
    }
    final ref = RegExp(r'^(\S+@\S+) (.+)$').firstMatch(segment);
    if (ref == null) {
      problems.add('$segment: not under the ref of a native the contract is fixed to');
    } else if (!refs.contains(ref.group(1))) {
      problems.add('$segment: ${ref.group(1)} is not a ref the contract is fixed to');
    } else {
      for (final part in ref.group(2)!.split(', ')) {
        final match = file.firstMatch(part);
        if (match == null) {
          problems.add('$part: not a file with its lines');
        } else if (_stepsOut(match.group(1)!)) {
          problems.add('$part: a path with ..');
        }
      }
    }
  }
  return problems;
}

/// A part of a source that names files of this repository: the SDK, its tests, the contract and the Flutter plugin.
final _repositoryFile = RegExp('^(${_repositoryDirectories.map(RegExp.escape).join('|')})');

/// The directories of this repository a source can name files under.
final _repositoryDirectories = [
  'lib/',
  'test/',
  'contract/',
  for (final platform in ContractPlatform.values) pluginDirectoryOf(platform),
];

/// The directory of the Flutter plugin of [platform] in this repository: the files a source names under it are files
/// of this repository, and the `plugin` line of a row of `contract/error_codes.yaml` lies under it.
String pluginDirectoryOf(ContractPlatform platform) => switch (platform) {
  ContractPlatform.ios => 'ios/adapty_flutter/',
  ContractPlatform.android => 'android/src/',
};

/// Whether [lines], the lines a part of a source names in a file of [count] lines, are the whole file: no lines at
/// all, or the one range from the first line to the last.
bool _namesWholeFile(String? lines, int count) {
  if (lines == null) return true;
  final range = RegExp(r'^1-(\d+)$').firstMatch(lines);
  return range != null && int.parse(range[1]!) == count;
}

/// Whether [path] has a `..` segment, which would lead out of the directory it names.
bool _stepsOut(String path) => path.split('/').contains('..');

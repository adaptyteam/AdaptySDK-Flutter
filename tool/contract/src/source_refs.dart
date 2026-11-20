/// The sources that rows of the contract give for what they say: files of this repository with their
/// lines, and files of a native under the ref the contract is fixed to.
library;

import 'dart:io';

/// What is wrong with the [reason] and the [source] of a row that explains a decision: both say
/// something; every file of this repository the source names (`lib/`, `test/`, `contract/`) exists
/// and has the lines it names; every other part of the source starts with the ref of a native the
/// contract is fixed to ([refs]), followed by its files. The files of this repository are looked up
/// under [root].
List<String> sourceProblems(String reason, String source, {required Set<String> refs, String root = '.'}) {
  if (reason.trim().isEmpty) return ['no reason'];
  if (source.trim().isEmpty) return ['no source'];
  final problems = <String>[];
  final file = RegExp(r'^([A-Za-z0-9_./-]+?)(?::(\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*))?$');
  for (final segment in source.split(';').map((s) => s.trim())) {
    if (RegExp(r'^(lib|test|contract)/').hasMatch(segment)) {
      for (final part in segment.split(', ')) {
        final match = file.firstMatch(part);
        if (match == null) {
          problems.add('$part: not a file with its lines');
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
        if (file.firstMatch(part) == null) problems.add('$part: not a file with its lines');
      }
    }
  }
  return problems;
}

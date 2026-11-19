import 'dart:convert';
import 'dart:io';

import 'src/api_gate.dart';

// Usage, from the repository root: dart run tool/api/check_api.dart [--update] [--offline] [--release-line]
//
// Extracts the public API with dart_apitool and compares it with tool/api/public_api.json. Without
// --offline it also compares the API with the last release on pub.dev and checks that pubspec.yaml and
// CHANGELOG.md account for the difference. --update rewrites the snapshot first and then runs the same
// checks. --release-line (or ADAPTY_RELEASE_LINE=true) compares with the newest release below the pubspec
// version instead of the newest one not above it.
//
// Exit codes: 0 — ok; 1 — a check failed; 2 — dart_apitool is not installed.
const _snapshotPath = 'tool/api/public_api.json';
const _apitoolVersion = '0.23.2';
const _flags = {'--update', '--offline', '--release-line'};

Future<void> main(List<String> args) async {
  final unknown = args.where((arg) => !_flags.contains(arg)).toList();
  if (unknown.isNotEmpty) {
    stderr.writeln('unknown arguments: ${unknown.join(' ')}');
    stderr.writeln('usage: dart run tool/api/check_api.dart [--update] [--offline] [--release-line]');
    exit(1);
  }
  final update = args.contains('--update');
  final offline = args.contains('--offline');
  final releaseLine = args.contains('--release-line') || Platform.environment['ADAPTY_RELEASE_LINE'] == 'true';

  final version = await _apitool(['--version']);
  if (version.exitCode != 0 || !apitoolVersionMatches('${version.stdout}', _apitoolVersion)) {
    stderr.writeln(
      'dart_apitool $_apitoolVersion is not installed: install it with: '
      'dart pub global activate dart_apitool $_apitoolVersion',
    );
    exit(2);
  }

  final temp = Directory.systemTemp.createTempSync('adapty_api_');
  final int code;
  try {
    code = await _check(temp.path, update: update, offline: offline, releaseLine: releaseLine);
  } finally {
    temp.deleteSync(recursive: true);
  }
  exit(code);
}

Future<int> _check(String temp, {required bool update, required bool offline, required bool releaseLine}) async {
  final extractedPath = '$temp/api.json';
  final extract = await _apitool(['extract', '--input', '.', '--output', extractedPath]);
  if (extract.exitCode != 0) {
    stdout.writeln('dart_apitool extract failed (exit ${extract.exitCode}): ${_reason(extract)}');
    return 1;
  }
  final snapshot = normalizeApiSnapshot(File(extractedPath).readAsStringSync());
  final snapshotFile = File(_snapshotPath);
  if (update) {
    snapshotFile.writeAsStringSync(snapshot);
    stdout.writeln('updated $_snapshotPath');
  }
  final snapshotMatches = snapshotFile.existsSync() && snapshotFile.readAsStringSync() == snapshot;

  final pubspecVersion = RegExp(
    r'^version:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!;
  final changelog = File('CHANGELOG.md').readAsStringSync();
  final lastRelease = lastReleaseFromChangelog(changelog, pubspecVersion: pubspecVersion, releaseLine: releaseLine);

  ApiDiffReport? diff;
  String? diffError;
  if (!offline) {
    final reportPath = '$temp/diff.json';
    final result = await _apitool([
      'diff',
      '--old',
      'pub://adapty_flutter/$lastRelease',
      '--new',
      '.',
      '--version-check-mode=none',
      '--report-format=json',
      '--report-file-path=$reportPath',
    ]);
    if (result.exitCode == 0) {
      diff = ApiDiffReport.fromApitoolJson(jsonDecode(File(reportPath).readAsStringSync()) as Map<String, Object?>);
      stdout.writeln('API changes against $lastRelease: ${diff.changes.length}');
      for (final change in diff.changes) {
        stdout.writeln('  [${change.breaking ? 'breaking' : 'non-breaking'}] ${change.description}');
      }
    } else {
      diffError = _reason(result);
    }
  }

  final result = evaluateApiGate(
    ApiGateInput(
      pubspecVersion: pubspecVersion,
      lastRelease: lastRelease,
      releaseLine: releaseLine,
      snapshotMatches: snapshotMatches,
      diff: diff,
      diffError: diffError,
      changelogSectionForVersion: changelogSection(changelog, pubspecVersion),
    ),
  );
  if (result.ok) {
    stdout.writeln('ok');
    return 0;
  }
  result.failures.forEach(stdout.writeln);
  return 1;
}

/// Runs dart_apitool with the Dart that runs this script: the tool then picks the Flutter SDK next to it.
Future<ProcessResult> _apitool(List<String> args) =>
    Process.run(Platform.resolvedExecutable, ['pub', 'global', 'run', 'dart_apitool:main', ...args]);

/// The last line the tool printed to stderr, or to stdout when stderr is empty, without its
/// `Error: Exception:` prefix.
String _reason(ProcessResult result) {
  String lastLine(Object? output) =>
      '$output'.split('\n').map((line) => line.trim()).lastWhere((line) => line.isNotEmpty, orElse: () => '');
  final stderrLine = lastLine(result.stderr);
  final line = stderrLine.isNotEmpty ? stderrLine : lastLine(result.stdout);
  return line.replaceFirst(RegExp(r'^Error: (Exception: )?'), '');
}

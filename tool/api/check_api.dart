import 'dart:convert';
import 'dart:io';

import 'src/api_gate.dart';

// Usage, from the repository root: dart run tool/api/check_api.dart [--update] [--offline] [--release-line]
//
// Extracts the public API with dart_apitool and compares it with tool/api/public_api.json. Without
// --offline it also compares the API with the last release on pub.dev and checks that pubspec.yaml and
// CHANGELOG.md account for the difference. --update rewrites the snapshot first and then runs the same
// checks. --release-line (or ADAPTY_RELEASE_LINE=true) compares with the newest release below the pubspec
// version instead of the newest one not above it. A dart_apitool run that fails because pub could not reach
// pub.dev is run again, up to three runs in all.
//
// Exit codes: 0 — ok; 1 — a check failed or an input could not be read; 2 — dart_apitool is not installed.
const _snapshotPath = 'tool/api/public_api.json';
const _apitoolVersion = '0.23.2';
const _flags = {'--update', '--offline', '--release-line'};
const _pubAttempts = 3;
const _pubPause = Duration(seconds: 20);

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
  var code = 1;
  try {
    code = await _check(temp.path, update: update, offline: offline, releaseLine: releaseLine);
  } on FormatException catch (error) {
    stdout.writeln(error.message);
  } on FileSystemException catch (error) {
    stdout.writeln('${error.message}: ${error.path}');
  } finally {
    temp.deleteSync(recursive: true);
  }
  exit(code);
}

Future<int> _check(String temp, {required bool update, required bool offline, required bool releaseLine}) async {
  final extractedPath = '$temp/api.json';
  final extract = await _apitool(
    apitoolExtractArgs(root: '.', temp: temp, output: extractedPath),
    environment: apitoolEnvironment(temp),
    readsPub: true,
  );
  if (extract.exitCode != 0) {
    final networkError = apitoolNeedsNetwork('${extract.stdout}\n${extract.stderr}');
    stdout.writeln(
      'dart_apitool extract failed (exit ${extract.exitCode}): ${_reason(extract)}'
      '${networkError ? ' (network access is required)' : ''}',
    );
    _printTail(extract);
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
  ).firstMatch(File('pubspec.yaml').readAsStringSync())?.group(1);
  if (pubspecVersion == null) throw const FormatException('pubspec.yaml has no version');
  final changelog = File('CHANGELOG.md').readAsStringSync();
  final lastRelease = lastReleaseFromChangelog(changelog, pubspecVersion: pubspecVersion, releaseLine: releaseLine);

  ApiDiffReport? diff;
  String? diffError;
  var diffNeedsNetwork = false;
  ProcessResult? failedDiff;
  if (!offline) {
    final reportPath = '$temp/diff.json';
    final result = await _apitool(
      apitoolDiffArgs(root: '.', temp: temp, old: 'pub://adapty_flutter/$lastRelease', report: reportPath),
      environment: apitoolEnvironment(temp),
      readsPub: true,
    );
    if (result.exitCode == 0) {
      diff = _readReport(reportPath);
      stdout.writeln('API changes against $lastRelease: ${diff.changes.length}');
      for (final change in diff.changes) {
        stdout.writeln('  [${change.breaking ? 'breaking' : 'non-breaking'}] ${change.description}');
      }
    } else {
      diffError = _reason(result);
      diffNeedsNetwork = apitoolNeedsNetwork('${result.stdout}\n${result.stderr}');
      failedDiff = result;
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
      diffNeedsNetwork: diffNeedsNetwork,
      changelogSectionForVersion: changelogSection(changelog, pubspecVersion),
    ),
  );
  if (result.ok) {
    stdout.writeln('ok');
    return 0;
  }
  result.failures.forEach(stdout.writeln);
  if (failedDiff != null) _printTail(failedDiff);
  return 1;
}

ApiDiffReport _readReport(String path) {
  final text = File(path).readAsStringSync();
  try {
    return ApiDiffReport.fromApitoolJson(jsonDecode(text) as Map<String, Object?>);
  } catch (error) {
    throw FormatException('cannot read the dart_apitool report: ${error is FormatException ? error.message : error}');
  }
}

/// Runs dart_apitool with the Dart that runs this script: the tool then picks the Flutter SDK next to it. [environment]
/// adds to the environment of this script. A run that [readsPub] is run again while it fails because pub could not
/// reach pub.dev, up to [_pubAttempts] runs, [_pubPause] apart.
Future<ProcessResult> _apitool(List<String> args, {Map<String, String>? environment, bool readsPub = false}) {
  Future<ProcessResult> run() => Process.run(Platform.resolvedExecutable, [
    'pub',
    'global',
    'run',
    'dart_apitool:main',
    ...args,
  ], environment: environment);
  if (!readsPub) return run();
  return retryNetworkFailures(
    run,
    attempts: _pubAttempts,
    pause: _pubPause,
    onRetry: (attempt, failed) => stdout.writeln(
      'dart_apitool ${args.first} could not reach pub.dev (run $attempt of $_pubAttempts): ${_reason(failed)} '
      'Running it again in ${_pubPause.inSeconds} s.',
    ),
  );
}

/// Prints the end of what a failed dart_apitool run printed: the reason alone can leave out the cause.
void _printTail(ProcessResult result) {
  final tail = apitoolOutputTail(stdout: '${result.stdout}', stderr: '${result.stderr}');
  if (tail.isNotEmpty) stdout.writeln(tail);
}

String _reason(ProcessResult result) => apitoolFailureReason(stdout: '${result.stdout}', stderr: '${result.stderr}');

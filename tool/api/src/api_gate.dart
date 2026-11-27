import 'dart:convert';
import 'dart:io';

import 'api_input.dart';

/// One change between the last release and this tree, as `dart_apitool diff` reports it.
final class ApiChange {
  const ApiChange(this.description, {required this.breaking});

  final String description;
  final bool breaking;
}

/// The changes of a `dart_apitool diff --report-format=json` report.
final class ApiDiffReport {
  const ApiDiffReport(this.changes);

  final List<ApiChange> changes;

  /// Reads the `breakingChanges` and `nonBreakingChanges` trees of the report. The tool leaves out a
  /// section that has no changes. A change is described by the labels on its path and its own text,
  /// for example `Class Adapty > Method getFlow: Name of parameter "placementId" changed. …`.
  static ApiDiffReport fromApitoolJson(Map<String, Object?> json) {
    final report = json['report'] as Map<String, Object?>;
    final changes = <ApiChange>[];
    for (final section in ['breakingChanges', 'nonBreakingChanges']) {
      final root = report[section] as Map<String, Object?>?;
      if (root != null) _collectChanges(root['children'] as List<Object?>, const [], changes);
    }
    return ApiDiffReport(changes);
  }

  static void _collectChanges(List<Object?> nodes, List<String> path, List<ApiChange> into) {
    for (final node in nodes.cast<Map<String, Object?>>()) {
      final description = node['changeDescription'] as String?;
      if (description != null) {
        final location = path.isEmpty ? '' : '${path.join(' > ')}: ';
        into.add(ApiChange('$location$description', breaking: node['isBreaking'] == true));
      } else {
        _collectChanges(node['children'] as List<Object?>, [...path, node['label'] as String], into);
      }
    }
  }
}

/// Everything the gate decides on, gathered by `check_api.dart`.
///
/// [diff] and [diffError] are both `null` when the tree was not compared with [lastRelease] (`--offline`).
final class ApiGateInput {
  const ApiGateInput({
    required this.pubspecVersion,
    required this.lastRelease,
    required this.releaseLine,
    required this.snapshotMatches,
    this.diff,
    this.diffError,
    this.changelogSectionForVersion,
    this.diffNeedsNetwork = false,
  });

  final String pubspecVersion;
  final String lastRelease;
  final bool releaseLine;
  final bool snapshotMatches;
  final ApiDiffReport? diff;
  final String? diffError;
  final String? changelogSectionForVersion;

  /// Whether the comparison failed because pub could not reach pub.dev ([apitoolNeedsNetwork]).
  final bool diffNeedsNetwork;
}

/// The arguments of `dart_apitool extract` that read a copy of the package at [root] and write the API to [output].
/// The copy is made in [temp] (see [copyApiInput]).
List<String> apitoolExtractArgs({required String root, required String temp, required String output}) => [
  'extract',
  '--input',
  _apiInputIn(root, temp),
  '--output',
  output,
];

/// The arguments of `dart_apitool diff` that compare a copy of the package at [root] with [old], a
/// `pub://adapty_flutter/<version>` reference, and write a JSON report to [report]. The copy in [temp] that
/// [apitoolExtractArgs] made is read again; without one it is made.
List<String> apitoolDiffArgs({
  required String root,
  required String temp,
  required String old,
  required String report,
}) => [
  'diff',
  '--old',
  old,
  '--new',
  _apiInputIn(root, temp),
  '--version-check-mode=none',
  '--report-format=json',
  '--report-file-path=$report',
];

/// The environment of a `dart_apitool` run that makes its own temporary folders in [temp]. The tool copies the
/// package it reads into a temporary folder and leaves the copy behind when it fails; in [temp] the copy goes away
/// with it.
Map<String, String> apitoolEnvironment(String temp) => {'TMPDIR': temp};

/// The copy of the package at [root] in [temp], made on the first call.
String _apiInputIn(String root, String temp) {
  final copy = '$temp/$apiInputName';
  return Directory(copy).existsSync() ? copy : copyApiInput(root, temp);
}

/// Whether `dart_apitool --version` printed [expectedVersion]. The version is the last line: when pub rebuilds
/// the tool first (after a Dart SDK change, for example), its own output comes before it.
bool apitoolVersionMatches(String versionOutput, String expectedVersion) {
  final lines = versionOutput.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty);
  return lines.isNotEmpty && lines.last == expectedVersion;
}

/// Whether the [output] of a failed `dart_apitool` run shows that pub could not reach pub.dev: no connection, or a
/// server error that pub's own tries did not outlast.
bool apitoolNeedsNetwork(String output) =>
    RegExp(r'SocketException|ClientException|socket error|\b5\d\d [^\n]* trying to find package').hasMatch(output);

/// Runs [run], a `dart_apitool` command that reads pub.dev, again while it fails because pub could not reach pub.dev
/// ([apitoolNeedsNetwork]), up to [attempts] runs in all and [pause] apart, and returns the last result. pub tries a
/// request again for some seconds by itself; a run on CI can still meet a minute of trouble with pub.dev or with the
/// network of the runner. [onRetry] is told of each failed run before the next one, with its number.
Future<ProcessResult> retryNetworkFailures(
  Future<ProcessResult> Function() run, {
  int attempts = 3,
  Duration pause = const Duration(seconds: 20),
  void Function(int attempt, ProcessResult failed)? onRetry,
}) async {
  var result = await run();
  for (var attempt = 1; attempt < attempts && _failedForNetwork(result); attempt++) {
    onRetry?.call(attempt, result);
    await Future<void>.delayed(pause);
    result = await run();
  }
  return result;
}

bool _failedForNetwork(ProcessResult result) =>
    result.exitCode != 0 && apitoolNeedsNetwork('${result.stdout}\n${result.stderr}');

/// Why `dart_apitool` failed, from what it printed: the last `Error:` line of [stderr], else its last line, or the
/// last line of [stdout] when [stderr] is empty, without the `Error: Exception:` prefix. The lines below an error
/// can be a frame drawn around the offending source, or the rest of a message whose cause is on the first line.
String apitoolFailureReason({required String stdout, required String stderr}) {
  List<String> linesOf(String output) =>
      output.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
  final stderrLines = linesOf(stderr);
  final stdoutLines = linesOf(stdout);
  final String line;
  if (stderrLines.isNotEmpty) {
    line = stderrLines.lastWhere((line) => line.startsWith('Error: '), orElse: () => stderrLines.last);
  } else {
    line = stdoutLines.isEmpty ? '' : stdoutLines.last;
  }
  return line.replaceFirst(RegExp(r'^Error: (Exception: )?'), '');
}

/// The last [lines] lines of what a failed `dart_apitool` run printed, under a heading that names the stream:
/// [stderr] when it has text, else [stdout]; empty when both are blank. Blank lines at the end are dropped.
///
/// stderr comes first because the tool also repeats there what a failed subprocess printed, and the line that
/// names the cause can be the last one: when Flutter fails to copy the plugin during `pub get`, the reason line says
/// only "Failed to copy plugin", and the rsync error with the file it could not read comes at the end.
String apitoolOutputTail({required String stdout, required String stderr, int lines = 40}) {
  final (name, text) = stderr.trim().isNotEmpty ? ('stderr', stderr) : ('stdout', stdout);
  final all = text.trimRight().split('\n');
  if (all.length == 1 && all.single.trim().isEmpty) return '';
  final tail = all.skip(all.length > lines ? all.length - lines : 0).toList();
  return ['--- dart_apitool $name (last ${tail.length} lines) ---', ...tail].join('\n');
}

final class ApiGateResult {
  const ApiGateResult(this.failures);

  final List<String> failures;

  bool get ok => failures.isEmpty;
}

const _breakingHeading = '### ⚠️ Breaking';

ApiGateResult evaluateApiGate(ApiGateInput input) {
  final failures = <String>[];
  if (!input.snapshotMatches) {
    failures.add('public API changed: review the diff and run: dart run tool/api/check_api.dart --update');
  }
  final diffError = input.diffError;
  if (diffError != null) {
    final cause = input.diffNeedsNetwork
        ? ' (pub.dev could not be reached: the network or pub.dev failed, not the API; run the check again)'
        : '';
    failures.add('cannot compare with adapty_flutter ${input.lastRelease}: $diffError$cause');
  }
  final diff = input.diff;
  if (diff != null && diff.changes.isNotEmpty) {
    if (input.pubspecVersion == input.lastRelease) {
      failures.add(
        'the API differs from released ${input.lastRelease}, but pubspec.yaml still says ${input.lastRelease}: '
        'start the development version (X.Y.0-dev.1) first',
      );
    } else {
      final breaking = [
        for (final change in diff.changes)
          if (change.breaking) change.description,
      ];
      final majorBump = _Version.parse(input.pubspecVersion).major > _Version.parse(input.lastRelease).major;
      final breakingLine = input.changelogSectionForVersion?.contains(_breakingHeading) ?? false;
      if (breaking.isNotEmpty && !majorBump && !breakingLine) {
        failures.add(
          "breaking change without a major version bump or a '$_breakingHeading' line in CHANGELOG.md: "
          '${breaking.join('; ')}',
        );
      }
    }
  }
  return ApiGateResult(failures);
}

final _releaseHeading = RegExp(r'^# (\d+\.\d+\.\d+)$', multiLine: true);

/// The released version to compare with: the newest `# X.Y.Z` heading (no pre-release suffix) that is not
/// above [pubspecVersion], or, on a release line, strictly below it.
String lastReleaseFromChangelog(String changelog, {required String pubspecVersion, required bool releaseLine}) {
  final current = _Version.parse(pubspecVersion);
  _Version? newest;
  for (final match in _releaseHeading.allMatches(changelog)) {
    final version = _Version.parse(match.group(1)!);
    final order = version.compareTo(current);
    final eligible = releaseLine ? order < 0 : order <= 0;
    if (eligible && (newest == null || version.compareTo(newest) > 0)) newest = version;
  }
  if (newest == null) {
    throw FormatException('CHANGELOG.md has no released version ${releaseLine ? 'below' : 'up to'} $pubspecVersion');
  }
  return newest.text;
}

/// The text under the `# <version>` heading up to the next top-level heading, or `null` without one.
String? changelogSection(String changelog, String version) {
  final lines = changelog.split('\n');
  final start = lines.indexOf('# $version');
  if (start < 0) return null;
  final section = <String>[];
  for (final line in lines.skip(start + 1)) {
    if (line.startsWith('# ')) break;
    section.add(line);
  }
  return section.join('\n');
}

/// The `dart_apitool extract` output with everything that depends on where and from which version the tool
/// ran removed — the format `version`, the package's `packagePath` and `packageVersion` and every
/// declaration's `relativePath` — and with keys sorted. Lists keep their order.
String normalizeApiSnapshot(String apitoolJson) {
  final json = Map<String, Object?>.of(jsonDecode(apitoolJson) as Map<String, Object?>)..remove('version');
  final packageApi = json['packageApi'];
  if (packageApi is Map<String, Object?>) {
    json['packageApi'] = Map<String, Object?>.of(packageApi)
      ..remove('packagePath')
      ..remove('packageVersion');
  }
  return '${const JsonEncoder.withIndent('  ').convert(_sorted(json))}\n';
}

Object? _sorted(Object? value) {
  if (value is Map<String, Object?>) {
    final keys = value.keys.where((key) => key != 'relativePath').toList()..sort();
    return {for (final key in keys) key: _sorted(value[key])};
  }
  if (value is List<Object?>) return [for (final item in value) _sorted(item)];
  return value;
}

final class _Version implements Comparable<_Version> {
  _Version._(this.text, this.major, this.minor, this.patch, this.preRelease);

  factory _Version.parse(String text) {
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?$').firstMatch(text);
    if (match == null) throw FormatException('not a version: $text');
    return _Version._(
      text,
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      match.group(4),
    );
  }

  final String text;
  final int major;
  final int minor;
  final int patch;
  final String? preRelease;

  /// Version order where a pre-release comes before its release. Only released versions are compared
  /// with each other or with a pre-release, so pre-releases are not ordered among themselves.
  @override
  int compareTo(_Version other) {
    for (final (a, b) in [(major, other.major), (minor, other.minor), (patch, other.patch)]) {
      if (a != b) return a.compareTo(b);
    }
    final pre = preRelease;
    final otherPre = other.preRelease;
    if (pre == otherPre) return 0;
    if (pre == null) return 1;
    if (otherPre == null) return -1;
    return pre.compareTo(otherPre);
  }
}

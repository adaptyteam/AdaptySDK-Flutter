/// The summary of one run of the native probe on a platform: what the run script recorded and what the probe
/// printed, with the class of the failure, if any.
library;

import 'dart:convert';

/// One step of a run as the run script records it: `<name>\t<infra|probe>\t<exit code>\t<attempts>\t<seconds>`.
final class L2aStep {
  const L2aStep(this.name, this.kind, this.exitCode, this.attempts, this.seconds);

  final String name;

  /// `infra` for what prepares the run (a device, a download, a build), `probe` for what checks the plugin.
  final String kind;
  final int exitCode;
  final int attempts;
  final int seconds;

  bool get passed => exitCode == 0;
}

/// One run of `tool/l2a/ci/<platform>.sh`, read from its output directory.
final class L2aRun {
  L2aRun._(
    this.steps,
    this.info,
    this.retried,
    this.probed,
    this.summary,
    this.outcomes,
    this.mismatches,
    this.views,
    this.logs,
  );

  /// [steps] and [info] are the tab-separated files the run script writes; [logs] holds the output of each test
  /// step by its name; [probed] is `probed` of the expectations (the iOS runtime and the Xcode among it).
  factory L2aRun.parse({
    required String steps,
    required String info,
    required Map<String, String> logs,
    Map<String, String> probed = const {},
  }) {
    final parsedSteps = [
      for (final line in const LineSplitter().convert(steps))
        if (line.split('\t') case [final name, final kind, final rc, final attempts, final seconds])
          L2aStep(name, kind, int.tryParse(rc) ?? -1, int.tryParse(attempts) ?? 0, int.tryParse(seconds) ?? 0),
    ];
    final infoLines = [
      for (final line in const LineSplitter().convert(info))
        if (line.split('\t') case [final key, final value]) (key, value),
    ];
    final parsedInfo = {for (final (key, value) in infoLines) key: value};
    final probeLog = _lastRun(logs['probe'] ?? '');
    final outcomes = _jsonLines(probeLog, 'L2A_OUTCOME').length;
    final mismatches = [
      for (final tag in const ['L2A_OUTCOME', 'L2A_AFTER'])
        for (final outcome in _jsonLines(probeLog, tag))
          if (outcome['matches'] == false) outcome,
    ];
    final views = [for (final log in logs.values) ..._jsonLines(log, 'L2A_VIEW')];
    return L2aRun._(
      parsedSteps,
      parsedInfo,
      [
        for (final (key, value) in infoLines)
          if (key == 'retried') value,
      ],
      probed,
      _jsonLines(probeLog, 'L2A_SUMMARY').lastOrNull,
      outcomes,
      mismatches,
      views,
      logs,
    );
  }

  /// Every step the run recorded, in order; a test that ran again records its steps twice.
  final List<L2aStep> steps;
  final Map<String, String> info;

  /// The tests that ran once more because they did not start on the device, each with what flutter or adb said
  /// (`retried` lines of [info]).
  final List<String> retried;

  /// The last record of each step: a step that ran again counts by its last run.
  List<L2aStep> get _lastSteps => [
    ...{for (final s in steps) s.name: s}.values,
  ];

  /// What the expectations were recorded on: `ios_sha`, `ios_runtime`, `xcode`.
  final Map<String, String> probed;

  /// The `L2A_SUMMARY` the probe printed; null when it printed none.
  final Map<String, Object?>? summary;

  /// How many `L2A_OUTCOME` lines of the probe could be read: one for each case it called, unless the log lost or cut
  /// some of them.
  final int outcomes;

  /// The outcomes the plugin answered other than expected.
  final List<Map<String, Object?>> mismatches;

  /// The embedded views the views tests created.
  final List<Map<String, Object?>> views;

  /// The output of each step of the probe class by its name.
  final Map<String, String> logs;

  /// The steps the run script of the platform in [info] always records once it gets to the tests: each test, and on
  /// Android its egress guard result and its native log, on iOS the native log of each test. Null when [info] names
  /// no platform the scripts know.
  static List<String>? requiredSteps(Map<String, String> info) {
    switch (info['platform']) {
      case 'ios':
        return const ['probe', 'views', 'probe-native-log', 'views-native-log'];
      case 'android':
        final tests = (info['variant'] ?? '').startsWith('flutter-activity')
            ? const ['probe', 'flutter_activity']
            : const ['probe', 'views'];
        return [
          for (final test in tests) ...[test, '$test-egress', '$test-native-log'],
        ];
      default:
        return null;
    }
  }

  /// `infra` when the run did not get to the plugin (a device, a download or a build failed, or the run stopped
  /// before the probe) or lost a step its script always records ([requiredSteps]), `probe` when the plugin answered
  /// other than expected or the outcomes of the probe that could be read are not one for each case it called; null
  /// when the run is green. [failure] says why. A step that ran again counts by its last run.
  String? get failureClass => failure?.kind;

  /// The class of the failure of the run, as [failureClass], with what made the run red; null when the run is green.
  ({String kind, String reason})? get failure {
    final failed = [
      for (final s in _lastSteps)
        if (!s.passed) s,
    ];
    final failedInfra = [
      for (final s in failed)
        if (s.kind != 'probe') s.name,
    ];
    if (failedInfra.isNotEmpty) return (kind: 'infra', reason: 'failed steps: ${failedInfra.join(', ')}');
    if (failed.isNotEmpty) return (kind: 'probe', reason: 'failed steps: ${failed.map((s) => s.name).join(', ')}');
    if (!steps.any((s) => s.name == 'probe')) return (kind: 'infra', reason: 'the run stopped before the probe');
    final required = requiredSteps(info);
    if (required == null) {
      return (kind: 'infra', reason: 'the run names no platform the scripts know (${info['platform'] ?? 'none'})');
    }
    final recorded = {for (final s in steps) s.name};
    final missing = [
      for (final name in required)
        if (!recorded.contains(name)) name,
    ];
    if (missing.isNotEmpty) return (kind: 'infra', reason: 'missing steps: ${missing.join(', ')}');
    final summary = this.summary;
    if (summary == null) return (kind: 'probe', reason: 'the probe printed no `L2A_SUMMARY`');
    if (mismatches.isNotEmpty) return (kind: 'probe', reason: 'answers other than expected: ${mismatches.length}');
    if (summary['called'] != outcomes) {
      return (kind: 'probe', reason: 'outcomes read: $outcomes of ${summary['called']} called');
    }
    return null;
  }

  /// What a reader should know although the run is green: a warning a tool of the run printed (a native log check that
  /// saw only part of the log), an iOS SDK other than the one the expectations were
  /// recorded on (`native-moved`) or one whose revision the run could not tell, and an iOS runtime or Xcode other
  /// than the ones of the expectations (`runtime-moved`). A probe that fails after such a move is triaged as a
  /// discrepancy, not answered by recording the expectations anew.
  List<String> get warnings => [..._toolWarnings, ..._iosWarnings];

  /// The warnings the tools of the run printed (`L2A_WARNING …` lines), such as a native log check that saw only part
  /// of the log.
  List<String> get _toolWarnings => [
    for (final log in logs.values)
      for (final line in const LineSplitter().convert(log))
        if (line.startsWith('L2A_WARNING ')) line.substring('L2A_WARNING '.length),
  ];

  List<String> get _iosWarnings {
    final summary = this.summary;
    if (summary == null || summary['platform'] != 'ios') return const [];
    final probedSha = '${summary['probed_ios_sha'] ?? ''}';
    final resolved = '${summary['resolved_ios_sha'] ?? ''}';
    final runtime = info['ios_runtime'], xcode = info['xcode_version'];
    final probedRuntime = probed['ios_runtime'], probedXcode = probed['xcode'];
    return [
      if (resolved.isEmpty)
        'the resolved revision of the iOS SDK is unknown'
      else if (resolved != probedSha)
        'native-moved: the app resolved the iOS SDK at $resolved, the expectations were recorded on $probedSha',
      if ((runtime != null && probedRuntime != null && runtime != probedRuntime) ||
          (xcode != null && probedXcode != null && xcode != probedXcode))
        'runtime-moved: the run used iOS $runtime and Xcode $xcode, the expectations were recorded on iOS '
            '$probedRuntime and Xcode $probedXcode',
    ];
  }

  /// The summary as Markdown, for the job summary and the terminal.
  String toMarkdown() {
    final failure = this.failure;
    final variant = info['variant'];
    final out = StringBuffer()
      ..writeln(
        '### Native probe on ${info['platform'] ?? summary?['platform']}${variant == null ? '' : ' ($variant)'}',
      )
      ..writeln()
      ..writeln(failure == null ? 'Result: **green**' : 'Result: **red** (failure class: `${failure.kind}`)')
      ..writeln();
    if (failure != null) {
      out
        ..writeln('Reason: ${failure.reason}')
        ..writeln();
    }
    for (final warning in warnings) {
      out
        ..writeln('> **Warning** $warning')
        ..writeln();
    }
    for (final key in const ['mode', 'commit', 'device', 'xcode']) {
      if (info[key] case final value?) out.writeln('- $key: $value');
    }
    for (final test in retried) {
      out.writeln('- retried: $test');
    }
    out
      ..writeln()
      ..writeln('| step | class | exit code | attempts | seconds |')
      ..writeln('|---|---|---|---|---|');
    for (final s in steps) {
      out.writeln('| ${s.name} | ${s.kind} | ${s.exitCode} | ${s.attempts} | ${s.seconds} |');
    }
    out.writeln();
    _writeSummary(out);
    if (views.isNotEmpty) {
      out
        ..writeln()
        ..writeln('Embedded views created: ${views.where((v) => v['created'] != null).length} of ${views.length}');
    }
    if (mismatches.isNotEmpty) {
      out
        ..writeln()
        ..writeln('Answers other than expected (${mismatches.length}):');
      for (final m in mismatches.take(50)) {
        out.writeln('- `${m['id']}`: expected `${jsonEncode(m['expected'])}`, got `${jsonEncode(m['observed'])}`');
      }
    }
    return out.toString();
  }

  /// The counters of the probe, the cases by the basis of their expectation, the denied cases and what the probe
  /// does not cover.
  void _writeSummary(StringBuffer out) {
    final summary = this.summary;
    if (summary == null) {
      out.writeln('The probe printed no `L2A_SUMMARY`.');
      return;
    }
    final unobservable = _shareOfCalled(summary['unobservable'], summary['called']);
    out
      ..writeln('- cases: ${summary['cases']}, called: ${summary['called']}')
      ..writeln('- answers: ${_counts(summary['observed'])}')
      ..writeln('- unexpected: ${summary['unexpected']}, unobservable: $unobservable')
      ..writeln(
        '- required fields a plugin takes without them, by method and path: ${summary['required_fields_taken']} '
        '(cases: ${summary['required_fields_taken_cases']})',
      );
    if (summary['probed_ios_sha'] case final String probed when probed.isNotEmpty && summary['platform'] == 'ios') {
      out.writeln('- iOS SDK: resolved ${summary['resolved_ios_sha'] ?? 'unknown'}, expectations recorded on $probed');
    }
    out
      ..writeln()
      ..writeln('| basis of the expectation | cases |')
      ..writeln('|---|---|');
    if (summary['by_basis'] case final Map<String, Object?> byBasis) {
      for (final MapEntry(:key, :value) in byBasis.entries) {
        out.writeln('| $key | $value |');
      }
    }
    out
      ..writeln()
      ..writeln('Denied (not called): ${_list(summary['denied'])}')
      ..writeln()
      ..writeln('Not covered: ${_list(summary['not_covered'])}');
  }

  static String _counts(Object? counts) =>
      counts is Map ? [for (final MapEntry(:key, :value) in counts.entries) '$key $value'].join(', ') : '$counts';

  /// [count] out of the [called] cases, with its share in whole percent rounded down; without the share when no case
  /// was called, and [count] alone when the number of called cases is not known.
  static String _shareOfCalled(Object? count, Object? called) => switch ((count, called)) {
    (final int count, final int called) when called > 0 => '$count of $called called (${count * 100 ~/ called} %)',
    (_, final int called) => '$count of $called called',
    _ => '$count',
  };

  static String _list(Object? items) => items is List && items.isNotEmpty ? items.join(', ') : 'none';

  /// How the run script starts the output of a step in its log, each time it runs the step.
  static const runHeader = '# command (repository ';

  /// The output of the last run of a step in [log]: a run into the directory of an earlier one appends to its logs.
  static String _lastRun(String log) {
    final start = log.lastIndexOf('\n$runHeader');
    return start < 0 ? log : log.substring(start + 1);
  }

  /// The JSON objects of the lines of [log] that carry [tag] followed by a space and an object.
  static List<Map<String, Object?>> _jsonLines(String log, String tag) => [
    for (final line in const LineSplitter().convert(log))
      if (line.indexOf('$tag {') case final start when start >= 0)
        if (_decode(line.substring(start + tag.length + 1)) case final Map<String, Object?> object) object,
  ];

  static Object? _decode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}

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
  L2aRun._(this.steps, this.info, this.summary, this.mismatches, this.views);

  /// [steps] and [info] are the tab-separated files the run script writes; [logs] holds the output of each test
  /// step by its name.
  factory L2aRun.parse({required String steps, required String info, required Map<String, String> logs}) {
    final parsedSteps = [
      for (final line in const LineSplitter().convert(steps))
        if (line.split('\t') case [final name, final kind, final rc, final attempts, final seconds])
          L2aStep(name, kind, int.tryParse(rc) ?? -1, int.tryParse(attempts) ?? 0, int.tryParse(seconds) ?? 0),
    ];
    final parsedInfo = {
      for (final line in const LineSplitter().convert(info))
        if (line.split('\t') case [final key, final value]) key: value,
    };
    final probeLog = logs['probe'] ?? '';
    final mismatches = [
      for (final tag in const ['L2A_OUTCOME', 'L2A_AFTER'])
        for (final outcome in _jsonLines(probeLog, tag))
          if (outcome['matches'] == false) outcome,
    ];
    final views = [for (final log in logs.values) ..._jsonLines(log, 'L2A_VIEW')];
    return L2aRun._(parsedSteps, parsedInfo, _jsonLines(probeLog, 'L2A_SUMMARY').lastOrNull, mismatches, views);
  }

  final List<L2aStep> steps;
  final Map<String, String> info;

  /// The `L2A_SUMMARY` the probe printed; null when it printed none.
  final Map<String, Object?>? summary;

  /// The outcomes the plugin answered other than expected.
  final List<Map<String, Object?>> mismatches;

  /// The embedded views the views tests created.
  final List<Map<String, Object?>> views;

  /// `infra` when the run did not get to the plugin (a device, a download or a build failed, or the run stopped
  /// before the probe), `probe` when the plugin answered other than expected; null when the run is green.
  String? get failureClass {
    if (steps.any((s) => s.kind != 'probe' && !s.passed)) return 'infra';
    if (steps.any((s) => !s.passed)) return 'probe';
    if (!steps.any((s) => s.name == 'probe')) return 'infra';
    if (summary == null || mismatches.isNotEmpty) return 'probe';
    return null;
  }

  /// What a reader should know although the run is green: an iOS SDK other than the one the expectations were
  /// recorded on (`native-moved`), or one whose revision the run could not tell.
  List<String> get warnings {
    final summary = this.summary;
    if (summary == null || summary['platform'] != 'ios') return const [];
    final probed = '${summary['probed_ios_sha'] ?? ''}';
    final resolved = '${summary['resolved_ios_sha'] ?? ''}';
    if (resolved.isEmpty) return const ['the resolved revision of the iOS SDK is unknown'];
    if (resolved != probed) {
      return ['native-moved: the app resolved the iOS SDK at $resolved, the expectations were recorded on $probed'];
    }
    return const [];
  }

  /// The summary as Markdown, for the job summary and the terminal.
  String toMarkdown() {
    final failure = failureClass;
    final variant = info['variant'];
    final out = StringBuffer()
      ..writeln(
        '### Native probe on ${info['platform'] ?? summary?['platform']}${variant == null ? '' : ' ($variant)'}',
      )
      ..writeln()
      ..writeln(failure == null ? 'Result: **green**' : 'Result: **red** (failure class: `$failure`)')
      ..writeln();
    for (final warning in warnings) {
      out
        ..writeln('> **Warning** $warning')
        ..writeln();
    }
    for (final key in const ['mode', 'commit', 'device', 'xcode']) {
      if (info[key] case final value?) out.writeln('- $key: $value');
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
    out
      ..writeln('- cases: ${summary['cases']}, called: ${summary['called']}')
      ..writeln('- answers: ${_counts(summary['observed'])}')
      ..writeln('- unexpected: ${summary['unexpected']}, unobservable: ${summary['unobservable']}')
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

  static String _list(Object? items) => items is List && items.isNotEmpty ? items.join(', ') : 'none';

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

import 'dart:io';

import 'src/native_log.dart';

// Usage, from the repository root:
//   dart run tool/l2a/native_log_check.dart <ios|android> <log file> [--onboarding-views <n>] [--flow-views <n>]
//     [--plugin-refusals <n>]
//
// Prints the lines of a native log of the probe that show a defect: on iOS a view whose creation params the
// wrapper could not read, an event it could not encode or a second registration of the plugin, on Android a
// platform view that failed to be created, a crash and arguments the SDK could not parse. The errors every call
// logs before activation are not defects. With --onboarding-views (iOS) the log must also say for exactly <n>
// onboarding views that they met an inactive SDK, which shows that their creation params decoded; with --flow-views
// (Android, the log level of the SDK at verbose) exactly <n> flow views must have asked for their configuration,
// which shows the same; with --plugin-refusals (iOS) <n> is the number of requests the plugin is expected to refuse
// as bad params: at least half of them, rounded up, must be in the log, which shows that the lines of the SDK are
// there, and fewer than all of them is a warning (an L2A_WARNING line: the defect check is incomplete, with the loss
// events of the window), as the unified log of iOS loses lines under load. A lost
// log fails too: on iOS one that log show did not write, on Android one without a line
// of the app process.
//
// Exit codes: 0 — no defect; 1 — a defect, a wrong count, a lost log, or the arguments or the file could not be
// read.
void main(List<String> arguments) {
  final args = nativeLogCheckArgs(arguments);
  if (args == null) {
    stderr.writeln(
      'usage: dart run tool/l2a/native_log_check.dart <ios|android> <log file> [--onboarding-views <n>] '
      '[--flow-views <n>] [--plugin-refusals <n>]',
    );
    exit(1);
  }
  final String log;
  try {
    log = File(args.path).readAsStringSync();
  } on FileSystemException catch (e) {
    stderr.writeln('${e.path}: ${e.message}');
    exit(1);
  }
  final problems = nativeLogProblems(
    log,
    args.platform,
    onboardingViews: args.onboardingViews,
    flowViews: args.flowViews,
    pluginRefusals: args.pluginRefusals,
  );
  for (final warning in nativeLogWarnings(log, args.platform, pluginRefusals: args.pluginRefusals)) {
    stdout.writeln('L2A_WARNING $warning');
  }
  if (problems.isEmpty) {
    stdout.writeln('no defect in the native log');
    return;
  }
  problems.forEach(stdout.writeln);
  exit(1);
}

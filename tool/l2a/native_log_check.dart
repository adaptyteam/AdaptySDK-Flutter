import 'dart:io';

import '../contract/src/contract_schema.dart' show ContractPlatform;
import 'src/native_log.dart';

// Usage, from the repository root:
//   dart run tool/l2a/native_log_check.dart <ios|android> <log file> [--onboarding-views <n>] [--flow-views <n>]
//
// Prints the lines of a native log of the probe that show a defect: on iOS a view whose creation params the
// wrapper could not read, an event it could not encode or a second registration of the plugin, on Android a
// platform view that failed to be created, a crash and arguments the SDK could not parse. The errors every call
// logs before activation are not defects. With --onboarding-views (iOS) the log must also say for exactly <n>
// onboarding views that they met an inactive SDK, which shows that their creation params decoded; with --flow-views
// (Android, the log level of the SDK at verbose) exactly <n> flow views must have asked for their configuration,
// which shows the same. A lost log fails too: on iOS one that log show did not write, on Android one without a line
// of the app process.
//
// Exit codes: 0 — no defect; 1 — a defect, a wrong count, a lost log, or the arguments or the file could not be
// read.
void main(List<String> args) {
  int? onboardingViews, flowViews;
  var valid = args.length >= 2 && args.length.isEven && const {'ios', 'android'}.contains(args[0]);
  for (var i = 2; valid && i < args.length; i += 2) {
    final count = int.tryParse(args[i + 1]);
    switch (args[i]) {
      case '--onboarding-views' when count != null:
        onboardingViews = count;
      case '--flow-views' when count != null:
        flowViews = count;
      default:
        valid = false;
    }
  }
  if (!valid) {
    stderr.writeln(
      'usage: dart run tool/l2a/native_log_check.dart <ios|android> <log file> [--onboarding-views <n>] '
      '[--flow-views <n>]',
    );
    exit(1);
  }
  final String log;
  try {
    log = File(args[1]).readAsStringSync();
  } on FileSystemException catch (e) {
    stderr.writeln('${e.path}: ${e.message}');
    exit(1);
  }
  final problems = nativeLogProblems(
    log,
    ContractPlatform.parse(args[0]),
    onboardingViews: onboardingViews,
    flowViews: flowViews,
  );
  if (problems.isEmpty) {
    stdout.writeln('no defect in the native log');
    return;
  }
  problems.forEach(stdout.writeln);
  exit(1);
}

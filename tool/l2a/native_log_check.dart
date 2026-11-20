import 'dart:io';

import '../contract/src/contract_schema.dart' show ContractPlatform;
import 'src/native_log.dart';

// Usage, from the repository root:
//   dart run tool/l2a/native_log_check.dart <ios|android> <log file> [--onboarding-views <n>]
//
// Prints the lines of a native log of the probe that show a defect: on iOS a view whose creation params the
// wrapper could not read, an event it could not encode or a second registration of the plugin, on Android a
// platform view that failed to be created and a crash. The errors every call logs before activation are not
// defects. With --onboarding-views (iOS) the log must also say for exactly <n> onboarding views that they met an
// inactive SDK, which shows that their creation params decoded. A lost log fails too: on iOS one that log show did
// not write, on Android one without a line of the app process.
//
// Exit codes: 0 — no defect; 1 — a defect, a wrong count, a lost log, or the arguments or the file could not be
// read.
void main(List<String> args) {
  final onboardingViews = args.length == 4 && args[2] == '--onboarding-views' ? int.tryParse(args[3]) : null;
  if ((args.length != 2 && onboardingViews == null) || !const {'ios', 'android'}.contains(args[0])) {
    stderr.writeln('usage: dart run tool/l2a/native_log_check.dart <ios|android> <log file> [--onboarding-views <n>]');
    exit(1);
  }
  final String log;
  try {
    log = File(args[1]).readAsStringSync();
  } on FileSystemException catch (e) {
    stderr.writeln('${e.path}: ${e.message}');
    exit(1);
  }
  final problems = nativeLogProblems(log, ContractPlatform.parse(args[0]), onboardingViews: onboardingViews);
  if (problems.isEmpty) {
    stdout.writeln('no defect in the native log');
    return;
  }
  problems.forEach(stdout.writeln);
  exit(1);
}

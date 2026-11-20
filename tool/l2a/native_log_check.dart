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
// inactive SDK, which shows that their creation params decoded.
//
// Exit codes: 0 — no defect; 1 — a defect, a wrong count, or the arguments or the file could not be read.
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
  final defects = defectLines(log, ContractPlatform.parse(args[0]));
  final onboardings = onboardingNotActivatedLines(log);
  final wrongCount = onboardingViews != null && onboardings != onboardingViews;
  if (wrongCount) {
    stdout.writeln('$onboardings onboarding views met an inactive SDK, $onboardingViews expected');
  }
  if (defects.isEmpty) {
    stdout.writeln('no defect in the native log');
    if (wrongCount) exit(1);
    return;
  }
  stdout.writeln('${defects.length} defect lines in the native log:');
  defects.forEach(stdout.writeln);
  exit(1);
}

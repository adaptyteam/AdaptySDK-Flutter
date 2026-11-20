import 'dart:io';

import '../contract/src/contract_schema.dart' show ContractPlatform;
import 'src/native_log.dart';

// Usage, from the repository root: dart run tool/l2a/native_log_check.dart <ios|android> <log file>
//
// Prints the lines of a native log of the probe that show a defect: on iOS a view whose creation params the
// wrapper could not read, on Android a platform view that failed to be created and a crash. The errors every
// call logs before activation are not defects.
//
// Exit codes: 0 — no defect; 1 — a defect, or the arguments or the file could not be read.
void main(List<String> args) {
  if (args.length != 2 || !const {'ios', 'android'}.contains(args[0])) {
    stderr.writeln('usage: dart run tool/l2a/native_log_check.dart <ios|android> <log file>');
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
  if (defects.isEmpty) {
    stdout.writeln('no defect in the native log');
    return;
  }
  stdout.writeln('${defects.length} defect lines in the native log:');
  defects.forEach(stdout.writeln);
  exit(1);
}

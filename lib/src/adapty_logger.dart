import 'models/adapty_log_level.dart';
import 'runtime/adapty_log_sink.dart';
import 'runtime/adapty_runtime.dart';

class AdaptyLogger {
  static AdaptyLogLevel logLevel = AdaptyLogLevel.info;

  static void write(AdaptyLogLevel level, String message) =>
      writeAdaptyLogTo(AdaptyRuntime.current.diagnostics.logSink, level, message);

  static String get stamp => AdaptyRuntime.current.diagnostics.logSink.nextStamp();
}

/// Writes [message] to [sink] unless [level] is below [AdaptyLogger.logLevel].
void writeAdaptyLogTo(AdaptyLogSink sink, AdaptyLogLevel level, String message) {
  if (level.index > AdaptyLogger.logLevel.index) return;
  sink.write(AdaptyLogRecord(level, message));
}

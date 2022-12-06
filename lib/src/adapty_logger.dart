import 'adapty.dart';
import 'models/adapty_log_level.dart';

class AdaptyLogger {
  static AdaptyLogLevel logLevel = AdaptyLogLevel.info;

  static void write(AdaptyLogLevel level, String message) {
    if (AdaptyLogLevel.values.indexOf(level) < AdaptyLogLevel.values.indexOf(logLevel)) return;

    print("[AdaptyFlutter v${Adapty.sdkVersion}] - ${level.jsonValue.toString().toUpperCase()}: $message");
  }
}

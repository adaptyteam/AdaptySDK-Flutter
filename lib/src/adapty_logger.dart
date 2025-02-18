import 'adapty.dart';
import 'models/adapty_log_level.dart';
import 'dart:io' show Platform;
import 'dart:math' show Random;

class AdaptyLogger {
  static AdaptyLogLevel logLevel = AdaptyLogLevel.info;

  static void write(AdaptyLogLevel level, String message) {
    if (AdaptyLogLevel.values.indexOf(level) > AdaptyLogLevel.values.indexOf(logLevel)) return;
    print("[AdaptyFlutter ${Platform.isAndroid ? 'a' : 'i'}${Adapty.sdkVersion}] - ${level.jsonValue.toString().toUpperCase()}: $message");
  }

  static final _random = Random();
  static const _stampChars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

  static String get stamp {
    var result = '';
    final random = _random.nextInt(0x7FFFFFFF);
    for (var i = 0; i < 4; i++) {
      final index = (random >> (i * 8)) & 0x3F;
      result += _stampChars[index];
    }
    return result;
  }
}

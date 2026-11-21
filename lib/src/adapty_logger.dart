import 'adapty_version.dart';
import 'models/adapty_log_level.dart';
import 'dart:io' show Platform;
import 'dart:math' show Random;

class AdaptyLogger {
  static AdaptyLogLevel logLevel = AdaptyLogLevel.info;

  static void write(AdaptyLogLevel level, String message) {
    if (level.index > logLevel.index) return;
    print("[AdaptyFlutter ${Platform.isAndroid ? 'a' : 'i'}$adaptySDKVersion] - ${level.jsonValue.toString().toUpperCase()}: $message");
  }

  static String get stamp => randomStamp(4);
}

final _random = Random();
const _stampChars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

/// [length] random characters from `0-9A-Za-z`.
String randomStamp(int length) {
  var result = '';
  for (var i = 0; i < length; i++) {
    result += _stampChars[_random.nextInt(_stampChars.length)];
  }
  return result;
}

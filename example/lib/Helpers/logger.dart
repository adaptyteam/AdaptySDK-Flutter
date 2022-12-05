import 'package:adapty_flutter/adapty_flutter.dart';

class Logger {
  static logExampleMessage(String message) {
    print('[Example v${Adapty.sdkVersion}] $message');
  }
}

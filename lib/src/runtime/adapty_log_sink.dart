import 'dart:math' show Random;

import '../adapty_version.dart';
import '../models/adapty_log_level.dart';
import 'adapty_platform_info.dart';

/// One line of the SDK log, already past the log level.
final class AdaptyLogRecord {
  const AdaptyLogRecord(this.level, this.message);

  final AdaptyLogLevel level;
  final String message;
}

/// Where a runtime writes its log lines and takes the stamps that pair a native call with its result.
abstract interface class AdaptyLogSink {
  void write(AdaptyLogRecord record);

  /// A new stamp for the lines of one native call.
  String nextStamp();
}

/// Prints every line with the prefix of [platform]; a stamp is four random characters from 0-9A-Za-z.
///
/// Nothing here may log: the logger reaches this sink through the current runtime, which may be the production
/// runtime being created.
final class PrintLogSink implements AdaptyLogSink {
  PrintLogSink(this.platform);

  final AdaptyPlatformInfo platform;

  @override
  void write(AdaptyLogRecord record) {
    final level = record.level.jsonValue.toString().toUpperCase();
    print('[AdaptyFlutter ${platform.logTag}$adaptySDKVersion] - $level: ${record.message}');
  }

  @override
  String nextStamp() => randomStamp(4);
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

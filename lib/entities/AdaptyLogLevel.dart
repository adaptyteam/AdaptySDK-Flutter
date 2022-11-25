//
//  AdaptyLogLevel.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

enum AdaptyLogLevel {
  error,
  warn,
  info,
  verbose,
  debug,
}

extension AdaptyLogLevelExtension on AdaptyLogLevel {
  static const _error = 'error';
  static const _warn = 'warn';
  static const _info = 'info';
  static const _verbose = "verbose";
  static const _debug = "debug";

  String stringValue() {
    switch (this) {
      case AdaptyLogLevel.error:
        return _error;
      case AdaptyLogLevel.warn:
        return _warn;
      case AdaptyLogLevel.info:
        return _info;
      case AdaptyLogLevel.verbose:
        return _verbose;
      case AdaptyLogLevel.debug:
        return _debug;
    }
  }

  static AdaptyLogLevel fromStringValue(String value) {
    switch (value) {
      case _error:
        return AdaptyLogLevel.error;
      case _warn:
        return AdaptyLogLevel.warn;
      case _info:
        return AdaptyLogLevel.info;
      case _verbose:
        return AdaptyLogLevel.verbose;
      case _debug:
        return AdaptyLogLevel.debug;
      default:
        throw FormatException("Unknown AdaptyLogLevel value == $value");
    }
  }
}

extension MapExtension on Map<String, dynamic> {
  AdaptyLogLevel logLevel(String key) {
    return AdaptyLogLevelExtension.fromStringValue(this[key] as String);
  }

  AdaptyLogLevel? logLevelIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyLogLevelExtension.fromStringValue(value);
  }
}

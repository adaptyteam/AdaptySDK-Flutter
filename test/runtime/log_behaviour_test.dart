/// What the SDK log looks like to the app: the line printed for each level, the level below which nothing is printed
/// and the stamp that pairs a native call with its result.
///
/// The lines are printed by the production runtime on a host that is not Android, so the prefix letter is `i`.
/// `AdaptyLogger.logLevel` is static and outlives a test, so every test restores it.
import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/adapty_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AdaptyLogLevel savedLogLevel;

  setUp(() => savedLogLevel = AdaptyLogger.logLevel);
  tearDown(() => AdaptyLogger.logLevel = savedLogLevel);

  test('a warn line carries the prefix, the version, the level and the message', () {
    AdaptyLogger.logLevel = AdaptyLogLevel.info;

    final lines = _printed(() => AdaptyLogger.write(AdaptyLogLevel.warn, 'x'));

    expect(lines, ['[AdaptyFlutter i$adaptySDKVersion] - WARN: x']);
  });

  test('every level is printed under its name in upper case', () {
    AdaptyLogger.logLevel = AdaptyLogLevel.debug;

    final lines = _printed(() {
      AdaptyLogger.write(AdaptyLogLevel.error, 'e');
      AdaptyLogger.write(AdaptyLogLevel.warn, 'w');
      AdaptyLogger.write(AdaptyLogLevel.info, 'i');
      AdaptyLogger.write(AdaptyLogLevel.verbose, 'v');
      AdaptyLogger.write(AdaptyLogLevel.debug, 'd');
    });

    expect(lines, [
      '[AdaptyFlutter i$adaptySDKVersion] - ERROR: e',
      '[AdaptyFlutter i$adaptySDKVersion] - WARN: w',
      '[AdaptyFlutter i$adaptySDKVersion] - INFO: i',
      '[AdaptyFlutter i$adaptySDKVersion] - VERBOSE: v',
      '[AdaptyFlutter i$adaptySDKVersion] - DEBUG: d',
    ]);
  });

  test('a verbose line is not printed at the info level', () {
    AdaptyLogger.logLevel = AdaptyLogLevel.info;

    final lines = _printed(() {
      AdaptyLogger.write(AdaptyLogLevel.info, 'at the level');
      AdaptyLogger.write(AdaptyLogLevel.verbose, 'below the level');
    });

    expect(lines, ['[AdaptyFlutter i$adaptySDKVersion] - INFO: at the level']);
  });

  test('a stamp is four characters from 0-9A-Za-z', () {
    final stamps = [for (var i = 0; i < 1000; i++) AdaptyLogger.stamp];

    expect(stamps, everyElement(matches(RegExp(r'^[0-9A-Za-z]{4}$'))));
    // 4000 random draws leave out one of the 62 characters with a chance below 1e-26.
    expect(stamps.join().split('').toSet(), hasLength(62));
  });
}

/// Every line [body] prints.
List<String> _printed(void Function() body) {
  final lines = <String>[];
  runZoned(body, zoneSpecification: ZoneSpecification(print: (_, _, _, line) => lines.add(line)));
  return lines;
}

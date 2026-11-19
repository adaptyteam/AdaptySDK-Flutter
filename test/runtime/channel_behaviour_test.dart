/// How a call to the native side reads in errors and logs: the method appears under the name it
/// has on the channel.
import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('a null reply fails with emptyResult', () async {
    final savedLogLevel = AdaptyLogger.logLevel;
    addTearDown(() => AdaptyLogger.logLevel = savedLogLevel);
    AdaptyLogger.logLevel = AdaptyLogLevel.verbose;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => null,
    );

    final logs = <String>[];
    Object? error;
    await runZoned(() async {
      try {
        await Adapty().isActivated();
      } catch (e) {
        error = e;
      }
    }, zoneSpecification: ZoneSpecification(print: (_, _, _, line) => logs.add(line)));

    expect(
      error,
      isA<AdaptyError>()
          .having((e) => e.code, 'code', AdaptyErrorCode.emptyResult)
          .having((e) => e.message, 'message', 'Adapty.is_activated() returned null'),
    );
    expect(logs, contains(contains('--> Adapty.is_activated()')));
    expect(logs, contains(contains('<-- Adapty.is_activated()')));
  });
}

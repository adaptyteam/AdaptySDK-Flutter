/// The verbose log of `activate` never shows the API key, while the native side still gets it.
///
/// `AdaptyLogger.logLevel` is static and outlives a test, so `setUp` saves it and `tearDown` restores it: these tests
/// pass in any order.
import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late AdaptyLogLevel savedLogLevel;

  setUp(() {
    calls = <MethodCall>[];
    savedLogLevel = AdaptyLogger.logLevel;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return jsonEncode({'success': true});
    });
  });

  tearDown(() {
    AdaptyLogger.logLevel = savedLogLevel;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    // activate installs the incoming method call handler on a channel shared by the whole isolate.
    _channel.setMethodCallHandler(null);
  });

  /// Activates with [apiKey] and verbose logs, and returns what the SDK printed.
  Future<List<String>> activate(String apiKey) async {
    final logs = <String>[];
    await runZoned(
      () => Adapty().activate(
        configuration: AdaptyConfiguration(apiKey: apiKey)..withLogLevel(AdaptyLogLevel.verbose),
      ),
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => logs.add(line)),
    );
    return logs;
  }

  String activateLine(List<String> logs) => logs.singleWhere((line) => line.contains('--> Adapty.activate()'));

  test('a key with a dot is not printed', () async {
    const apiKey = 'test_key_prefix.secret_part';

    final logs = await activate(apiKey);

    expect(logs.where((line) => line.contains('test_key_prefix') || line.contains('secret_part')), isEmpty);
    expect(activateLine(logs), contains('"api_key":"<redacted>"'));
    expect(activateLine(logs), contains('"log_level":"verbose"'));
  });

  test('a key without a dot is not printed', () async {
    const apiKey = 'test_key_without_dot';

    final logs = await activate(apiKey);

    expect(logs.where((line) => line.contains(apiKey)), isEmpty);
    expect(activateLine(logs), contains('"api_key":"<redacted>"'));
  });

  test('the native side gets the full key', () async {
    const apiKey = 'test_key_prefix.secret_part';

    await activate(apiKey);

    final activations = calls.where((call) => call.method == 'activate').toList();
    expect(activations, hasLength(1));
    final configuration = (jsonDecode(activations.single.arguments as String) as Map<String, dynamic>)['configuration'];
    expect(configuration['api_key'], apiKey);
  });
}

/// The log level on `activate`. The native side always receives one: the configuration's if it
/// sets one, else the level this package logs at (`info` by default, or the one set with
/// `setLogLevel`). A level from the configuration also becomes this package's own level, before
/// the activate call is logged.
///
/// `AdaptyLogger.logLevel` is static and outlives a test, so `setUp` saves it and restates the
/// default and `tearDown` restores it: these tests pass in any order. Nothing here depends on the
/// host platform.
import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_configuration.dart' show AdaptyConfigurationJSONBuilder;
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
    AdaptyLogger.logLevel = AdaptyLogLevel.info;
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

  /// Runs [body] and returns what the SDK printed. `AdaptyLogger` writes through `print`, which is
  /// `Zone.current.print`; a zone with only a `print` specification lets errors through to the test.
  Future<List<String>> capturingLogs(Future<void> Function() body) async {
    final logs = <String>[];
    await runZoned(body, zoneSpecification: ZoneSpecification(print: (_, __, ___, line) => logs.add(line)));
    return logs;
  }

  Future<List<String>> activate(AdaptyConfiguration configuration) =>
      capturingLogs(() => Adapty().activate(configuration: configuration));

  Future<void> setLogLevel(AdaptyLogLevel level) => capturingLogs(() => Adapty().setLogLevel(level));

  /// Checks that the one `activate` request carried [configuration] as it serializes itself, with
  /// `log_level` set to [logLevel] and nothing else added or changed.
  void expectActivateSent(AdaptyConfiguration configuration, String logLevel) {
    final activations = calls.where((call) => call.method == 'activate').toList();
    expect(activations, hasLength(1));
    final expected = Map<String, dynamic>.of(configuration.jsonValue as Map<String, dynamic>);
    expected['log_level'] = logLevel;
    expect(jsonDecode(activations.single.arguments as String), {'configuration': expected});
  }

  test('withLogLevel sets the level of the native SDK and of this package', () async {
    final configuration = AdaptyConfiguration(apiKey: 'test-api-key')..withLogLevel(AdaptyLogLevel.verbose);

    await activate(configuration);

    expectActivateSent(configuration, 'verbose');
    expect(AdaptyLogger.logLevel, AdaptyLogLevel.verbose);
  });

  test('without withLogLevel, activate keeps the level set with setLogLevel on both sides', () async {
    await setLogLevel(AdaptyLogLevel.verbose);
    final configuration = AdaptyConfiguration(apiKey: 'test-api-key');

    await activate(configuration);

    expect(calls.map((call) => call.method), ['set_log_level', 'activate']);
    expectActivateSent(configuration, 'verbose');
    expect(AdaptyLogger.logLevel, AdaptyLogLevel.verbose);
  });

  test('with no level set anywhere, activate still sends log_level: info', () async {
    final configuration = AdaptyConfiguration(apiKey: 'test-api-key');

    await activate(configuration);

    expectActivateSent(configuration, 'info');
    // Literal values as well: the expected map above is built from configuration.jsonValue itself.
    final sent = jsonDecode(calls.single.arguments as String) as Map<String, dynamic>;
    expect(sent['configuration'], containsPair('log_level', 'info'));
    expect(sent['configuration'], containsPair('api_key', 'test-api-key'));
    expect(AdaptyLogger.logLevel, AdaptyLogLevel.info);
  });

  test('withLogLevel wins over a level set with setLogLevel', () async {
    await setLogLevel(AdaptyLogLevel.verbose);
    final configuration = AdaptyConfiguration(apiKey: 'test-api-key')..withLogLevel(AdaptyLogLevel.error);

    await activate(configuration);

    expectActivateSent(configuration, 'error');
    expect(AdaptyLogger.logLevel, AdaptyLogLevel.error);
  });

  test('the activate call itself is logged at the level set with withLogLevel', () async {
    final configuration = AdaptyConfiguration(apiKey: 'test-api-key')..withLogLevel(AdaptyLogLevel.verbose);

    final logs = await activate(configuration);

    final requestLines = logs.where((line) => line.contains('--> Adapty.activate()')).toList();
    expect(requestLines, hasLength(1));
    expect(requestLines.single, contains('VERBOSE'));
    expect(requestLines.single, contains('"log_level":"verbose"'));
  });

  test('a quieter withLogLevel already silences the activate call itself', () async {
    await setLogLevel(AdaptyLogLevel.verbose);
    final configuration = AdaptyConfiguration(apiKey: 'test-api-key')..withLogLevel(AdaptyLogLevel.error);

    final logs = await activate(configuration);

    expect(logs, isEmpty);
  });
}

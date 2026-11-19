// What the SDK sends to the native side for every call of the public API: one channel call of the method each case
// names, valid for the platform under the bridge contract and equal to what the native decoders of that platform read
// (test/contract/support/api_calls.dart).
import 'dart:io';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/constants/method.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/contract_schema.dart';
import '../support/contract/contract_runtime.dart';
import 'support/api_calls.dart';

/// The platforms [call] sends its method on.
Set<ContractPlatform> _sendsOn(ApiCall call) => {
  for (final MapEntry(:key, :value) in call.expected.entries)
    if (value != null) key,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AdaptyLogLevel logLevel;
  setUp(() {
    // activate and setLogLevel change the level of the logger, which activate sends.
    logLevel = AdaptyLogger.logLevel;
    AdaptyLogger.logLevel = AdaptyLogLevel.info;
  });
  tearDown(() => AdaptyLogger.logLevel = logLevel);

  group('the table', () {
    test('every method of the bridge is sent by a case', () {
      final sent = {
        for (final call in apiCalls)
          if (_sendsOn(call).isNotEmpty) call.method,
      };
      expect(NativeMethod.values.map((m) => m.wireName).where((m) => !sent.contains(m)), isEmpty);
    });

    test('every case has a name of its own and runs on at least one platform', () {
      final names = apiCalls.map((call) => call.name).toList();
      expect(names.toSet(), hasLength(names.length));
      for (final call in apiCalls) {
        expect(call.platforms, isNotEmpty, reason: call.name);
      }
    });

    test('a case names the decoders of every platform it sends on', () {
      for (final call in apiCalls) {
        for (final platform in _sendsOn(call)) {
          expect(
            call.expected[platform]!.source,
            contains('${platform.name}@'),
            reason: '${call.name} on ${platform.name}',
          );
        }
      }
    });
  });

  test('activate sends the version of the package as the version of the cross-platform SDK', () async {
    final rt = installContractRuntime(platform: ContractPlatform.ios);
    final version = RegExp(r'^version: (\S+)$', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())!;

    await Adapty().activate(configuration: AdaptyConfiguration(apiKey: 'public-key'));

    final configuration = rt.native.calls.single.arguments['configuration']! as Map<String, Object?>;
    expect(configuration['cross_platform_sdk_version'], version.group(1));
    expect(configuration['cross_platform_sdk_name'], 'flutter');
  });

  group('each case', () {
    for (final call in apiCalls) {
      for (final MapEntry(key: platform, value: expected) in call.expected.entries) {
        test('${call.name} on ${platform.name}', () async {
          final rt = installContractRuntime(platform: platform);

          await call.call(rt);

          final sent = rt.native.calls.where((c) => c.method == call.method).toList();
          if (expected == null) {
            expect(sent, isEmpty, reason: 'the SDK does not send ${call.method} on ${platform.name}');
            return;
          }
          expect(sent, hasLength(1), reason: 'one call of ${call.method}');
          expect(sent.single.normalizedArguments, expected.arguments);
        });
      }
    }
  });
}

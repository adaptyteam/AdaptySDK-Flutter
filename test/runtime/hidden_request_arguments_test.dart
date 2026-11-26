/// The arguments a request declares hidden: the `-->` line of the call shows `<redacted>` in their place, the native
/// side gets them as they are, and a call without them is logged as it is sent.
///
/// `AdaptyLogger.logLevel` is static and outlives a test, so every test restores it.
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/constants/method.dart';
import 'package:adapty_flutter/src/runtime/adapty_runtime.dart';
import 'package:adapty_flutter/src/runtime/bridge.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/capturing_log_sink.dart';
import '../support/fake_transport.dart';
import '../support/test_runtime.dart';

/// A request of no native method, which hides the `secret` key of its argument `a`.
final class _RequestWithSecret implements NativeRequest {
  const _RequestWithSecret();

  @override
  String get wireName => 'request_with_secret';

  @override
  List<String> get hiddenArguments => const ['a.secret'];
}

/// A request of no native method, which hides the `secret` key of its argument `a` and its whole argument `b`.
final class _RequestWithTwoSecrets implements NativeRequest {
  const _RequestWithTwoSecrets();

  @override
  String get wireName => 'request_with_two_secrets';

  @override
  List<String> get hiddenArguments => const ['a.secret', 'b'];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AdaptyLogLevel savedLogLevel;
  late FakeTransport fake;
  late CapturingLogSink sink;

  setUp(() {
    savedLogLevel = AdaptyLogger.logLevel;
    AdaptyLogger.logLevel = AdaptyLogLevel.verbose;
    fake = FakeTransport();
    sink = CapturingLogSink();
    installTestRuntime(transport: fake, logSink: sink, withEventHandler: false);
  });
  tearDown(() => AdaptyLogger.logLevel = savedLogLevel);

  /// Calls [request] with [arguments] and returns its `-->` line.
  Future<String> callLine(NativeRequest request, Map<String, dynamic>? arguments) async {
    await adaptyInvoke(AdaptyRuntime.current, request, (_) => null, arguments);
    return sink.lines.map((line) => line.$2).singleWhere((line) => line.contains('-->'));
  }

  test('a hidden argument of a request is <redacted> in its call line, and the native side gets it', () async {
    final line = await callLine(const _RequestWithSecret(), {
      'a': {'secret': 's3cr3t', 'other': 1},
      'b': 2,
    });

    expect(line, '[0001] --> Adapty.request_with_secret(), Args: {"a":{"secret":"<redacted>","other":1},"b":2}');
    expect(fake.calls.single.$1, 'request_with_secret');
    expect(fake.calls.single.$2, {
      'a': {'secret': 's3cr3t', 'other': 1},
      'b': 2,
    });
  });

  test('every hidden argument of a request is <redacted> in its call line, and the native side gets them', () async {
    final line = await callLine(const _RequestWithTwoSecrets(), {
      'a': {'secret': 's3cr3t', 'other': 1},
      'b': 'another s3cr3t',
      'c': 3,
    });

    expect(
      line,
      '[0001] --> Adapty.request_with_two_secrets(), Args: {"a":{"secret":"<redacted>","other":1},"b":"<redacted>","c":3}',
    );
    expect(fake.calls.single.$2, {
      'a': {'secret': 's3cr3t', 'other': 1},
      'b': 'another s3cr3t',
      'c': 3,
    });
  });

  test('a hidden argument under a map of any type is <redacted>, and the native side gets it', () async {
    for (final inner in <Map<Object?, Object?>>[
      <dynamic, dynamic>{'secret': 's3cr3t', 'other': 1},
      <Object?, Object?>{'secret': 's3cr3t', 'other': 1},
      <String, Object>{'secret': 's3cr3t', 'other': 1},
    ]) {
      sink.records.clear();
      fake.calls.clear();
      final line = await callLine(const _RequestWithSecret(), {'a': inner, 'b': 2});

      expect(line, endsWith('Args: {"a":{"secret":"<redacted>","other":1},"b":2}'), reason: '${inner.runtimeType}');
      expect(fake.calls.single.$2, {
        'a': {'secret': 's3cr3t', 'other': 1},
        'b': 2,
      });
    }
  });

  test('activate logs the API key as <redacted> when the configuration is an untyped map', () async {
    final line = await callLine(NativeMethod.activate, {
      'configuration': <dynamic, dynamic>{'api_key': 'SECRET-KEY'},
    });

    expect(line, '[0001] --> Adapty.activate(), Args: {"configuration":{"api_key":"<redacted>"}}');
  });

  test('a call without the hidden argument is logged as it is sent', () async {
    final arguments = <String, dynamic>{
      'a': {'other': 1},
      'b': 2,
    };

    expect(
      await callLine(const _RequestWithSecret(), arguments),
      '[0001] --> Adapty.request_with_secret(), Args: {"a":{"other":1},"b":2}',
    );
  });

  test('a hidden argument under a value that is not an object is not looked for', () async {
    for (final arguments in <Map<String, dynamic>?>[
      {'a': 's3cr3t'},
      {
        'a': [
          {'secret': 's3cr3t'},
        ],
      },
      {'b': 2},
      null,
    ]) {
      sink.records.clear();
      final line = await callLine(const _RequestWithSecret(), arguments);
      expect(line, endsWith('Args: ${arguments == null ? '{}' : _encoded(arguments)}'), reason: '$arguments');
    }
  });

  test('activate logs the API key as <redacted>, and the native side gets the key', () async {
    final line = await callLine(NativeMethod.activate, {
      'configuration': {'api_key': 'key-prefix.secret-part', 'log_level': 'verbose'},
    });

    expect(
      line,
      '[0001] --> Adapty.activate(), Args: {"configuration":{"api_key":"<redacted>","log_level":"verbose"}}',
    );
    expect(fake.calls.single.$2, {
      'configuration': {'api_key': 'key-prefix.secret-part', 'log_level': 'verbose'},
    });
  });

  test('activate without an API key is logged as it is sent', () async {
    expect(
      await callLine(NativeMethod.activate, {
        'configuration': {'log_level': 'verbose'},
      }),
      '[0001] --> Adapty.activate(), Args: {"configuration":{"log_level":"verbose"}}',
    );
  });

  test('NativeMethod.activate hides exactly the API key of the configuration, and every other request nothing', () {
    expect(
      {
        for (final request in <NativeRequest>[...NativeMethod.values, ...NativeEventResponse.values])
          if (request.hiddenArguments.isNotEmpty) request.wireName: request.hiddenArguments,
      },
      {
        'activate': ['configuration.api_key'],
      },
    );
  });

  test('no answer to an event hides anything', () {
    expect(
      {for (final response in NativeEventResponse.values) response.wireName: response.hiddenArguments},
      {for (final response in NativeEventResponse.values) response.wireName: isEmpty},
    );
  });
}

String _encoded(Map<String, dynamic> arguments) => json.encode(arguments);

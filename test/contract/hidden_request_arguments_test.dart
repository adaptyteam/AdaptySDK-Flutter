// The arguments a request declares hidden from the log (`NativeRequest.hiddenArguments`) never reach it, in any case
// of the public API under test/contract/support/api_calls.dart: each case runs against the contract native of every
// platform it sends on, the native side gets the value of the golden request, and no line of the log holds it. When
// the log level lets the call line through, that line shows `<redacted>` in its place.
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/constants/method.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contract/contract_runtime.dart';
import 'support/api_calls.dart';

/// The value at the dotted [path] of [arguments], or null when the arguments have none.
Object? _valueAt(Map<String, Object?> arguments, String path) {
  Object? value = arguments;
  for (final key in path.split('.')) {
    if (value is! Map<String, Object?> || !value.containsKey(key)) return null;
    value = value[key];
  }
  return value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final hidden = {
    for (final request in <NativeRequest>[...NativeMethod.values, ...NativeEventResponse.values])
      if (request.hiddenArguments.isNotEmpty) request.wireName: request.hiddenArguments,
  };
  final cases = [
    for (final call in apiCalls)
      if (hidden.containsKey(call.method))
        for (final MapEntry(key: platform, value: expected) in call.expected.entries)
          if (expected != null) (call: call, platform: platform, expected: expected),
  ];

  late AdaptyLogLevel logLevel;
  setUp(() => logLevel = AdaptyLogger.logLevel);
  tearDown(() => AdaptyLogger.logLevel = logLevel);

  test('some case of the public API sends a request with hidden arguments', () {
    expect(cases, isNotEmpty);
  });

  group('each case', () {
    var ran = 0, logged = 0;
    tearDownAll(() {
      // Only when every case ran: a run of some of them by name need not reach one that logs its call line.
      if (ran == cases.length) expect(logged, greaterThan(0), reason: 'no case let its call line through');
    });

    for (final (:call, :platform, :expected) in cases) {
      test('${call.name} on ${platform.name}', () async {
        final rt = installContractRuntime(platform: platform);
        rt.native.expectCase(call.name);
        AdaptyLogger.logLevel = AdaptyLogLevel.verbose;

        await call.call(rt);

        final paths = hidden[call.method]!;
        final secrets = {
          for (final path in paths)
            if (_valueAt(expected.arguments, path) case final Object value) path: value,
        };
        expect(secrets, isNotEmpty, reason: 'the golden request of the case has none of $paths');
        final sent = rt.native.calls.singleWhere((c) => c.method == call.method);
        for (final MapEntry(key: path, value: secret) in secrets.entries) {
          expect(_valueAt(sent.arguments, path), secret, reason: 'the native side gets $path');
          for (final (_, line) in rt.log.lines) {
            expect(line, isNot(contains(json.encode(secret))), reason: path);
            if (secret is String) expect(line, isNot(contains(secret)), reason: path);
          }
        }

        final prefix = '--> Adapty.${call.method}(), Args: ';
        final callLines = [
          for (final (_, line) in rt.log.lines)
            if (line.contains(prefix)) line,
        ];
        if (AdaptyLogger.logLevel.index < AdaptyLogLevel.verbose.index) {
          expect(callLines, isEmpty);
        } else {
          expect(callLines, hasLength(1), reason: 'the level lets the call line through');
          final shown = jsonDecode(callLines.single.substring(callLines.single.indexOf(prefix) + prefix.length));
          for (final path in secrets.keys) {
            expect(_valueAt(shown as Map<String, Object?>, path), '<redacted>', reason: path);
          }
          logged++;
        }
        ran++;
      });
    }
  });
}

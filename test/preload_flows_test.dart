import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    _mockNative(calls, {'success': true});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('preloadFlows sends the timeout in seconds as given, a zero or negative one included', () async {
    await Adapty().preloadFlows(placementIds: ['a', 'b'], loadTimeout: const Duration(milliseconds: 1500));
    await Adapty().preloadFlows(placementIds: ['a', 'b'], loadTimeout: Duration.zero);
    await Adapty().preloadFlows(placementIds: ['a', 'b'], loadTimeout: const Duration(milliseconds: -500));

    expect(calls.map((call) => call.method), ['preload_flows', 'preload_flows', 'preload_flows']);
    expect(calls.map((call) => jsonDecode(call.arguments as String)), [
      {
        'placement_ids': ['a', 'b'],
        'load_timeout': 1.5,
      },
      {
        'placement_ids': ['a', 'b'],
        'load_timeout': 0.0,
      },
      {
        'placement_ids': ['a', 'b'],
        'load_timeout': -0.5,
      },
    ]);
  });

  test('preloadFlows without a timeout leaves load_timeout out, so the native default applies', () async {
    await Adapty().preloadFlows(placementIds: ['a', 'b']);

    expect(calls.single.method, 'preload_flows');
    expect(jsonDecode(calls.single.arguments as String), {
      'placement_ids': ['a', 'b'],
    });
  });

  test('preloadFlowsForDefaultAudience sends only the placement ids', () async {
    await Adapty().preloadFlowsForDefaultAudience(placementIds: ['a', 'b']);

    expect(calls.single.method, 'preload_flows_for_default_audience');
    expect(jsonDecode(calls.single.arguments as String), {
      'placement_ids': ['a', 'b'],
    });
  });

  test('both methods forward the ids as given: an empty list, duplicates and blank ids included', () async {
    const ids = ['a', 'a', ' b ', ''];

    await Adapty().preloadFlows(placementIds: []);
    await Adapty().preloadFlowsForDefaultAudience(placementIds: []);
    await Adapty().preloadFlows(placementIds: ids);
    await Adapty().preloadFlowsForDefaultAudience(placementIds: ids);

    expect(calls.map((call) => call.method), [
      'preload_flows',
      'preload_flows_for_default_audience',
      'preload_flows',
      'preload_flows_for_default_audience',
    ]);
    expect(calls.map((call) => jsonDecode(call.arguments as String)), [
      {'placement_ids': []},
      {'placement_ids': []},
      {'placement_ids': ids},
      {'placement_ids': ids},
    ]);
  });

  test('a failed preload reaches the caller as the native AdaptyError, from either method', () async {
    _mockNative(calls, {
      'error': {'adapty_code': 2005, 'message': 'Failed to preload 1 placement(s): [b: Request failed]'},
    });

    for (final preload in [
      () => Adapty().preloadFlows(placementIds: ['a', 'b']),
      () => Adapty().preloadFlowsForDefaultAudience(placementIds: ['a', 'b']),
    ]) {
      await expectLater(
        preload(),
        throwsA(
          isA<AdaptyError>()
              .having((error) => error.code, 'code', AdaptyErrorCode.networkFailed)
              .having((error) => error.message, 'message', 'Failed to preload 1 placement(s): [b: Request failed]'),
        ),
      );
    }
  });

  test('a preload without activate goes to the native side, and its not-activated error comes back as is', () async {
    _mockNative(calls, {
      'error': {'adapty_code': 20, 'message': 'Adapty was not initialized'},
    });

    await expectLater(
      Adapty().preloadFlows(placementIds: ['a']),
      throwsA(
        isA<AdaptyError>()
            .having((error) => error.code, 'code', AdaptyErrorCode.adaptyNotInitialized)
            .having((error) => error.message, 'message', 'Adapty was not initialized'),
      ),
    );
    expect(calls.single.method, 'preload_flows');
  });

  test('a native exception in place of a reply reaches the caller as an AdaptyError', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      throw PlatformException(code: 'error', message: 'Parameter specified as non-null is null');
    });

    await expectLater(
      Adapty().preloadFlows(placementIds: ['a']),
      throwsA(
        isA<AdaptyError>()
            .having((error) => error.code, 'code', AdaptyErrorCode.internalPluginError)
            .having((error) => error.message, 'message', 'Internal plugin error in Adapty.preload_flows()'),
      ),
    );
  });
}

/// Records every call into [calls] and answers each one with [reply].
void _mockNative(List<MethodCall> calls, Map<String, dynamic> reply) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
    calls.add(call);
    return jsonEncode(reply);
  });
}

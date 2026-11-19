import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

// No flows events observer is set in this file, so the events go to the SDK's default handling.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];

  /// Delivers the event in a guarded zone and returns what escaped it uncaught.
  Future<List<Object>> sendEventCatchingUncaught(String method, Map<String, dynamic> arguments) async {
    final caught = <Object>[];
    await runZonedGuarded(() async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        _channel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, jsonEncode(arguments))),
        (_) {},
      );
      await pumpEventQueue();
    }, (error, _) => caught.add(error));
    return caught;
  }

  setUp(() {
    calls.clear();
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return jsonEncode({
        'error': {'adapty_code': 3001, 'message': 'the view is not found'},
      });
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('a failing default dismiss surfaces as an uncaught error', () async {
    final caught = await sendEventCatchingUncaught('flow_view_did_perform_action', {
      'view': {'id': 'v1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
      'action': {'type': 'close'},
    });

    expect(calls.map((call) => call.method), ['adapty_ui_dismiss_flow_view']);
    expect(caught, [isA<AdaptyError>().having((e) => e.code, 'code', 3001)]);
  });

  test('a failing default openUrl surfaces as an uncaught error', () async {
    final caught = await sendEventCatchingUncaught('flow_view_did_perform_action', {
      'view': {'id': 'v1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
      'action': {'type': 'open_url', 'value': 'https://adapty.io', 'open_in': 'browser_out_app'},
    });

    expect(calls.map((call) => call.method), ['adapty_ui_open_url']);
    expect(caught, [isA<AdaptyError>().having((e) => e.code, 'code', 3001)]);
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

/// Keeps the action handling it inherits from [AdaptyUIFlowsEventsObserver].
class _Observer extends AdaptyUIFlowsEventsObserver {
  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) {}

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  final printed = <String>[];

  /// Delivers the event in a guarded zone and returns what escaped it uncaught.
  Future<List<Object>> sendEventCatchingUncaught(String method, Map<String, dynamic> arguments) async {
    final caught = <Object>[];
    await runZonedGuarded(
      () async {
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
          _channel.name,
          const StandardMethodCodec().encodeMethodCall(MethodCall(method, jsonEncode(arguments))),
          (_) {},
        );
        await pumpEventQueue();
      },
      (error, _) => caught.add(error),
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => printed.add(line)),
    );
    return caught;
  }

  Iterable<String> loggedFailures(String label) =>
      printed.where((line) => line.contains('ERROR: Adapty background call $label failed'));

  setUp(() {
    calls.clear();
    printed.clear();
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
    AdaptyUI().setFlowsEventsObserver(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('a flow error without an observer makes no call that could fail', () async {
    final caught = await sendEventCatchingUncaught('flow_view_did_receive_error', {
      'view': {'id': 'v1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
      'error': {'adapty_code': 2002, 'message': 'rendering failed'},
    });

    expect(calls, isEmpty);
    expect(caught, isEmpty);
    expect(loggedFailures('default_observer.dismiss'), isEmpty);
  });

  test('a failing dismiss of the inherited action handling is logged, not thrown', () async {
    AdaptyUI().setFlowsEventsObserver(_Observer());

    final caught = await sendEventCatchingUncaught('flow_view_did_perform_action', {
      'view': {'id': 'v1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
      'action': {'type': 'close'},
    });

    expect(calls.map((call) => call.method), ['adapty_ui_dismiss_flow_view']);
    expect(caught, isEmpty);
    expect(loggedFailures('default_observer.dismiss'), hasLength(1));
  });

  test('a failing openUrl of the inherited action handling is logged, not thrown', () async {
    AdaptyUI().setFlowsEventsObserver(_Observer());

    final caught = await sendEventCatchingUncaught('flow_view_did_perform_action', {
      'view': {'id': 'v1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
      'action': {'type': 'open_url', 'value': 'https://adapty.io', 'open_in': 'browser_out_app'},
    });

    expect(calls.map((call) => call.method), ['adapty_ui_open_url']);
    expect(caught, isEmpty);
    expect(loggedFailures('default_observer.open_url'), hasLength(1));
  });
}

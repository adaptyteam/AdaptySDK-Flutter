import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

class _Observer extends AdaptyUIFlowsEventsObserver {
  final actions = <AdaptyUIAction>[];

  @override
  void flowViewDidPerformAction(AdaptyUIFlowView view, AdaptyUIAction action) {
    actions.add(action);
  }

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

/// Keeps the inherited action handling, so the default reaction to an action is what runs.
class _DefaultActionObserver extends AdaptyUIFlowsEventsObserver {
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

  Future<void> sendEvent(String method, Map<String, dynamic> arguments) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, jsonEncode(arguments))),
      (_) {},
    );
    await pumpEventQueue();
  }

  setUp(() {
    calls.clear();
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return jsonEncode({'success': null});
    });
  });

  tearDown(() {
    AdaptyUI().setFlowsEventsObserver(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('the removed paywall_view_did_perform_system_back_action reaches no observer', () async {
    final observer = _Observer();
    AdaptyUI().setFlowsEventsObserver(observer);

    await sendEvent('paywall_view_did_perform_system_back_action', {
      'view': {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
    });

    expect(observer.actions, isEmpty);
    expect(calls, isEmpty);
  });

  test('a system back press reaches the global observer as AndroidSystemBackAction', () async {
    final observer = _Observer();
    AdaptyUI().setFlowsEventsObserver(observer);

    await sendEvent('flow_view_did_perform_action', {
      'view': {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
      'action': {'type': 'system_back'},
    });

    expect(observer.actions, [isA<AndroidSystemBackAction>()]);
    expect(calls, isEmpty);
  });

  test('a system back press does not dismiss the view by default', () async {
    AdaptyUI().setFlowsEventsObserver(_DefaultActionObserver());

    await sendEvent('flow_view_did_perform_action', {
      'view': {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
      'action': {'type': 'system_back'},
    });

    expect(calls, isEmpty);
  });
}

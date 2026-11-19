import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

class _Observer extends AdaptyUIFlowsEventsObserver {
  final viewIds = <String>[];
  final actions = <AdaptyUIAction>[];

  @override
  void flowViewDidPerformAction(AdaptyUIFlowView view, AdaptyUIAction action) {
    viewIds.add(view.id);
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

  test('the dead paywall_view_did_perform_system_back_action still reaches the observer', () async {
    final observer = _Observer();
    AdaptyUI().setFlowsEventsObserver(observer);

    await sendEvent('paywall_view_did_perform_system_back_action', {
      'view': {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
    });

    expect(observer.actions, [isA<AndroidSystemBackAction>()]);
    expect(observer.viewIds, ['view-1']);
    expect(calls, isEmpty);
  });
}

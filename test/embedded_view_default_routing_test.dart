import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

/// Keeps the action handling it inherits from [AdaptyUIFlowsEventsObserver].
class _Observer extends AdaptyUIFlowsEventsObserver {
  final actions = <AdaptyUIAction>[];

  @override
  void flowViewDidPerformAction(AdaptyUIFlowView view, AdaptyUIAction action) {
    actions.add(action);
    super.flowViewDidPerformAction(view, action);
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

  test(
    'a global observer that keeps the inherited action handling leaves an embedded view to its widget on close',
    () async {
      final observer = _Observer();
      AdaptyUI().setFlowsEventsObserver(observer);

      await sendEvent('flow_view_did_perform_action', {
        'view': {'id': 'flutter_native_5', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
        'action': {'type': 'close'},
      });

      expect(observer.actions, [isA<CloseAction>()]);
      expect(calls, isEmpty);
    },
  );

  group('close of a view created by createFlowView is still dismissed', () {
    for (final (name, observer) in [('by default', null), ('by the inherited default handling', _Observer())]) {
      test(name, () async {
        if (observer != null) AdaptyUI().setFlowsEventsObserver(observer);

        await sendEvent('flow_view_did_perform_action', {
          'view': {'id': 'view-7', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
          'action': {'type': 'close'},
        });

        expect(calls.map((call) => call.method), ['adapty_ui_dismiss_flow_view']);
        expect(jsonDecode(calls.single.arguments as String), {'id': 'view-7', 'destroy': true});
      });
    }
  });

  group('open_url of an embedded view is still opened', () {
    for (final (name, observer) in [
      ('by default when nobody listens to the view', null),
      ('by the inherited default handling', _Observer()),
    ]) {
      test(name, () async {
        if (observer != null) AdaptyUI().setFlowsEventsObserver(observer);

        await sendEvent('flow_view_did_perform_action', {
          'view': {'id': 'flutter_native_6', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
          'action': {'type': 'open_url', 'value': 'https://adapty.io', 'open_in': 'browser_out_app'},
        });

        expect(calls.map((call) => call.method), ['adapty_ui_open_url']);
        expect(jsonDecode(calls.single.arguments as String), {
          'url': 'https://adapty.io',
          'open_in': 'browser_out_app',
        });
      });
    }
  });
}

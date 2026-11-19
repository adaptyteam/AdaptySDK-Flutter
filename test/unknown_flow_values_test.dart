// ignore_for_file: deprecated_member_use
/// Flow and onboarding values this version has no constant for, as a newer native SDK could send
/// them in an event: what reaches the observer today.
import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

const _view = {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'};

class _FlowObserver extends AdaptyUIFlowsEventsObserver {
  final actions = <AdaptyUIAction>[];

  @override
  void flowViewDidPerformAction(AdaptyUIFlowView view, AdaptyUIAction action) => actions.add(action);

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

class _OnboardingObserver extends AdaptyUIOnboardingsEventsObserver {
  final stateUpdates = <String>[];

  @override
  void onboardingViewOnStateUpdatedAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String elementId,
    AdaptyOnboardingsStateUpdatedParams params,
  ) => stateUpdates.add(elementId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<String>> sendEventCapturingLogs(String method, Map<String, dynamic> arguments) async {
    final logs = <String>[];
    await runZoned(() async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        _channel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, jsonEncode(arguments))),
        (_) {},
      );
      await pumpEventQueue();
    }, zoneSpecification: ZoneSpecification(print: (_, _, _, line) => logs.add(line)));
    return logs;
  }

  setUp(() {
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => jsonEncode({'success': null}),
    );
  });

  tearDown(() {
    AdaptyUI().setFlowsEventsObserver(null);
    AdaptyUI().setOnboardingsEventsObserver(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('an unknown action type arrives as a CustomAction with a made-up name', () async {
    final observer = _FlowObserver();
    AdaptyUI().setFlowsEventsObserver(observer);

    await sendEventCapturingLogs('flow_view_did_perform_action', {
      'view': _view,
      'action': {'type': 'future_action'},
    });

    final action = observer.actions.single as CustomAction;
    expect(action.action, 'Unknown action type: future_action');
    expect(action.arguments, isNull);
  });

  test('an unknown open_in decodes as externalBrowser', () async {
    final observer = _FlowObserver();
    AdaptyUI().setFlowsEventsObserver(observer);

    await sendEventCapturingLogs('flow_view_did_perform_action', {
      'view': _view,
      'action': {'type': 'open_url', 'value': 'https://example.com/terms', 'open_in': 'future'},
    });

    final action = observer.actions.single as OpenUrlAction;
    expect(action.url, 'https://example.com/terms');
    expect(action.openIn, AdaptyWebPresentation.externalBrowser);
  });

  test('an unknown onboarding element type loses the event', () async {
    final observer = _OnboardingObserver();
    AdaptyUI().setOnboardingsEventsObserver(observer);

    final logs = await sendEventCapturingLogs('onboarding_on_state_updated_action', {
      'view': _view,
      'meta': {'onboarding_id': 'onboarding-id', 'screen_cid': 'screen-1', 'screen_index': 2, 'total_screens': 5},
      'action': {'element_id': 'element-1', 'element_type': 'future', 'value': 'a'},
    });

    expect(observer.stateUpdates, isEmpty);
    expect(
      logs.where((line) => line.contains('ERROR:') && line.contains('Unknown element type: future')),
      hasLength(1),
    );
  });
}

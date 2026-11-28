// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

class _FlowObserver extends AdaptyUIFlowsEventsObserver {
  _FlowObserver({this.throwing = false});

  final bool throwing;
  final appeared = <String>[];

  @override
  void flowViewDidAppear(AdaptyUIFlowView view) {
    appeared.add(view.id);
    if (throwing) throw StateError('observer boom');
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

class _OnboardingObserver extends AdaptyUIOnboardingsEventsObserver {
  _OnboardingObserver({this.throwing = false});

  final bool throwing;
  final loaded = <String>[];

  @override
  void onboardingViewDidFinishLoading(AdaptyUIOnboardingView view, AdaptyUIOnboardingMeta meta) {
    loaded.add(view.id);
    if (throwing) throw StateError('observer boom');
  }
}

Map<String, dynamic> _view(String id) => {'id': id, 'placement_id': 'placement-id', 'variation_id': 'variation-id'};

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
      (call) async => jsonEncode({'success': true}),
    );
  });

  tearDown(() {
    AdaptyUI().unregisterFlowEventsListener('flutter_native_1');
    AdaptyUI().unregisterOnboardingEventsListener('flutter_native_2');
    AdaptyUI().setFlowsEventsObserver(null);
    AdaptyUI().setOnboardingsEventsObserver(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('a throwing embedded view observer does not keep the global observer from the event', () async {
    final widget = _FlowObserver(throwing: true);
    final global = _FlowObserver();
    AdaptyUI().registerFlowEventsListener(widget, 'flutter_native_1');
    AdaptyUI().setFlowsEventsObserver(global);

    final logs = await sendEventCapturingLogs('flow_view_did_appear', {'view': _view('flutter_native_1')});

    expect(widget.appeared, ['flutter_native_1']);
    expect(global.appeared, ['flutter_native_1']);
    expect(logs.where((line) => line.contains('ERROR:') && line.contains('observer boom')), hasLength(1));
  });

  test('a throwing onboarding observer does not keep the global observer from the event', () async {
    final widget = _OnboardingObserver(throwing: true);
    final global = _OnboardingObserver();
    AdaptyUI().registerOnboardingEventsListener(widget, 'flutter_native_2');
    AdaptyUI().setOnboardingsEventsObserver(global);

    final logs = await sendEventCapturingLogs('onboarding_did_finish_loading', {
      'view': _view('flutter_native_2'),
      'meta': {'onboarding_id': 'onboarding-id', 'screen_cid': 'screen-1', 'screen_index': 0, 'total_screens': 3},
    });

    expect(widget.loaded, ['flutter_native_2']);
    expect(global.loaded, ['flutter_native_2']);
    expect(logs.where((line) => line.contains('ERROR:') && line.contains('observer boom')), hasLength(1));
  });
}

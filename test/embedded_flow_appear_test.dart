import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

class _Observer extends AdaptyUIFlowsEventsObserver {
  final appeared = <AdaptyUIFlowView>[];

  @override
  void flowViewDidAppear(AdaptyUIFlowView view) => appeared.add(view);

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

  final usedIds = <String>{};

  // The event the iOS platform view sends once the flow is added to it.
  Future<void> sendAppear(String viewId) async {
    usedIds.add(viewId);
    final arguments = {
      'id': 'flow_view_did_appear',
      'view': {'id': viewId, 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
    };
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall('flow_view_did_appear', jsonEncode(arguments))),
      (_) {},
    );
    await pumpEventQueue();
  }

  void register(AdaptyUIFlowsEventsObserver observer, String viewId) {
    usedIds.add(viewId);
    AdaptyUI().registerFlowEventsListener(observer, viewId);
  }

  setUp(() {
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => null,
    );
  });

  tearDown(() {
    AdaptyUI().setFlowsEventsObserver(null);
    for (final id in usedIds) {
      AdaptyUI().unregisterFlowEventsListener(id);
    }
    usedIds.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('an appear of an embedded view reaches the widget and the observer once', () async {
    final observer = _Observer();
    final widget = _Observer();
    final otherBefore = _Observer();
    final otherAfter = _Observer();
    AdaptyUI().setFlowsEventsObserver(observer);
    // Other widgets registered before and after the one the event is for.
    register(otherBefore, 'flutter_native_49');
    register(widget, 'flutter_native_50');
    register(otherAfter, 'flutter_native_52');

    await sendAppear('flutter_native_50');

    expect(widget.appeared.map((view) => view.id), ['flutter_native_50']);
    expect(otherBefore.appeared, isEmpty);
    expect(otherAfter.appeared, isEmpty);
    expect(observer.appeared.map((view) => view.id), ['flutter_native_50']);
  });

  test('an appear of an embedded view whose widget is removed reaches only the observer', () async {
    final observer = _Observer();
    final widget = _Observer();
    AdaptyUI().setFlowsEventsObserver(observer);
    register(widget, 'flutter_native_51');
    AdaptyUI().unregisterFlowEventsListener('flutter_native_51');

    await sendAppear('flutter_native_51');

    expect(widget.appeared, isEmpty);
    expect(observer.appeared.map((view) => view.id), ['flutter_native_51']);
  });
}

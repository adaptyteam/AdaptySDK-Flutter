import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/adaptyui_events_proxy.dart' show AdaptyEmbeddedFlowActions;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

/// Stands for the widget: [handlesActions] tells whether the app passed `onDidPerformAction`.
class _Widget extends AdaptyUIFlowsEventsObserver implements AdaptyEmbeddedFlowActions {
  _Widget({required this.handlesActions, this.throws = false});

  @override
  final bool handlesActions;
  final bool throws;
  final actions = <AdaptyUIAction>[];

  @override
  void flowViewDidPerformAction(AdaptyUIFlowView view, AdaptyUIAction action) {
    actions.add(action);
    if (throws) throw StateError('the callback failed');
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

/// The app's own observer: handles every action itself and records it.
class _HandlingObserver extends _Observer {
  final actions = <AdaptyUIAction>[];

  @override
  void flowViewDidPerformAction(AdaptyUIFlowView view, AdaptyUIAction action) => actions.add(action);
}

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
  final usedIds = <String>{};

  const openUrl = {'type': 'open_url', 'value': 'https://example.com/terms', 'open_in': 'browser_out_app'};

  Future<void> sendAction(String viewId, Map<String, dynamic> action) async {
    await runZoned(
      () async {
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
          _channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(
              'flow_view_did_perform_action',
              jsonEncode({
                'view': {'id': viewId, 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
                'action': action,
              }),
            ),
          ),
          (_) {},
        );
        await pumpEventQueue();
      },
      zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}),
    );
  }

  void register(AdaptyUIFlowsEventsObserver widget, String viewId) {
    usedIds.add(viewId);
    AdaptyUI().registerFlowEventsListener(widget, viewId);
  }

  int opens() => calls.where((call) => call.method == 'adapty_ui_open_url').length;

  setUp(() {
    calls.clear();
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return jsonEncode({'success': true});
    });
  });

  tearDown(() {
    AdaptyUI().setFlowsEventsObserver(null);
    for (final id in usedIds) {
      AdaptyUI().unregisterFlowEventsListener(id);
    }
    usedIds.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('without a callback and without an observer, the SDK opens the link once', () async {
    final widget = _Widget(handlesActions: false);
    register(widget, 'flutter_native_70');

    await sendAction('flutter_native_70', openUrl);

    expect(opens(), 1);
    expect(widget.actions, isEmpty);
  });

  test('with a callback and without an observer, the SDK opens nothing and the callback gets the action', () async {
    final widget = _Widget(handlesActions: true);
    register(widget, 'flutter_native_71');

    await sendAction('flutter_native_71', openUrl);

    expect(opens(), 0);
    expect(widget.actions, hasLength(1));
    expect(widget.actions.single, isA<OpenUrlAction>());
  });

  test('without a callback, an observer that keeps the default handling opens the link once', () async {
    AdaptyUI().setFlowsEventsObserver(_Observer());
    register(_Widget(handlesActions: false), 'flutter_native_72');

    await sendAction('flutter_native_72', openUrl);

    expect(opens(), 1);
  });

  test('with a callback, an observer that keeps the default handling opens the link once', () async {
    final widget = _Widget(handlesActions: true);
    AdaptyUI().setFlowsEventsObserver(_Observer());
    register(widget, 'flutter_native_73');

    await sendAction('flutter_native_73', openUrl);

    expect(opens(), 1);
    expect(widget.actions, hasLength(1));
  });

  test('a close action of an embedded flow without a callback is not dismissed', () async {
    register(_Widget(handlesActions: false), 'flutter_native_74');

    await sendAction('flutter_native_74', {'type': 'close'});

    expect(calls.where((call) => call.method == 'adapty_ui_dismiss_flow_view'), isEmpty);
  });

  test('a callback that throws, with an observer set, still lets the observer open the link once', () async {
    final widget = _Widget(handlesActions: true, throws: true);
    AdaptyUI().setFlowsEventsObserver(_Observer());
    register(widget, 'flutter_native_75');

    await sendAction('flutter_native_75', openUrl);

    expect(widget.actions, hasLength(1));
    expect(opens(), 1);
  });

  test('without a callback, an observer that handles actions itself gets the link and the SDK opens nothing', () async {
    final widget = _Widget(handlesActions: false);
    final observer = _HandlingObserver();
    AdaptyUI().setFlowsEventsObserver(observer);
    register(widget, 'flutter_native_76');

    await sendAction('flutter_native_76', openUrl);

    expect(observer.actions, hasLength(1));
    expect(observer.actions.single, isA<OpenUrlAction>());
    expect(widget.actions, isEmpty);
    expect(opens(), 0);
  });
}

import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_flow.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// On Android, when the native view of a mounted AdaptyUIFlowPlatformView is detached from the window and attached
// again, the native SDK sends a disappear on the detach and an appear again on the attach. The SDK forwards each of
// them to the widget and to the flows events observer: it doesn't report the appear only once.

const _channel = MethodChannel('flutter.adapty.com/adapty');
const _viewId = 'flutter_native_80';

class _Observer extends AdaptyUIFlowsEventsObserver {
  final events = <String>[];

  @override
  void flowViewDidAppear(AdaptyUIFlowView view) => events.add('appear:${view.id}');

  @override
  void flowViewDidDisappear(AdaptyUIFlowView view) => events.add('disappear:${view.id}');

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

Future<void> _send(String method) async {
  final arguments = {
    'id': method,
    'view': {'id': _viewId, 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
  };
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    _channel.name,
    const StandardMethodCodec().encodeMethodCall(MethodCall(method, jsonEncode(arguments))),
    (_) {},
  );
}

AdaptyFlow _flow() => AdaptyFlowJSONBuilder.fromJsonValue({
  'placement': {
    'developer_id': 'placement-id',
    'audience_name': 'Audience',
    'revision': 1,
    'ab_test_name': 'Experiment',
    'placement_audience_version_id': 'placement-audience-version-id',
  },
  'flow_id': 'flow-id',
  'flow_name': 'Flow',
  'variation_id': 'variation-id',
  'remote_configs': <dynamic>[],
  'variations': <dynamic>[],
  'response_created_at': 0,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    AdaptyUI().unregisterFlowEventsListener(_viewId);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  testWidgets('the widget and the observer get appear, disappear, appear across a detach and attach', (tester) async {
    final widgetEvents = <String>[];
    final observer = _Observer();
    AdaptyUI().setFlowsEventsObserver(observer);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: AdaptyUIFlowPlatformView(
          flow: _flow(),
          onDidAppear: (view) => widgetEvents.add('appear:${view.id}'),
          onDidDisappear: (view) => widgetEvents.add('disappear:${view.id}'),
        ),
      ),
    );
    // The test host builds neither a UiKitView nor an AndroidView, so the platform view is never created: register
    // the widget's own State under the view id, as its onPlatformViewCreated does.
    final state = tester.state(find.byType(AdaptyUIFlowPlatformView));
    AdaptyUI().registerFlowEventsListener(state as AdaptyUIFlowsEventsObserver, _viewId);

    await tester.runAsync(() async {
      await _send('flow_view_did_appear'); // The flow has loaded into the widget.
      await _send('flow_view_did_disappear'); // The native view is detached from the window.
      await _send('flow_view_did_appear'); // The native view is attached again.
      await Future<void>.delayed(Duration.zero);
    });

    const expected = ['appear:$_viewId', 'disappear:$_viewId', 'appear:$_viewId'];
    expect(widgetEvents, expected);
    expect(observer.events, expected);
  });
}

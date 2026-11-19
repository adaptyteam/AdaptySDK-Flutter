// Where an action of a flow shown by AdaptyUIFlowPlatformView goes: to the widget's onDidPerformAction, to the flows
// observer and to the default handling, and what each of them calls on the native side.
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_flow.dart';
import 'package:adapty_flutter/src/runtime/adapty_platform_info.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_platform_views.dart';
import 'support/fake_transport.dart';
import 'support/test_platform_info.dart';
import 'support/test_runtime.dart';

const _flowViewType = 'adaptyui_flow_platform_view';

const _openUrl = {'type': 'open_url', 'value': 'https://adapty.io', 'open_in': 'browser_out_app'};

/// Keeps the action handling it inherits from [AdaptyUIFlowsEventsObserver].
class _InheritingObserver extends AdaptyUIFlowsEventsObserver {
  @override
  void flowViewDidFinishPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product, AdaptyPurchaseResult result) {}

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) {}
}

/// Handles actions itself: records each one and opens nothing.
class _RecordingObserver extends _InheritingObserver {
  final actions = <AdaptyUIAction>[];

  @override
  void flowViewDidPerformAction(AdaptyUIFlowView view, AdaptyUIAction action) => actions.add(action);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a link of an embedded flow with onDidPerformAction goes to the callback and is not opened', (
    tester,
  ) async {
    final seen = <AdaptyUIAction>[];
    final (transport, viewId) = await _mount(tester, onDidPerformAction: (view, action) => seen.add(action));

    await _deliverAction(tester, transport, viewId, _openUrl);

    expect(seen, [_isLink]);
    expect(transport.calls, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'a link of an embedded flow with onDidPerformAction is opened once by a flows observer that keeps the default '
    'handling',
    (tester) async {
      final seen = <AdaptyUIAction>[];
      final (transport, viewId) = await _mount(
        tester,
        global: _InheritingObserver(),
        onDidPerformAction: (view, action) => seen.add(action),
      );

      await _deliverAction(tester, transport, viewId, _openUrl);

      expect(seen, [_isLink]);
      expect(transport.calls.map((c) => c.$1), ['adapty_ui_open_url']);
      expect(transport.calls.single.$2, {'url': 'https://adapty.io', 'open_in': 'browser_out_app'});
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a link of an embedded flow without onDidPerformAction is opened by a flows observer that keeps the default '
    'handling',
    (tester) async {
      final (transport, viewId) = await _mount(tester, global: _InheritingObserver());

      await _deliverAction(tester, transport, viewId, _openUrl);

      expect(transport.calls.map((c) => c.$1), ['adapty_ui_open_url']);
      expect(transport.calls.single.$2, {'url': 'https://adapty.io', 'open_in': 'browser_out_app'});
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a link of an embedded flow without onDidPerformAction goes to a flows observer that handles it', (
    tester,
  ) async {
    final global = _RecordingObserver();
    final (transport, viewId) = await _mount(tester, global: global);

    await _deliverAction(tester, transport, viewId, _openUrl);

    expect(global.actions, [_isLink]);
    expect(transport.calls, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a link of a flow presented with createFlowView opens when no observer is set', (tester) async {
    final transport = FakeTransport();
    installTestRuntime(transport: transport, platform: _uiKit);

    await _deliverAction(tester, transport, 'view-7', _openUrl);

    expect(transport.calls.map((c) => c.$1), ['adapty_ui_open_url']);
    expect(transport.calls.single.$2, {'url': 'https://adapty.io', 'open_in': 'browser_out_app'});
  });

  for (final action in [
    {'type': 'close'},
    {'type': 'system_back'},
    {'type': 'custom', 'value': 'action-1'},
  ]) {
    testWidgets(
      '${action['type']} of an embedded flow without onDidPerformAction calls nothing on the native side when no '
      'observer is set',
      (tester) async {
        final (transport, viewId) = await _mount(tester);

        await _deliverAction(tester, transport, viewId, action);

        expect(transport.calls, isEmpty);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('an error of an embedded flow without onDidReceiveError does not dismiss it when no observer is set', (
    tester,
  ) async {
    final (transport, viewId) = await _mount(tester);

    await transport.deliver('flow_view_did_receive_error', {
      'view': _view(viewId),
      'error': {'adapty_code': 2002, 'message': 'something failed'},
    });
    await tester.runAsync(() => pumpEventQueue());

    expect(transport.calls, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}

final _isLink = isA<OpenUrlAction>()
    .having((action) => action.url, 'url', 'https://adapty.io')
    .having((action) => action.openIn, 'openIn', AdaptyWebPresentation.externalBrowser);

/// Installs a runtime on a fresh native side, sets [global] as the flows observer until the end of the test and shows
/// one flow widget with [onDidPerformAction]. Returns the native side and the id of the widget's view.
Future<(FakeTransport, String)> _mount(
  WidgetTester tester, {
  AdaptyUIFlowsEventsObserver? global,
  void Function(AdaptyUIFlowView, AdaptyUIAction)? onDidPerformAction,
}) async {
  final transport = FakeTransport();
  installTestRuntime(transport: transport, platform: _uiKit);
  if (global != null) {
    AdaptyUI().setFlowsEventsObserver(global);
    addTearDown(() => AdaptyUI().setFlowsEventsObserver(null));
  }
  final views = FakePlatformViews.install(tester);
  await tester.pumpWidget(_hosted(AdaptyUIFlowPlatformView(flow: _flow(), onDidPerformAction: onDidPerformAction)));
  return (transport, 'flutter_native_${_idsOf(views, _flowViewType).single}');
}

/// Delivers [action] of the view [viewId] and lets the calls it starts reach the native side.
Future<void> _deliverAction(
  WidgetTester tester,
  FakeTransport transport,
  String viewId,
  Map<String, dynamic> action,
) async {
  await transport.deliver('flow_view_did_perform_action', {'view': _view(viewId), 'action': action});
  await tester.runAsync(() => pumpEventQueue());
}

const _uiKit = TestPlatformInfo(isIOS: false, isAndroid: false, viewKind: AdaptyPlatformViewKind.uiKit, logTag: 'i');

/// The ids of the views of [viewType] created so far, in order.
List<int> _idsOf(FakePlatformViews views, String viewType) => [
  for (final view in views.created)
    if (view.viewType == viewType) view.id,
];

Widget _hosted(Widget view) => Directionality(textDirection: TextDirection.ltr, child: view);

Map<String, dynamic> _view(String id) => {'id': id, 'placement_id': 'placement-id', 'variation_id': 'variation-id'};

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
  'ui_schema': {
    'layouts': [
      {'flow_layout_id': 'flow-layout-id'},
    ],
    'grids': <dynamic>[],
  },
  'response_created_at': 0,
});

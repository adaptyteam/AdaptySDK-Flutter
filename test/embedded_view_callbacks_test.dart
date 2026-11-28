// ignore_for_file: deprecated_member_use_from_same_package
// Every event of the native view behind an embedded flow or onboarding widget reaches the matching callback of that
// widget, once, with what the event carried, and no other callback of it or of the widget next to it.
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_flow.dart';
import 'package:adapty_flutter/src/models/adapty_onboarding.dart' show AdaptyOnboardingJSONBuilder;
import 'package:adapty_flutter/src/runtime/adapty_platform_info.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_platform_views.dart';
import 'support/fake_transport.dart';
import 'support/test_platform_info.dart';
import 'support/test_runtime.dart';

const _flowViewType = 'adaptyui_flow_platform_view';
const _onboardingViewType = 'adaptyui_onboarding_platform_view';

/// Every callback call of every widget in the test, in order: the widget, the callback and what it got.
final _calls = <List<Object?>>[];

const _error = {'adapty_code': 2002, 'message': 'something failed'};
const _profile = {'profile_id': 'profile-1', 'segment_hash': 'segment-hash', 'timestamp': 1, 'is_test_user': false};
const _meta = {'onboarding_id': 'onboarding-id', 'screen_cid': 'screen-2', 'screen_index': 2, 'total_screens': 5};

const _product = {
  'vendor_product_id': 'com.app.yearly',
  'adapty_product_id': 'adapty-yearly',
  'access_level_id': 'premium',
  'product_type': 'annual',
  'paywall_product_index': 0,
  'paywall_variation_id': 'variation-id',
  'paywall_ab_test_name': 'ab-test',
  'paywall_name': 'Paywall',
  'localized_description': 'Premium for a year',
  'localized_title': 'Premium',
  'price': {'amount': 119.88, 'currency_code': 'EUR', 'currency_symbol': '€', 'localized_string': '119,88 €'},
};

/// One event of the native view: its wire name, its payload besides `view`, the callback it reaches and what that
/// callback gets besides the view.
typedef _Row = (String event, Map<String, dynamic> payload, String callback, List<Object?> got);

const _flowRows = <_Row>[
  ('flow_view_did_appear', {}, 'onDidAppear', []),
  ('flow_view_did_disappear', {}, 'onDidDisappear', []),
  (
    'flow_view_did_perform_action',
    {
      'action': {
        'type': 'custom',
        'value': 'action-1',
        'arguments': {'step': 'two'},
      },
    },
    'onDidPerformAction',
    [
      'action-1',
      {'step': 'two'},
    ],
  ),
  ('flow_view_did_select_product', {'product_id': 'product-1'}, 'onDidSelectProduct', ['product-1']),
  ('flow_view_did_start_purchase', {'product': _product}, 'onDidStartPurchase', ['com.app.yearly']),
  (
    'flow_view_did_finish_purchase',
    {
      'product': _product,
      'purchased_result': {'type': 'user_cancelled'},
    },
    'onDidFinishPurchase',
    ['com.app.yearly', AdaptyPurchaseResultUserCancelled],
  ),
  (
    'flow_view_did_fail_purchase',
    {'product': _product, 'error': _error},
    'onDidFailPurchase',
    ['com.app.yearly', 2002],
  ),
  ('flow_view_did_start_restore', {}, 'onDidStartRestore', []),
  ('flow_view_did_finish_restore', {'profile': _profile}, 'onDidFinishRestore', ['profile-1']),
  ('flow_view_did_fail_restore', {'error': _error}, 'onDidFailRestore', [2002]),
  ('flow_view_did_receive_error', {'error': _error}, 'onDidReceiveError', [2002]),
  ('flow_view_did_fail_loading_products', {'error': _error}, 'onDidFailLoadingProducts', [2002]),
  (
    'flow_view_did_finish_web_payment_navigation',
    {'product': _product, 'error': _error},
    'onDidFinishWebPaymentNavigation',
    ['com.app.yearly', 2002],
  ),
  (
    'flow_view_did_receive_analytic_event',
    {
      'name': 'analytic-1',
      'params': {'step': 3},
    },
    'onDidReceiveAnalyticEvent',
    [
      'analytic-1',
      {'step': 3},
    ],
  ),
];

const _onboardingRows = <_Row>[
  ('onboarding_did_finish_loading', {'meta': _meta}, 'onDidFinishLoading', ['onboarding-id', 2]),
  ('onboarding_did_fail_with_error', {'error': _error}, 'onDidFailWithError', [2002]),
  (
    'onboarding_on_close_action',
    {'meta': _meta, 'action_id': 'close-1'},
    'onCloseAction',
    ['onboarding-id', 2, 'close-1'],
  ),
  (
    'onboarding_on_paywall_action',
    {'meta': _meta, 'action_id': 'paywall-1'},
    'onPaywallAction',
    ['onboarding-id', 2, 'paywall-1'],
  ),
  (
    'onboarding_on_custom_action',
    {'meta': _meta, 'action_id': 'custom-1'},
    'onCustomAction',
    ['onboarding-id', 2, 'custom-1'],
  ),
  (
    'onboarding_on_state_updated_action',
    {
      'meta': _meta,
      'action': {
        'element_id': 'element-1',
        'element_type': 'select',
        'value': {'id': 'option-1', 'value': 'a', 'label': 'A'},
      },
    },
    'onStateUpdatedAction',
    ['onboarding-id', 2, 'element-1', 'option-1'],
  ),
  (
    'onboarding_on_analytics_action',
    {
      'meta': _meta,
      'event': {'name': 'onboarding_started'},
    },
    'onAnalyticsEvent',
    ['onboarding-id', 2, AdaptyOnboardingsAnalyticsEventOnboardingStarted],
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_calls.clear);

  for (final (event, payload, callback, got) in _flowRows) {
    testWidgets('$event reaches $callback of its flow widget once, with what it carried', (tester) async {
      final transport = FakeTransport();
      installTestRuntime(transport: transport, platform: _uiKit);
      final views = FakePlatformViews.install(tester);
      await tester.pumpWidget(_hostedPair(_flowView('first'), _flowView('second')));
      final [_, id] = _idsOf(views, _flowViewType);

      await transport.deliver(event, {'view': _view('flutter_native_$id'), ...payload});

      expect(_calls, [
        ['second', callback, 'flutter_native_$id', ...got],
      ]);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final (event, payload, callback, got) in _onboardingRows) {
    testWidgets('$event reaches $callback of its onboarding widget once, with what it carried', (tester) async {
      final transport = FakeTransport();
      installTestRuntime(transport: transport, platform: _uiKit);
      final views = FakePlatformViews.install(tester);
      await tester.pumpWidget(_hostedPair(_onboardingView('first'), _onboardingView('second')));
      final [_, id] = _idsOf(views, _onboardingViewType);

      await transport.deliver(event, {'view': _view('flutter_native_$id'), ...payload});

      expect(_calls, [
        ['second', callback, ...got],
      ]);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

/// A flow widget with every callback set; each one records its call under [tag].
AdaptyUIFlowPlatformView _flowView(String tag) => AdaptyUIFlowPlatformView(
  flow: _flow(),
  onDidAppear: (view) => _calls.add([tag, 'onDidAppear', view.id]),
  onDidDisappear: (view) => _calls.add([tag, 'onDidDisappear', view.id]),
  onDidPerformAction: (view, action) => _calls.add([
    tag,
    'onDidPerformAction',
    view.id,
    if (action is CustomAction) ...[action.action, action.arguments] else action,
  ]),
  onDidSelectProduct: (view, productId) => _calls.add([tag, 'onDidSelectProduct', view.id, productId]),
  onDidStartPurchase: (view, product) => _calls.add([tag, 'onDidStartPurchase', view.id, product.vendorProductId]),
  onDidFinishPurchase: (view, product, result) =>
      _calls.add([tag, 'onDidFinishPurchase', view.id, product.vendorProductId, result.runtimeType]),
  onDidFailPurchase: (view, product, error) =>
      _calls.add([tag, 'onDidFailPurchase', view.id, product.vendorProductId, error.code]),
  onDidStartRestore: (view) => _calls.add([tag, 'onDidStartRestore', view.id]),
  onDidFinishRestore: (view, profile) => _calls.add([tag, 'onDidFinishRestore', view.id, profile.profileId]),
  onDidFailRestore: (view, error) => _calls.add([tag, 'onDidFailRestore', view.id, error.code]),
  onDidReceiveError: (view, error) => _calls.add([tag, 'onDidReceiveError', view.id, error.code]),
  onDidFailLoadingProducts: (view, error) => _calls.add([tag, 'onDidFailLoadingProducts', view.id, error.code]),
  onDidFinishWebPaymentNavigation: (view, product, error) =>
      _calls.add([tag, 'onDidFinishWebPaymentNavigation', view.id, product?.vendorProductId, error?.code]),
  onDidReceiveAnalyticEvent: (view, name, params) =>
      _calls.add([tag, 'onDidReceiveAnalyticEvent', view.id, name, params]),
);

/// An onboarding widget with every callback set; each one records its call under [tag].
AdaptyUIOnboardingPlatformView _onboardingView(String tag) => AdaptyUIOnboardingPlatformView(
  onboarding: _onboarding(),
  onDidFinishLoading: (meta) => _calls.add([tag, 'onDidFinishLoading', meta.onboardingId, meta.screenIndex]),
  onDidFailWithError: (error) => _calls.add([tag, 'onDidFailWithError', error.code]),
  onCloseAction: (meta, actionId) => _calls.add([tag, 'onCloseAction', meta.onboardingId, meta.screenIndex, actionId]),
  onPaywallAction: (meta, actionId) =>
      _calls.add([tag, 'onPaywallAction', meta.onboardingId, meta.screenIndex, actionId]),
  onCustomAction: (meta, actionId) =>
      _calls.add([tag, 'onCustomAction', meta.onboardingId, meta.screenIndex, actionId]),
  onStateUpdatedAction: (meta, elementId, params) => _calls.add([
    tag,
    'onStateUpdatedAction',
    meta.onboardingId,
    meta.screenIndex,
    elementId,
    params is AdaptyOnboardingsSelectParams ? params.id : params,
  ]),
  onAnalyticsEvent: (meta, event) =>
      _calls.add([tag, 'onAnalyticsEvent', meta.onboardingId, meta.screenIndex, event.runtimeType]),
);

const _uiKit = TestPlatformInfo(isIOS: false, isAndroid: false, viewKind: AdaptyPlatformViewKind.uiKit, logTag: 'i');

/// The ids of the views of [viewType] created so far, in order.
List<int> _idsOf(FakePlatformViews views, String viewType) => [
  for (final view in views.created)
    if (view.viewType == viewType) view.id,
];

Widget _hostedPair(Widget first, Widget second) => Directionality(
  textDirection: TextDirection.ltr,
  child: Column(
    children: [
      Expanded(child: first),
      Expanded(child: second),
    ],
  ),
);

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

AdaptyOnboarding _onboarding() => AdaptyOnboardingJSONBuilder.fromJsonValue({
  'placement': {
    'developer_id': 'placement-id',
    'audience_name': 'Audience',
    'revision': 1,
    'ab_test_name': 'Experiment',
    'placement_audience_version_id': 'placement-audience-version-id',
  },
  'onboarding_id': 'onboarding-id',
  'onboarding_name': 'Onboarding',
  'variation_id': 'variation-id',
  'response_created_at': 0,
  'onboarding_builder': {'config_url': 'https://example.com/config'},
  'request_locale': 'en',
});

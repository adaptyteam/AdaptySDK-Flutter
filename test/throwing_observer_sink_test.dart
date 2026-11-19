// ignore_for_file: deprecated_member_use
/// What the SDK reports when an observer of flow or onboarding events throws: one `observerThrew` record per throw,
/// with the wire name of the event the observer was handling.
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/runtime/adapty_internal_error_sink.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/collecting_error_sink.dart';
import 'support/fake_transport.dart';
import 'support/test_runtime.dart';

Never _boom() => throw StateError('observer boom');

/// Throws on every event.
class _ThrowingFlowObserver extends AdaptyUIFlowsEventsObserver {
  @override
  void flowViewDidAppear(AdaptyUIFlowView view) => _boom();

  @override
  void flowViewDidDisappear(AdaptyUIFlowView view) => _boom();

  @override
  void flowViewDidPerformAction(AdaptyUIFlowView view, AdaptyUIAction action) => _boom();

  @override
  void flowViewDidSelectProduct(AdaptyUIFlowView view, String productId) => _boom();

  @override
  void flowViewDidStartPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product) => _boom();

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) => _boom();

  @override
  void flowViewDidFailPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product, AdaptyError error) => _boom();

  @override
  void flowViewDidStartRestore(AdaptyUIFlowView view) => _boom();

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) => _boom();

  @override
  void flowViewDidFailRestore(AdaptyUIFlowView view, AdaptyError error) => _boom();

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) => _boom();

  @override
  void flowViewDidFailLoadingProducts(AdaptyUIFlowView view, AdaptyError error) => _boom();

  @override
  void flowViewDidFinishWebPaymentNavigation(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) => _boom();

  @override
  void flowViewDidReceiveAnalyticEvent(AdaptyUIFlowView view, String name, Map<String, dynamic> params) => _boom();
}

/// Throws on every event.
class _ThrowingOnboardingObserver extends AdaptyUIOnboardingsEventsObserver {
  @override
  void onboardingViewDidFinishLoading(AdaptyUIOnboardingView view, AdaptyUIOnboardingMeta meta) => _boom();

  @override
  void onboardingViewDidFailWithError(AdaptyUIOnboardingView view, AdaptyError error) => _boom();

  @override
  void onboardingViewOnCloseAction(AdaptyUIOnboardingView view, AdaptyUIOnboardingMeta meta, String actionId) =>
      _boom();

  @override
  void onboardingViewOnPaywallAction(AdaptyUIOnboardingView view, AdaptyUIOnboardingMeta meta, String actionId) =>
      _boom();

  @override
  void onboardingViewOnCustomAction(AdaptyUIOnboardingView view, AdaptyUIOnboardingMeta meta, String actionId) =>
      _boom();

  @override
  void onboardingViewOnStateUpdatedAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String elementId,
    AdaptyOnboardingsStateUpdatedParams params,
  ) => _boom();

  @override
  void onboardingViewOnAnalyticsEvent(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    AdaptyOnboardingsAnalyticsEvent event,
  ) => _boom();
}

const _view = {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'};
const _embeddedView = {'id': 'flutter_native_7', 'placement_id': 'placement-id', 'variation_id': 'variation-id'};
const _meta = {'onboarding_id': 'onboarding-id', 'screen_cid': 'screen-1', 'screen_index': 2, 'total_screens': 5};
const _error = {'adapty_code': 2002, 'message': 'something failed'};
const _profile = {'profile_id': 'profile-1', 'segment_hash': 'segment-hash', 'timestamp': 1, 'is_test_user': false};

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

/// Every event an observer handles: a name for the case, the event the native side sends, and its payload.
const _cases = <(String, String, Map<String, dynamic>)>[
  ('flow_view_did_appear', 'flow_view_did_appear', {'view': _view}),
  ('flow_view_did_disappear', 'flow_view_did_disappear', {'view': _view}),
  (
    'flow_view_did_perform_action',
    'flow_view_did_perform_action',
    {
      'view': _view,
      'action': {'type': 'custom', 'value': 'action-1'},
    },
  ),
  ('flow_view_did_select_product', 'flow_view_did_select_product', {'view': _view, 'product_id': 'product-1'}),
  ('flow_view_did_start_purchase', 'flow_view_did_start_purchase', {'view': _view, 'product': _product}),
  (
    'flow_view_did_finish_purchase',
    'flow_view_did_finish_purchase',
    {
      'view': _view,
      'product': _product,
      'purchased_result': {'type': 'user_cancelled'},
    },
  ),
  ('flow_view_did_fail_purchase', 'flow_view_did_fail_purchase', {'view': _view, 'product': _product, 'error': _error}),
  ('flow_view_did_start_restore', 'flow_view_did_start_restore', {'view': _view}),
  ('flow_view_did_finish_restore', 'flow_view_did_finish_restore', {'view': _view, 'profile': _profile}),
  ('flow_view_did_fail_restore', 'flow_view_did_fail_restore', {'view': _view, 'error': _error}),
  ('flow_view_did_receive_error', 'flow_view_did_receive_error', {'view': _view, 'error': _error}),
  (
    'flow_view_did_receive_error of an embedded view nobody listens to',
    'flow_view_did_receive_error',
    {'view': _embeddedView, 'error': _error},
  ),
  ('flow_view_did_fail_loading_products', 'flow_view_did_fail_loading_products', {'view': _view, 'error': _error}),
  (
    'flow_view_did_finish_web_payment_navigation',
    'flow_view_did_finish_web_payment_navigation',
    {'view': _view, 'product': _product, 'error': _error},
  ),
  (
    'flow_view_did_receive_analytic_event',
    'flow_view_did_receive_analytic_event',
    {
      'view': _view,
      'name': 'analytic-1',
      'params': {'step': 3},
    },
  ),
  ('onboarding_did_finish_loading', 'onboarding_did_finish_loading', {'view': _view, 'meta': _meta}),
  ('onboarding_did_fail_with_error', 'onboarding_did_fail_with_error', {'view': _view, 'error': _error}),
  (
    'onboarding_on_analytics_action',
    'onboarding_on_analytics_action',
    {
      'view': _view,
      'meta': _meta,
      'event': {'name': 'onboarding_started'},
    },
  ),
  ('onboarding_on_close_action', 'onboarding_on_close_action', {'view': _view, 'meta': _meta, 'action_id': 'close-1'}),
  (
    'onboarding_on_custom_action',
    'onboarding_on_custom_action',
    {'view': _view, 'meta': _meta, 'action_id': 'custom-1'},
  ),
  (
    'onboarding_on_paywall_action',
    'onboarding_on_paywall_action',
    {'view': _view, 'meta': _meta, 'action_id': 'paywall-1'},
  ),
  (
    'onboarding_on_state_updated_action',
    'onboarding_on_state_updated_action',
    {
      'view': _view,
      'meta': _meta,
      'action': {
        'element_id': 'element-1',
        'element_type': 'select',
        'value': {'id': 'option-1', 'value': 'a', 'label': 'A'},
      },
    },
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (name, event, payload) in _cases) {
    test('a throwing observer is reported with the wire name of its event: $name', () async {
      final sink = CollectingErrorSink();
      final fake = FakeTransport();
      installTestRuntime(transport: fake, errorSink: sink);
      AdaptyUI().setFlowsEventsObserver(_ThrowingFlowObserver());
      AdaptyUI().setOnboardingsEventsObserver(_ThrowingOnboardingObserver());

      final reply = await fake.deliver(event, payload);

      expect(reply, isNull);
      expect(sink.records, hasLength(1));
      final record = sink.records.single;
      expect(record.kind, AdaptyInternalErrorKind.observerThrew);
      expect(record.context, event);
      expect(record.error, isA<StateError>().having((e) => e.message, 'message', 'observer boom'));
    });
  }
}

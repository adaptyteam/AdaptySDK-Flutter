// ignore_for_file: deprecated_member_use
/// What the SDK reports when an observer of flow or onboarding events throws: one `observerThrew` record per throw,
/// with the wire name of the event the observer was handling. The event still reaches the observers after the one that
/// threw.
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adaptyui/adaptyui_flow_view.dart' show AdaptyUIFlowViewJSONBuilder;
import 'package:adapty_flutter/src/runtime/adapty_internal_error_sink.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/capturing_log_sink.dart';
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

/// Every event the [_RecordingFlowObserver]s received, in order: who received it and for which view.
final _delivered = <(String, String)>[];

/// Records [flowViewDidAppear] and [flowViewDidReceiveError] in [_delivered] under [name], then throws if [throwing].
class _RecordingFlowObserver extends AdaptyUIFlowsEventsObserver {
  _RecordingFlowObserver(this.name, {this.throwing = false});

  final String name;
  final bool throwing;

  void _record(AdaptyUIFlowView view) {
    _delivered.add((name, view.id));
    if (throwing) _boom();
  }

  @override
  void flowViewDidAppear(AdaptyUIFlowView view) => _record(view);

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) {}

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) => _record(view);
}

/// Records [flowViewDidAppear] in [_delivered] under [name], calls [onAppear], then throws `boom from <name>`.
class _ThrowingAppearObserver extends AdaptyUIFlowsEventsObserver {
  _ThrowingAppearObserver(this.name, {this.onAppear});

  final String name;
  final void Function()? onAppear;

  @override
  void flowViewDidAppear(AdaptyUIFlowView view) {
    _delivered.add((name, view.id));
    onAppear?.call();
    throw StateError('boom from $name');
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

  setUp(_delivered.clear);

  test('a throwing observer does not keep the event from the global observer and is reported once', () async {
    final sink = CollectingErrorSink();
    final fake = FakeTransport();
    installTestRuntime(transport: fake, errorSink: sink);
    AdaptyUI().registerFlowEventsListener(_RecordingFlowObserver('widget', throwing: true), 'flutter_native_1');
    addTearDown(() => AdaptyUI().unregisterFlowEventsListener('flutter_native_1'));
    AdaptyUI().setFlowsEventsObserver(_RecordingFlowObserver('global'));

    final reply = await fake.deliver('flow_view_did_appear', {
      'view': {'id': 'flutter_native_1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
    });

    expect(reply, isNull);
    expect(_delivered, [('widget', 'flutter_native_1'), ('global', 'flutter_native_1')]);
    expect(sink.records, hasLength(1));
    final record = sink.records.single;
    expect(record.kind, AdaptyInternalErrorKind.observerThrew);
    expect(record.context, 'flow_view_did_appear');
    expect(record.error, isA<StateError>().having((e) => e.message, 'message', 'observer boom'));
  });

  test('every observer that throws is reported', () async {
    final sink = CollectingErrorSink();
    final fake = FakeTransport();
    installTestRuntime(transport: fake, errorSink: sink);
    int? recordsWhenGlobalCalled;
    AdaptyUI().registerFlowEventsListener(_ThrowingAppearObserver('widget'), 'flutter_native_1');
    addTearDown(() => AdaptyUI().unregisterFlowEventsListener('flutter_native_1'));
    AdaptyUI().setFlowsEventsObserver(
      _ThrowingAppearObserver('global', onAppear: () => recordsWhenGlobalCalled = sink.records.length),
    );

    final reply = await fake.deliver('flow_view_did_appear', {
      'view': {'id': 'flutter_native_1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
    });

    expect(reply, isNull);
    expect(_delivered, [('widget', 'flutter_native_1'), ('global', 'flutter_native_1')]);
    expect(recordsWhenGlobalCalled, 1, reason: 'the throw of the widget is reported before the global observer runs');
    expect(sink.records.map((record) => (record.kind, record.context, '${record.error}')), [
      (AdaptyInternalErrorKind.observerThrew, 'flow_view_did_appear', 'Bad state: boom from widget'),
      (AdaptyInternalErrorKind.observerThrew, 'flow_view_did_appear', 'Bad state: boom from global'),
    ]);
  });

  test('a throwing observer is logged as a single error line', () async {
    final logSink = CapturingLogSink();
    final fake = FakeTransport();
    installTestRuntime(transport: fake, logSink: logSink);
    AdaptyUI().registerFlowEventsListener(_RecordingFlowObserver('widget', throwing: true), 'flutter_native_1');
    addTearDown(() => AdaptyUI().unregisterFlowEventsListener('flutter_native_1'));
    AdaptyUI().setFlowsEventsObserver(_RecordingFlowObserver('global'));

    await fake.deliver('flow_view_did_appear', {
      'view': {'id': 'flutter_native_1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
    });

    expect(logSink.lines, [
      (AdaptyLogLevel.error, 'Error in Adapty._handleIncomingMethodCall: Bad state: observer boom'),
    ]);
  });

  test('a throwing observer is reported to the sink of the runtime it belongs to', () {
    final sinkA = CollectingErrorSink();
    final a = installTestRuntime(errorSink: sinkA);
    AdaptyUI().setFlowsEventsObserver(_RecordingFlowObserver('global', throwing: true));
    final sinkB = CollectingErrorSink();
    installTestRuntime(errorSink: sinkB);

    // The event reaches the observers of runtime A while another runtime is current.
    expect(() => a.ui.eventsProxy.flowViewDidAppear(AdaptyUIFlowViewJSONBuilder.fromJsonValue(_view)), returnsNormally);

    expect(sinkA.records.map((record) => record.kind), [AdaptyInternalErrorKind.observerThrew]);
    expect(sinkB.records, isEmpty);
  });

  test(
    'a global observer that throws on an early embedded view error is reported and the error stays buffered',
    () async {
      final sink = CollectingErrorSink();
      final fake = FakeTransport();
      installTestRuntime(transport: fake, errorSink: sink);
      AdaptyUI().setFlowsEventsObserver(_RecordingFlowObserver('global', throwing: true));
      addTearDown(() => AdaptyUI().unregisterFlowEventsListener('flutter_native_3'));

      await fake.deliver('flow_view_did_receive_error', {
        'view': {'id': 'flutter_native_3', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
        'error': _error,
      });

      expect(sink.records.map((record) => (record.kind, record.context)), [
        (AdaptyInternalErrorKind.observerThrew, 'flow_view_did_receive_error'),
      ]);

      AdaptyUI().registerFlowEventsListener(_RecordingFlowObserver('widget'), 'flutter_native_3');

      expect(_delivered, [('global', 'flutter_native_3'), ('widget', 'flutter_native_3')]);
      expect(sink.records, hasLength(1));
    },
  );

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

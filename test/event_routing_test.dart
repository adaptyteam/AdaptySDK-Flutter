// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

/// Every delivery the SDK makes to the app, in order: observer methods, the system requests
/// handler, the observer mode resolver and the streams of [Adapty].
final _log = <List<Object?>>[];

/// The callbacks the resolver received. The resolver itself never calls them.
final _resolverCallbacks = <void Function()>[];

class _FlowObserver extends AdaptyUIFlowsEventsObserver {
  @override
  void flowViewDidAppear(AdaptyUIFlowView view) => _log.add(['flowViewDidAppear', view.id]);

  @override
  void flowViewDidDisappear(AdaptyUIFlowView view) => _log.add(['flowViewDidDisappear', view.id]);

  @override
  void flowViewDidPerformAction(AdaptyUIFlowView view, AdaptyUIAction action) =>
      _log.add(['flowViewDidPerformAction', view.id, action is CustomAction ? action.action : action]);

  @override
  void flowViewDidSelectProduct(AdaptyUIFlowView view, String productId) =>
      _log.add(['flowViewDidSelectProduct', view.id, productId]);

  @override
  void flowViewDidStartPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product) =>
      _log.add(['flowViewDidStartPurchase', view.id, product.vendorProductId]);

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) => _log.add(['flowViewDidFinishPurchase', view.id, product.vendorProductId, purchaseResult.runtimeType]);

  @override
  void flowViewDidFailPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product, AdaptyError error) =>
      _log.add(['flowViewDidFailPurchase', view.id, product.vendorProductId, error.code]);

  @override
  void flowViewDidStartRestore(AdaptyUIFlowView view) => _log.add(['flowViewDidStartRestore', view.id]);

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) =>
      _log.add(['flowViewDidFinishRestore', view.id, profile.profileId]);

  @override
  void flowViewDidFailRestore(AdaptyUIFlowView view, AdaptyError error) =>
      _log.add(['flowViewDidFailRestore', view.id, error.code]);

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) =>
      _log.add(['flowViewDidReceiveError', view.id, error.code]);

  @override
  void flowViewDidFailLoadingProducts(AdaptyUIFlowView view, AdaptyError error) =>
      _log.add(['flowViewDidFailLoadingProducts', view.id, error.code]);

  @override
  void flowViewDidFinishWebPaymentNavigation(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) => _log.add(['flowViewDidFinishWebPaymentNavigation', view.id, product?.vendorProductId, error?.code]);

  @override
  void flowViewDidReceiveAnalyticEvent(AdaptyUIFlowView view, String name, Map<String, dynamic> params) =>
      _log.add(['flowViewDidReceiveAnalyticEvent', view.id, name, params]);
}

class _OnboardingObserver extends AdaptyUIOnboardingsEventsObserver {
  @override
  void onboardingViewDidFinishLoading(AdaptyUIOnboardingView view, AdaptyUIOnboardingMeta meta) =>
      _log.add(['onboardingViewDidFinishLoading', view.id, meta.onboardingId, meta.screenIndex]);

  @override
  void onboardingViewDidFailWithError(AdaptyUIOnboardingView view, AdaptyError error) =>
      _log.add(['onboardingViewDidFailWithError', view.id, error.code]);

  @override
  void onboardingViewOnCloseAction(AdaptyUIOnboardingView view, AdaptyUIOnboardingMeta meta, String actionId) =>
      _log.add(['onboardingViewOnCloseAction', view.id, meta.onboardingId, actionId]);

  @override
  void onboardingViewOnPaywallAction(AdaptyUIOnboardingView view, AdaptyUIOnboardingMeta meta, String actionId) =>
      _log.add(['onboardingViewOnPaywallAction', view.id, meta.onboardingId, actionId]);

  @override
  void onboardingViewOnCustomAction(AdaptyUIOnboardingView view, AdaptyUIOnboardingMeta meta, String actionId) =>
      _log.add(['onboardingViewOnCustomAction', view.id, meta.onboardingId, actionId]);

  @override
  void onboardingViewOnStateUpdatedAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String elementId,
    AdaptyOnboardingsStateUpdatedParams params,
  ) => _log.add([
    'onboardingViewOnStateUpdatedAction',
    view.id,
    meta.onboardingId,
    elementId,
    params is AdaptyOnboardingsSelectParams ? params.id : params,
  ]);

  @override
  void onboardingViewOnAnalyticsEvent(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    AdaptyOnboardingsAnalyticsEvent event,
  ) => _log.add(['onboardingViewOnAnalyticsEvent', view.id, meta.onboardingId, event.runtimeType]);
}

class _Handler extends AdaptyUISystemRequestsHandler {
  @override
  Future<AdaptyUIPermissionResult> handlePermission(
    AdaptyUIFlowView view,
    AdaptyUIPermission permission,
    Map<String, String>? customArgs,
  ) async {
    _log.add(['handlePermission', view.id, permission.value, customArgs]);
    return const AdaptyUIPermissionResult.granted();
  }

  @override
  Future<void> handleAppReviewRequest(AdaptyUIFlowView view) async => _log.add(['handleAppReviewRequest', view.id]);
}

class _Resolver extends AdaptyUIObserverModeResolver {
  @override
  void observerModeDidInitiatePurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    void Function() onStartPurchase,
    void Function() onFinishPurchase,
  ) {
    _log.add(['observerModeDidInitiatePurchase', view.id, product.vendorProductId]);
    _resolverCallbacks.addAll([onStartPurchase, onFinishPurchase]);
  }

  @override
  void observerModeDidInitiateRestore(
    AdaptyUIFlowView view,
    void Function() onStartRestore,
    void Function() onFinishRestore,
  ) {
    _log.add(['observerModeDidInitiateRestore', view.id]);
    _resolverCallbacks.addAll([onStartRestore, onFinishRestore]);
  }
}

const _view = {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'};
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

const _promotedProduct = {
  'vendor_product_id': 'promoted.product',
  'localized_description': 'Promoted product',
  'localized_title': 'Promoted',
  'price': {'amount': 9.99, 'currency_code': 'USD', 'currency_symbol': r'$', 'localized_string': r'$9.99'},
};

/// One bridge event: what the native side sends and what the app and the native side get.
class _Route {
  const _Route(this.event, this.payload, {required this.delivered, this.sent = const []});

  final String event;
  final Map<String, dynamic> payload;

  /// The expected [_log].
  final List<List<Object?>> delivered;

  /// The expected calls to the native side, as method name and decoded arguments.
  final List<List<Object>> sent;
}

const _routes = [
  _Route(
    'flow_view_did_appear',
    {'view': _view},
    delivered: [
      ['flowViewDidAppear', 'view-1'],
    ],
  ),
  _Route(
    'flow_view_did_disappear',
    {'view': _view},
    delivered: [
      ['flowViewDidDisappear', 'view-1'],
    ],
  ),
  _Route(
    'flow_view_did_perform_action',
    {
      'view': _view,
      'action': {'type': 'custom', 'value': 'action-1'},
    },
    delivered: [
      ['flowViewDidPerformAction', 'view-1', 'action-1'],
    ],
  ),
  _Route(
    'flow_view_did_select_product',
    {'view': _view, 'product_id': 'product-1'},
    delivered: [
      ['flowViewDidSelectProduct', 'view-1', 'product-1'],
    ],
  ),
  _Route(
    'flow_view_did_start_purchase',
    {'view': _view, 'product': _product},
    delivered: [
      ['flowViewDidStartPurchase', 'view-1', 'com.app.yearly'],
    ],
  ),
  _Route(
    'flow_view_did_finish_purchase',
    {
      'view': _view,
      'product': _product,
      'purchased_result': {'type': 'user_cancelled'},
    },
    delivered: [
      ['flowViewDidFinishPurchase', 'view-1', 'com.app.yearly', AdaptyPurchaseResultUserCancelled],
    ],
  ),
  _Route(
    'flow_view_did_fail_purchase',
    {'view': _view, 'product': _product, 'error': _error},
    delivered: [
      ['flowViewDidFailPurchase', 'view-1', 'com.app.yearly', 2002],
    ],
  ),
  _Route(
    'flow_view_did_start_restore',
    {'view': _view},
    delivered: [
      ['flowViewDidStartRestore', 'view-1'],
    ],
  ),
  _Route(
    'flow_view_did_finish_restore',
    {'view': _view, 'profile': _profile},
    delivered: [
      ['flowViewDidFinishRestore', 'view-1', 'profile-1'],
    ],
  ),
  _Route(
    'flow_view_did_fail_restore',
    {'view': _view, 'error': _error},
    delivered: [
      ['flowViewDidFailRestore', 'view-1', 2002],
    ],
  ),
  _Route(
    'flow_view_did_receive_error',
    {'view': _view, 'error': _error},
    delivered: [
      ['flowViewDidReceiveError', 'view-1', 2002],
    ],
  ),
  _Route(
    'flow_view_did_fail_loading_products',
    {'view': _view, 'error': _error},
    delivered: [
      ['flowViewDidFailLoadingProducts', 'view-1', 2002],
    ],
  ),
  _Route(
    'flow_view_did_finish_web_payment_navigation',
    {'view': _view, 'product': _product, 'error': _error},
    delivered: [
      ['flowViewDidFinishWebPaymentNavigation', 'view-1', 'com.app.yearly', 2002],
    ],
  ),
  _Route(
    'flow_view_did_ask_permission',
    {
      'event_id': 'hr_1',
      'view': _view,
      'permission': 'camera',
      'custom_args': {'reason': 'scan'},
    },
    delivered: [
      [
        'handlePermission',
        'view-1',
        'camera',
        {'reason': 'scan'},
      ],
    ],
    sent: [
      [
        'flow_view_did_answer_permission',
        {'event_id': 'hr_1', 'status': 'granted'},
      ],
    ],
  ),
  _Route(
    'flow_view_did_request_app_review',
    {'view': _view},
    delivered: [
      ['handleAppReviewRequest', 'view-1'],
    ],
  ),
  _Route(
    'flow_view_did_receive_analytic_event',
    {
      'view': _view,
      'name': 'analytic-1',
      'params': {'step': 3},
    },
    delivered: [
      [
        'flowViewDidReceiveAnalyticEvent',
        'view-1',
        'analytic-1',
        {'step': 3},
      ],
    ],
  ),
  _Route(
    'flow_view_observer_did_initiate_purchase',
    {'event_id': 'e1', 'view': _view, 'product': _product},
    delivered: [
      ['observerModeDidInitiatePurchase', 'view-1', 'com.app.yearly'],
    ],
    sent: [
      [
        'observer_purchase_did_start',
        {'event_id': 'e1'},
      ],
      [
        'observer_purchase_did_finish',
        {'event_id': 'e1'},
      ],
    ],
  ),
  _Route(
    'flow_view_observer_did_initiate_restore',
    {'event_id': 'e2', 'view': _view},
    delivered: [
      ['observerModeDidInitiateRestore', 'view-1'],
    ],
    sent: [
      [
        'observer_restore_did_start',
        {'event_id': 'e2'},
      ],
      [
        'observer_restore_did_finish',
        {'event_id': 'e2'},
      ],
    ],
  ),
  _Route(
    'onboarding_did_finish_loading',
    {'view': _view, 'meta': _meta},
    delivered: [
      ['onboardingViewDidFinishLoading', 'view-1', 'onboarding-id', 2],
    ],
  ),
  _Route(
    'onboarding_did_fail_with_error',
    {'view': _view, 'error': _error},
    delivered: [
      ['onboardingViewDidFailWithError', 'view-1', 2002],
    ],
  ),
  _Route(
    'onboarding_on_analytics_action',
    {
      'view': _view,
      'meta': _meta,
      'event': {'name': 'onboarding_started'},
    },
    delivered: [
      ['onboardingViewOnAnalyticsEvent', 'view-1', 'onboarding-id', AdaptyOnboardingsAnalyticsEventOnboardingStarted],
    ],
  ),
  _Route(
    'onboarding_on_close_action',
    {'view': _view, 'meta': _meta, 'action_id': 'close-1'},
    delivered: [
      ['onboardingViewOnCloseAction', 'view-1', 'onboarding-id', 'close-1'],
    ],
  ),
  _Route(
    'onboarding_on_custom_action',
    {'view': _view, 'meta': _meta, 'action_id': 'custom-1'},
    delivered: [
      ['onboardingViewOnCustomAction', 'view-1', 'onboarding-id', 'custom-1'],
    ],
  ),
  _Route(
    'onboarding_on_paywall_action',
    {'view': _view, 'meta': _meta, 'action_id': 'paywall-1'},
    delivered: [
      ['onboardingViewOnPaywallAction', 'view-1', 'onboarding-id', 'paywall-1'],
    ],
  ),
  _Route(
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
    delivered: [
      ['onboardingViewOnStateUpdatedAction', 'view-1', 'onboarding-id', 'element-1', 'option-1'],
    ],
  ),
  _Route(
    'did_load_latest_profile',
    {'profile': _profile},
    delivered: [
      ['didUpdateProfileStream', 'profile-1'],
    ],
  ),
  _Route(
    'did_receive_promoted_purchase',
    {'product': _promotedProduct},
    delivered: [
      ['didReceivePromotedPurchaseStream', 'promoted.product'],
    ],
  ),
  _Route(
    'on_installation_details_success',
    {
      'details': {
        'install_id': 'install-1',
        'install_time': '2026-08-24T09:34:24.727Z',
        'app_launch_count': 4,
        'payload': 'payload-1',
      },
    },
    delivered: [
      ['onUpdateInstallationDetailsSuccessStream', 'install-1', 4],
    ],
  ),
  _Route(
    'on_installation_details_fail',
    {'error': _error},
    delivered: [
      ['onUpdateInstallationDetailsFailStream', 2002],
    ],
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  final subscriptions = <StreamSubscription<Object>>[];

  setUp(() {
    _log.clear();
    _resolverCallbacks.clear();
    calls.clear();
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return jsonEncode({'success': null});
    });
    AdaptyUI().setFlowsEventsObserver(_FlowObserver());
    AdaptyUI().setOnboardingsEventsObserver(_OnboardingObserver());
    AdaptyUI().setSystemRequestsHandler(_Handler());
    AdaptyUI().setObserverModeResolver(_Resolver());
    subscriptions.addAll([
      Adapty().didUpdateProfileStream.listen((profile) => _log.add(['didUpdateProfileStream', profile.profileId])),
      Adapty().didReceivePromotedPurchaseStream.listen(
        (product) => _log.add(['didReceivePromotedPurchaseStream', product.vendorProductId]),
      ),
      Adapty().onUpdateInstallationDetailsSuccessStream.listen(
        (details) => _log.add(['onUpdateInstallationDetailsSuccessStream', details.installId, details.appLaunchCount]),
      ),
      Adapty().onUpdateInstallationDetailsFailStream.listen(
        (error) => _log.add(['onUpdateInstallationDetailsFailStream', error.code]),
      ),
    ]);
  });

  tearDown(() async {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    subscriptions.clear();
    AdaptyUI().setFlowsEventsObserver(null);
    AdaptyUI().setOnboardingsEventsObserver(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  for (final route in _routes) {
    test('routes ${route.event}', () async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        _channel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(route.event, jsonEncode(route.payload))),
        (_) {},
      );
      await pumpEventQueue();
      for (final callback in _resolverCallbacks) {
        callback();
      }
      await pumpEventQueue();

      expect(_log, route.delivered);
      expect(calls.map((call) => [call.method, jsonDecode(call.arguments as String)]).toList(), route.sent);
    });
  }
}

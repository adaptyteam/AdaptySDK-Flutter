// Where every event of the native side goes: the observers, the system requests handler, the observer mode resolver
// and the streams of the SDK, and what the SDK answers to the native side. Each event is the case the bridge contract
// corpus has for it (contract/events/<event>/default), sent over the real adapty channel to the event handler the SDK
// installs; the contract native of the platform takes the answers. An event whose case differs between the platforms
// goes once on each.
// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/contract/src/contract_schema.dart';
import '../tool/contract/src/corpus.dart';
import 'support/contract/contract_native.dart';
import 'support/native_wire_names.dart';

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

/// One bridge event: what the app and the native side get from the case of the corpus the native side sends.
class _Route {
  const _Route(this.event, {required this.delivered, this.sent = const []});

  final String event;

  /// The expected [_log].
  final List<List<Object?>> delivered;

  /// The expected calls to the native side, as method name and decoded arguments.
  final List<List<Object>> sent;
}

const _routes = [
  _Route(
    'flow_view_did_appear',
    delivered: [
      ['flowViewDidAppear', 'view-1'],
    ],
  ),
  _Route(
    'flow_view_did_disappear',
    delivered: [
      ['flowViewDidDisappear', 'view-1'],
    ],
  ),
  _Route(
    'flow_view_did_perform_action',
    delivered: [
      ['flowViewDidPerformAction', 'view-1', 'action-1'],
    ],
  ),
  _Route(
    'flow_view_did_select_product',
    delivered: [
      ['flowViewDidSelectProduct', 'view-1', 'product-1'],
    ],
  ),
  _Route(
    'flow_view_did_start_purchase',
    delivered: [
      ['flowViewDidStartPurchase', 'view-1', 'com.app.yearly'],
    ],
  ),
  _Route(
    'flow_view_did_finish_purchase',
    delivered: [
      ['flowViewDidFinishPurchase', 'view-1', 'com.app.yearly', AdaptyPurchaseResultUserCancelled],
    ],
  ),
  _Route(
    'flow_view_did_fail_purchase',
    delivered: [
      ['flowViewDidFailPurchase', 'view-1', 'com.app.yearly', 2002],
    ],
  ),
  _Route(
    'flow_view_did_start_restore',
    delivered: [
      ['flowViewDidStartRestore', 'view-1'],
    ],
  ),
  _Route(
    'flow_view_did_finish_restore',
    delivered: [
      ['flowViewDidFinishRestore', 'view-1', 'profile-1'],
    ],
  ),
  _Route(
    'flow_view_did_fail_restore',
    delivered: [
      ['flowViewDidFailRestore', 'view-1', 2002],
    ],
  ),
  _Route(
    'flow_view_did_receive_error',
    delivered: [
      ['flowViewDidReceiveError', 'view-1', 2002],
    ],
  ),
  _Route(
    'flow_view_did_fail_loading_products',
    delivered: [
      ['flowViewDidFailLoadingProducts', 'view-1', 2002],
    ],
  ),
  _Route(
    'flow_view_did_finish_web_payment_navigation',
    delivered: [
      ['flowViewDidFinishWebPaymentNavigation', 'view-1', 'com.app.yearly', 2002],
    ],
  ),
  _Route(
    'flow_view_did_ask_permission',
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
    delivered: [
      ['handleAppReviewRequest', 'view-1'],
    ],
  ),
  _Route(
    'flow_view_did_receive_analytic_event',
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
    delivered: [
      ['onboardingViewDidFinishLoading', 'view-1', 'onboarding-id', 2],
    ],
  ),
  _Route(
    'onboarding_did_fail_with_error',
    delivered: [
      ['onboardingViewDidFailWithError', 'view-1', 2002],
    ],
  ),
  _Route(
    'onboarding_on_analytics_action',
    delivered: [
      ['onboardingViewOnAnalyticsEvent', 'view-1', 'onboarding-id', AdaptyOnboardingsAnalyticsEventOnboardingStarted],
    ],
  ),
  _Route(
    'onboarding_on_close_action',
    delivered: [
      ['onboardingViewOnCloseAction', 'view-1', 'onboarding-id', 'close-1'],
    ],
  ),
  _Route(
    'onboarding_on_custom_action',
    delivered: [
      ['onboardingViewOnCustomAction', 'view-1', 'onboarding-id', 'custom-1'],
    ],
  ),
  _Route(
    'onboarding_on_paywall_action',
    delivered: [
      ['onboardingViewOnPaywallAction', 'view-1', 'onboarding-id', 'paywall-1'],
    ],
  ),
  _Route(
    'onboarding_on_state_updated_action',
    delivered: [
      ['onboardingViewOnStateUpdatedAction', 'view-1', 'onboarding-id', 'element-1', 'option-1'],
    ],
  ),
  _Route(
    'did_load_latest_profile',
    delivered: [
      ['didUpdateProfileStream', 'profile-1'],
    ],
  ),
  _Route(
    'did_receive_promoted_purchase',
    delivered: [
      ['didReceivePromotedPurchaseStream', 'promoted.product'],
    ],
  ),
  _Route(
    'on_installation_details_success',
    delivered: [
      ['onUpdateInstallationDetailsSuccessStream', 'install-1', 4],
    ],
  ),
  _Route(
    'on_installation_details_fail',
    delivered: [
      ['onUpdateInstallationDetailsFailStream', 2002],
    ],
  ),
];

final _schema = ContractSchema.load('.');
final _corpus = Corpus.load('.');

/// The platforms an event goes on: each platform that sends it when its case differs between them, iOS (or the only
/// platform that sends it) otherwise.
List<ContractPlatform> _platformsOf(String event) {
  final sending = _schema.eventPlatforms[event]!;
  final differs = _corpus.fixtures.any(
    (f) => f.kind == CorpusKind.event && f.name == event && f.caseName == 'default' && f.platform != null,
  );
  return differs ? sending.toList() : [sending.first];
}

/// The keys of the case of [event] on [platform] the native side writes at the top of the event, but `id`: the SDK
/// takes the event from the name of the call on the channel.
List<String> _topKeys(String event, ContractPlatform platform) => [
  for (final key in (_corpus.fixture(CorpusKind.event, event, 'default', platform)!.payload! as Map).keys)
    if (key != 'id') key as String,
];

/// The corpus with the default case of every event on every platform without each of its top keys, as the case
/// `without_top_<key>`.
final _withoutTopKeys = Corpus(
  fixtures: [
    ..._corpus.fixtures,
    for (final route in _routes)
      for (final platform in _platformsOf(route.event))
        for (final key in _topKeys(route.event, platform))
          CorpusFixture(
            kind: CorpusKind.event,
            name: route.event,
            caseName: 'without_top_$key',
            platform: platform,
            path: 'events/${route.event}/without_top_$key.${platform.name}.json (made by the test)',
            provenance: const {'source': 'hand', 'native': 'both'},
            expect: null,
            notes: 'the default case without $key',
            payload: {
              ...(_corpus.fixture(CorpusKind.event, route.event, 'default', platform)!.payload!
                  as Map<String, Object?>),
            }..remove(key),
          ),
  ],
  baseline: _corpus.baseline,
  problems: const [],
);

/// Sends the case [caseName] of [route] on [platform] and returns what the app and the native side got. What the SDK
/// prints, such as an event it could not read, is kept out of the output of the test.
Future<List<Object?>> _deliver(_Route route, ContractPlatform platform, {String caseName = 'default'}) async {
  final native = ContractNative.install(platform: platform, corpus: _withoutTopKeys);
  await runZoned(() async {
    await native.sendEvent(route.event, caseName: caseName);
    await pumpEventQueue();
    for (final callback in _resolverCallbacks) {
      callback();
    }
    await pumpEventQueue();
  }, zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) {}));
  return [
    [..._log],
    native.calls.map((call) => [call.method, call.arguments]).toList(),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final subscriptions = <StreamSubscription<Object>>[];

  setUp(() {
    _log.clear();
    _resolverCallbacks.clear();
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
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
  });

  for (final route in _routes) {
    for (final platform in _platformsOf(route.event)) {
      test('routes ${route.event} on ${platform.name}', () async {
        final [delivered, sent] = await _deliver(route, platform);

        expect(delivered, route.delivered);
        expect(sent, route.sent);
      });

      // The SDK reads every key the native side writes at the top of the event: without one, the app or the native
      // side gets something else.
      for (final key in _topKeys(route.event, platform)) {
        test('${route.event} on ${platform.name} without $key delivers something else', () async {
          final [delivered, sent] = await _deliver(route, platform, caseName: 'without_top_$key');

          expect([delivered, sent], isNot([route.delivered, route.sent]));
        });
      }
    }
  }

  test('every bridge event has a route', () {
    // Sorted lists rather than sets, so that an event routed twice fails as well.
    final routed = _routes.map((route) => route.event).toList()..sort();
    final known = nativeEventWireNames.values.toList()..sort();

    expect(routed, known);
  });
}

/// The dispatcher handles an event on the runtime it is given. None of these tests installs that runtime: the current
/// one stays the production runtime, so a branch that reads the current runtime instead of its parameter misses the
/// state set on the given one.
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/runtime/adapty_internal_error_sink.dart';
import 'package:adapty_flutter/src/runtime/adapty_runtime.dart';
import 'package:adapty_flutter/src/runtime/event_dispatcher.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/collecting_error_sink.dart';
import '../support/fake_transport.dart';

const _profile = {'profile_id': 'profile-1', 'segment_hash': 'segment-hash', 'timestamp': 1, 'is_test_user': false};

const _view = {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'};

/// A yearly subscription as the iOS SDK reports it.
const _product = {
  'vendor_product_id': 'com.app.yearly',
  'flow_product_id': 'p1',
  'adapty_product_id': 'adapty-yearly',
  'access_level_id': 'premium',
  'product_type': 'annual',
  'paywall_product_index': 0,
  'paywall_variation_id': 'variation-id',
  'paywall_ab_test_name': 'ab-test',
  'paywall_name': 'Paywall',
  'localized_description': 'Premium for a year',
  'localized_title': 'Premium',
  'is_family_shareable': false,
  'region_code': 'DE',
  'price': {'amount': 119.88, 'currency_code': 'EUR', 'currency_symbol': '€', 'localized_string': '119,88 €'},
  'subscription': {
    'group_identifier': '21345678',
    'period': {'unit': 'year', 'number_of_units': 1},
    'localized_period': '1 year',
  },
};

const _promotedProduct = {
  'vendor_product_id': 'promoted.product',
  'localized_description': 'Promoted product',
  'localized_title': 'Promoted',
  'is_family_shareable': true,
  'region_code': 'US',
  'price': {'amount': 9.99, 'currency_code': 'USD', 'currency_symbol': r'$', 'localized_string': r'$9.99'},
};

/// Records the appearing views that reach it.
class _Observer extends AdaptyUIFlowsEventsObserver {
  final appeared = <String>[];

  @override
  void flowViewDidAppear(AdaptyUIFlowView view) => appeared.add(view.id);

  @override
  void flowViewDidFinishPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product, AdaptyPurchaseResult result) {}

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) {}
}

/// Grants every permission and records the views that ask for an app review.
class _GrantingHandler extends AdaptyUISystemRequestsHandler {
  final appReviews = <String>[];

  @override
  Future<AdaptyUIPermissionResult> handlePermission(
    AdaptyUIFlowView view,
    AdaptyUIPermission permission,
    Map<String, String>? customArgs,
  ) async => const AdaptyUIPermissionResult.granted();

  @override
  Future<void> handleAppReviewRequest(AdaptyUIFlowView view) async => appReviews.add(view.id);
}

/// Records the observer mode purchases and restores that reach it.
class _Resolver extends AdaptyUIObserverModeResolver {
  final initiated = <String>[];

  @override
  void observerModeDidInitiatePurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    void Function() onStartPurchase,
    void Function() onFinishPurchase,
  ) => initiated.add('purchase ${view.id} ${product.vendorProductId}');

  @override
  void observerModeDidInitiateRestore(
    AdaptyUIFlowView view,
    void Function() onStartRestore,
    void Function() onFinishRestore,
  ) => initiated.add('restore ${view.id}');
}

/// A runtime over [transport] that is never installed; it is disposed at the end of the test.
AdaptyRuntime _runtime(FakeTransport transport, {AdaptyInternalErrorSink? errorSink}) {
  final runtime = AdaptyRuntime(transport: transport, errorSink: errorSink);
  addTearDown(runtime.debugDispose);
  return runtime;
}

Future<Object?> _dispatch(AdaptyRuntime runtime, String eventName, Map<String, dynamic> payload) =>
    const AdaptyEventDispatcher().dispatch(runtime, eventName, jsonEncode(payload));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dispatch delivers a profile event to the profile stream of the given runtime', () async {
    final runtime = _runtime(FakeTransport());
    final profiles = <String>[];
    final subscription = runtime
        .runBound(() => Adapty().didUpdateProfileStream)
        .listen((profile) => profiles.add(profile.profileId));
    addTearDown(subscription.cancel);

    await _dispatch(runtime, 'did_load_latest_profile', {'profile': _profile});
    await pumpEventQueue();

    expect(profiles, ['profile-1']);
  });

  test('dispatch delivers a flow event to the observer of the given runtime', () async {
    final runtime = _runtime(FakeTransport());
    final observer = _Observer();
    runtime.runBound(() => AdaptyUI().setFlowsEventsObserver(observer));

    await _dispatch(runtime, 'flow_view_did_appear', {'view': _view});

    expect(observer.appeared, ['view-1']);
  });

  test('a permission answer from dispatch goes to the transport of the given runtime', () async {
    final fake = FakeTransport();
    final runtime = _runtime(fake);
    runtime.runBound(() => AdaptyUI().setSystemRequestsHandler(_GrantingHandler()));

    await _dispatch(runtime, 'flow_view_did_ask_permission', {
      'event_id': 'hr_1',
      'view': _view,
      'permission': 'camera',
    });

    expect(fake.calls.map((call) => call.$1), ['flow_view_did_answer_permission']);
    expect(fake.calls.map((call) => call.$2), [
      {'event_id': 'hr_1', 'status': 'granted'},
    ]);
  });

  test('dispatch hands an app review request to the handler of the given runtime', () async {
    final runtime = _runtime(FakeTransport());
    final handler = _GrantingHandler();
    runtime.runBound(() => AdaptyUI().setSystemRequestsHandler(handler));

    await _dispatch(runtime, 'flow_view_did_request_app_review', {'view': _view});

    expect(handler.appReviews, ['view-1']);
  });

  test('dispatch hands an observer mode purchase to the resolver of the given runtime', () async {
    final runtime = _runtime(FakeTransport());
    final resolver = _Resolver();
    runtime.runBound(() => AdaptyUI().setObserverModeResolver(resolver));

    await _dispatch(runtime, 'flow_view_observer_did_initiate_purchase', {
      'event_id': 'e1',
      'view': _view,
      'product': _product,
    });

    expect(resolver.initiated, ['purchase view-1 com.app.yearly']);
  });

  test('dispatch hands an observer mode restore to the resolver of the given runtime', () async {
    final runtime = _runtime(FakeTransport());
    final resolver = _Resolver();
    runtime.runBound(() => AdaptyUI().setObserverModeResolver(resolver));

    await _dispatch(runtime, 'flow_view_observer_did_initiate_restore', {'event_id': 'e2', 'view': _view});

    expect(resolver.initiated, ['restore view-1']);
  });

  test('dispatch hands a promoted product to a listener on the stream of the given runtime', () async {
    final fake = FakeTransport();
    final runtime = _runtime(fake);
    final products = <String>[];
    final subscription = runtime
        .runBound(() => Adapty().didReceivePromotedPurchaseStream)
        .listen((product) => products.add(product.vendorProductId));
    addTearDown(subscription.cancel);

    await _dispatch(runtime, 'did_receive_promoted_purchase', {'product': _promotedProduct});
    await settle(runtime);

    expect(products, ['promoted.product']);
    expect(fake.calls, isEmpty, reason: 'a listener takes the purchase over');
  });

  test(
    'a promoted purchase nobody listens for that fails to complete is reported to the sink of the given runtime',
    () async {
      // The purchase fails whichever way it goes out: the fake answers with an error, and the adapty channel has no
      // native side in tests.
      final fake = FakeTransport()..replyError('make_promoted_purchase', code: 2);
      final sink = CollectingErrorSink();
      final runtime = _runtime(fake, errorSink: sink);

      await _dispatch(runtime, 'did_receive_promoted_purchase', {'product': _promotedProduct});
      await settle(runtime);

      expect(sink.records.map((record) => (record.kind, record.context)), [
        (AdaptyInternalErrorKind.promotedAutoCompleteFailed, 'promoted_purchase.complete'),
      ]);
    },
  );
}

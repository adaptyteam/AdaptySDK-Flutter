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

class _GrantingHandler extends AdaptyUISystemRequestsHandler {
  @override
  Future<AdaptyUIPermissionResult> handlePermission(
    AdaptyUIFlowView view,
    AdaptyUIPermission permission,
    Map<String, String>? customArgs,
  ) async => const AdaptyUIPermissionResult.granted();
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

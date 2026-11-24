import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

/// A Google Play subscription. [ids] says which transaction ids it carries: both, one, none, or explicit nulls.
Map<String, dynamic> _subscription({String ids = 'both'}) => {
  'store': 'play_store',
  'vendor_product_id': 'yearly.premium:yearly-base',
  if (ids == 'both' || ids == 'original only') 'vendor_original_transaction_id': 'GPA.3375-1',
  if (ids == 'both') 'vendor_transaction_id': 'GPA.3375-1..0',
  if (ids == 'nulls') 'vendor_transaction_id': null,
  if (ids == 'nulls') 'vendor_original_transaction_id': null,
  'is_active': true,
  'is_lifetime': false,
  'activated_at': '2026-01-01T00:00:00.000Z',
  'expires_at': '2027-01-01T00:00:00.000Z',
  'is_in_grace_period': false,
  'is_sandbox': true,
  'is_refund': false,
  'will_renew': true,
};

Map<String, dynamic> _profile(Map<String, Map<String, dynamic>> subscriptions) => {
  'profile_id': 'profile-id',
  'segment_hash': 'segment-hash',
  'timestamp': 1760436000000,
  'is_test_user': false,
  'subscriptions': subscriptions,
};

final _product = {
  'vendor_product_id': 'yearly.premium',
  'adapty_product_id': 'adapty-yearly',
  'access_level_id': 'premium',
  'product_type': 'annual',
  'paywall_product_index': 0,
  'paywall_variation_id': 'variation-id',
  'paywall_ab_test_name': 'ab-test',
  'paywall_name': 'Paywall',
  'localized_description': 'Premium for a year',
  'localized_title': 'Premium',
  'price': {'amount': 119.88, 'currency_code': 'EUR', 'currency_symbol': '€', 'localized_string': '€119.88'},
};

final _flow = {
  'placement': {
    'developer_id': 'placement-id',
    'audience_name': 'Audience',
    'revision': 1,
    'ab_test_name': 'ab-test',
    'placement_audience_version_id': 'placement-audience-version-id',
  },
  'flow_id': 'flow-id',
  'flow_name': 'Flow',
  'variation_id': 'variation-id',
  'remote_configs': <dynamic>[],
  'variations': [
    {'paywall_id': 'paywall-id', 'paywall_name': 'Paywall', 'variation_id': 'variation-id', 'products': <dynamic>[]},
  ],
  'response_created_at': 0,
};

class _Observer extends AdaptyUIFlowsEventsObserver {
  final purchases = <AdaptyPurchaseResult>[];

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) =>
      purchases.add(purchaseResult);

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final replies = <String, Map<String, dynamic>>{};

  Future<void> sendEvent(String method, Map<String, dynamic> arguments) async {
    await runZoned(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        _channel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, jsonEncode(arguments))),
        (_) {},
      ),
      zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}),
    );
    await pumpEventQueue();
  }

  setUp(() {
    replies.clear();
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      return jsonEncode(replies[call.method] ?? {'success': true});
    });
  });

  tearDown(() {
    AdaptyUI().setFlowsEventsObserver(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('a subscription without transaction ids decodes with empty ids and the other one stays intact', () async {
    replies['get_profile'] = {
      'success': _profile({'with-ids': _subscription(), 'without-ids': _subscription(ids: 'none')}),
    };

    final profile = await Adapty().getProfile();

    expect(profile.subscriptions, hasLength(2));
    expect(profile.subscriptions['with-ids']!.vendorTransactionId, 'GPA.3375-1..0');
    expect(profile.subscriptions['with-ids']!.vendorOriginalTransactionId, 'GPA.3375-1');
    expect(profile.subscriptions['without-ids']!.vendorTransactionId, '');
    expect(profile.subscriptions['without-ids']!.vendorOriginalTransactionId, '');
    expect(profile.subscriptions['without-ids']!.vendorProductId, 'yearly.premium:yearly-base');
    expect(profile.subscriptions['without-ids']!.isActive, isTrue);
  });

  test('a subscription with only the original transaction id keeps it', () async {
    replies['get_profile'] = {
      'success': _profile({'one-id': _subscription(ids: 'original only')}),
    };

    final subscription = (await Adapty().getProfile()).subscriptions['one-id']!;

    expect(subscription.vendorTransactionId, '');
    expect(subscription.vendorOriginalTransactionId, 'GPA.3375-1');
  });

  test('transaction ids sent as null decode as empty', () async {
    replies['get_profile'] = {
      'success': _profile({'nulls': _subscription(ids: 'nulls')}),
    };

    final subscription = (await Adapty().getProfile()).subscriptions['nulls']!;

    expect(subscription.vendorTransactionId, '');
    expect(subscription.vendorOriginalTransactionId, '');
  });

  test('restorePurchases returns a profile with such a subscription', () async {
    replies['restore_purchases'] = {
      'success': _profile({'without-ids': _subscription(ids: 'none')}),
    };

    final profile = await Adapty().restorePurchases();

    expect(profile.subscriptions['without-ids']!.vendorTransactionId, '');
  });

  test('a successful makePurchase returns a profile with such a subscription', () async {
    replies['get_flow'] = {'success': _flow};
    replies['get_paywall_products'] = {
      'success': [_product],
    };
    replies['make_purchase'] = {
      'success': {
        'type': 'success',
        'profile': _profile({'without-ids': _subscription(ids: 'none')}),
        'google_purchase_token': 'purchase-token',
      },
    };
    final flow = await Adapty().getFlow(placementId: 'placement-id');
    final product = (await Adapty().getPaywallProducts(flow: flow)).single;

    final result = await Adapty().makePurchase(product: product);

    expect(result, isA<AdaptyPurchaseResultSuccess>());
    final success = result as AdaptyPurchaseResultSuccess;
    expect(success.profile.subscriptions['without-ids']!.vendorTransactionId, '');
    expect(success.googlePurchaseToken, 'purchase-token');
  });

  test('a profile update and a flow purchase with such a subscription are delivered', () async {
    final profiles = <AdaptyProfile>[];
    final subscription = Adapty().didUpdateProfileStream.listen(profiles.add);
    addTearDown(subscription.cancel);
    final observer = _Observer();
    AdaptyUI().setFlowsEventsObserver(observer);
    final profile = _profile({'without-ids': _subscription(ids: 'none')});

    await sendEvent('did_load_latest_profile', {'profile': profile});
    await sendEvent('flow_view_did_finish_purchase', {
      'view': {'id': 'view-id', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
      'product': _product,
      'purchased_result': {'type': 'success', 'profile': profile, 'google_purchase_token': 'purchase-token'},
    });

    expect(profiles, hasLength(1));
    expect(profiles.single.subscriptions['without-ids']!.vendorTransactionId, '');
    expect(observer.purchases, hasLength(1));
    final purchase = observer.purchases.single as AdaptyPurchaseResultSuccess;
    expect(purchase.profile.subscriptions['without-ids']!.vendorOriginalTransactionId, '');
  });
}

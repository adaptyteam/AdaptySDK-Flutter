import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

/// An access level that is active and renews, with every optional field set.
const _premium = {
  'id': 'premium',
  'is_active': true,
  'vendor_product_id': 'com.app.yearly',
  'store': 'app_store',
  'activated_at': '2026-01-01T00:00:00.000Z',
  'renewed_at': '2026-09-01T00:00:00.000Z',
  'expires_at': '2026-10-01T00:00:00.000Z',
  'is_lifetime': false,
  'active_introductory_offer_type': 'free_trial',
  'active_promotional_offer_type': 'pay_as_you_go',
  'active_promotional_offer_id': 'promo-offer',
  'offer_id': 'offer-id',
  'will_renew': true,
  'is_in_grace_period': false,
  'unsubscribed_at': '2026-09-15T00:00:00.000Z',
  'billing_issue_detected_at': '2026-09-20T00:00:00.000Z',
  'starts_at': '2026-01-01T00:00:00.000Z',
  'cancellation_reason': 'voluntarily_cancelled',
  'is_refund': false,
};

/// A lifetime access level that is no longer active, with the optional fields left out.
const _lifetime = {
  'id': 'lifetime',
  'is_active': false,
  'vendor_product_id': 'com.app.lifetime',
  'store': 'play_store',
  'activated_at': '2025-05-05T05:05:05.000Z',
  'is_lifetime': true,
  'will_renew': false,
  'is_in_grace_period': true,
  'is_refund': true,
};

Map<String, dynamic> _profile() => {
  'profile_id': 'profile-id',
  'segment_hash': 'segment-hash',
  'timestamp': 1760436000000,
  'is_test_user': false,
  'paid_access_levels': {'premium': _premium, 'lifetime': _lifetime},
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

final _product = {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final replies = <String, Object>{};

  setUp(() {
    replies.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      return jsonEncode(replies[call.method] ?? {'success': true});
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  /// Buys the only product of a flow; the native side answers with [result].
  Future<AdaptyPurchaseResult> purchase(Map<String, dynamic> result) async {
    replies['get_flow'] = {'success': _flow};
    replies['get_paywall_products'] = {
      'success': [_product],
    };
    replies['make_purchase'] = {'success': result};
    final flow = await Adapty().getFlow(placementId: 'placement-id');
    final product = (await Adapty().getPaywallProducts(flow: flow)).single;
    return Adapty().makePurchase(product: product);
  }

  test('two access levels decode with every field', () async {
    replies['get_profile'] = {'success': _profile()};

    final accessLevels = (await Adapty().getProfile()).accessLevels;

    expect(accessLevels.keys, unorderedEquals(['premium', 'lifetime']));
    final premium = accessLevels['premium']!;
    expect(premium.id, 'premium');
    expect(premium.isActive, isTrue);
    expect(premium.vendorProductId, 'com.app.yearly');
    expect(premium.store, 'app_store');
    expect(premium.activatedAt, DateTime.utc(2026, 1, 1));
    expect(premium.renewedAt, DateTime.utc(2026, 9, 1));
    expect(premium.expiresAt, DateTime.utc(2026, 10, 1));
    expect(premium.isLifetime, isFalse);
    expect(premium.activeIntroductoryOfferType, 'free_trial');
    expect(premium.activePromotionalOfferType, 'pay_as_you_go');
    expect(premium.activePromotionalOfferId, 'promo-offer');
    expect(premium.offerId, 'offer-id');
    expect(premium.willRenew, isTrue);
    expect(premium.isInGracePeriod, isFalse);
    expect(premium.unsubscribedAt, DateTime.utc(2026, 9, 15));
    expect(premium.billingIssueDetectedAt, DateTime.utc(2026, 9, 20));
    expect(premium.startsAt, DateTime.utc(2026, 1, 1));
    expect(premium.cancellationReason, 'voluntarily_cancelled');
    expect(premium.isRefund, isFalse);

    final lifetime = accessLevels['lifetime']!;
    expect(lifetime.id, 'lifetime');
    expect(lifetime.isActive, isFalse);
    expect(lifetime.vendorProductId, 'com.app.lifetime');
    expect(lifetime.store, 'play_store');
    expect(lifetime.activatedAt, DateTime.utc(2025, 5, 5, 5, 5, 5));
    expect(lifetime.renewedAt, isNull);
    expect(lifetime.expiresAt, isNull);
    expect(lifetime.isLifetime, isTrue);
    expect(lifetime.activeIntroductoryOfferType, isNull);
    expect(lifetime.activePromotionalOfferType, isNull);
    expect(lifetime.activePromotionalOfferId, isNull);
    expect(lifetime.offerId, isNull);
    expect(lifetime.willRenew, isFalse);
    expect(lifetime.isInGracePeriod, isTrue);
    expect(lifetime.unsubscribedAt, isNull);
    expect(lifetime.billingIssueDetectedAt, isNull);
    expect(lifetime.startsAt, isNull);
    expect(lifetime.cancellationReason, isNull);
    expect(lifetime.isRefund, isTrue);
  });

  test('a successful purchase decodes its profile and both tokens', () async {
    final result = await purchase({
      'type': 'success',
      'profile': _profile(),
      'apple_jws_transaction': 'jws-transaction',
      'google_purchase_token': 'purchase-token',
    });

    expect(result, isA<AdaptyPurchaseResultSuccess>());
    final success = result as AdaptyPurchaseResultSuccess;
    expect(success.appleJwsTransaction, 'jws-transaction');
    expect(success.googlePurchaseToken, 'purchase-token');
    expect(success.profile.profileId, 'profile-id');
    expect(success.profile.accessLevels['premium']!.isActive, isTrue);
    expect(success.profile.accessLevels['lifetime']!.isActive, isFalse);
  });

  test('a cancelled purchase decodes as user cancelled', () async {
    final result = await purchase({'type': 'user_cancelled'});

    expect(result, isA<AdaptyPurchaseResultUserCancelled>());
    expect(result, isNot(isA<AdaptyPurchaseResultPending>()));
  });

  test('a pending purchase decodes as pending', () async {
    final result = await purchase({'type': 'pending'});

    expect(result, isA<AdaptyPurchaseResultPending>());
  });
}

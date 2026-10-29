import 'package:adapty_flutter/src/models/adapty_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// The profile is cross-store: a Google Play purchase shows up on an iPhone and
/// an App Store purchase on an Android device. The decoders must therefore not
/// look at the device platform when they read the offer ids.
void main() {
  group('profile offer ids', () {
    test('reads offerId of a Google Play purchase on both models', () {
      final profile = _profile(
        accessLevel: _accessLevel(store: 'play_store', offerId: 'intro-pay-up-front-weekly-premium-determined'),
        subscription: _subscription(store: 'play_store', offerId: 'intro-pay-up-front-weekly-premium-determined'),
      );

      final accessLevel = profile.accessLevels['premium']!;
      final subscription = profile.subscriptions['weekly.premium.599']!;

      expect(accessLevel.offerId, 'intro-pay-up-front-weekly-premium-determined');
      expect(accessLevel.activePromotionalOfferId, isNull);
      expect(subscription.offerId, 'intro-pay-up-front-weekly-premium-determined');
      expect(subscription.activePromotionalOfferId, isNull);
    });

    test('reads activePromotionalOfferId of an App Store purchase on both models', () {
      final profile = _profile(
        accessLevel: _accessLevel(store: 'app_store', activePromotionalOfferId: 'promo.weekly.50off'),
        subscription: _subscription(store: 'app_store', activePromotionalOfferId: 'promo.weekly.50off'),
      );

      final accessLevel = profile.accessLevels['premium']!;
      final subscription = profile.subscriptions['weekly.premium.599']!;

      expect(accessLevel.activePromotionalOfferId, 'promo.weekly.50off');
      expect(accessLevel.offerId, isNull);
      expect(subscription.activePromotionalOfferId, 'promo.weekly.50off');
      expect(subscription.offerId, isNull);
    });

    test('leaves both ids null on both models when the profile has none', () {
      final profile = _profile(
        accessLevel: _accessLevel(store: 'app_store'),
        subscription: _subscription(store: 'app_store'),
      );

      final accessLevel = profile.accessLevels['premium']!;
      final subscription = profile.subscriptions['weekly.premium.599']!;

      expect(accessLevel.offerId, isNull);
      expect(accessLevel.activePromotionalOfferId, isNull);
      expect(subscription.offerId, isNull);
      expect(subscription.activePromotionalOfferId, isNull);
    });

    test('reads both ids independently when both are present', () {
      final profile = _profile(
        accessLevel: _accessLevel(
          store: 'play_store',
          offerId: 'intro-pay-up-front-weekly-premium-determined',
          activePromotionalOfferId: 'promo.weekly.50off',
        ),
        subscription: _subscription(
          store: 'play_store',
          offerId: 'intro-pay-up-front-weekly-premium-determined',
          activePromotionalOfferId: 'promo.weekly.50off',
        ),
      );

      final accessLevel = profile.accessLevels['premium']!;
      final subscription = profile.subscriptions['weekly.premium.599']!;

      expect(accessLevel.offerId, 'intro-pay-up-front-weekly-premium-determined');
      expect(accessLevel.activePromotionalOfferId, 'promo.weekly.50off');
      expect(subscription.offerId, 'intro-pay-up-front-weekly-premium-determined');
      expect(subscription.activePromotionalOfferId, 'promo.weekly.50off');
    });
  });
}

AdaptyProfile _profile({required Map<String, dynamic> accessLevel, required Map<String, dynamic> subscription}) =>
    AdaptyProfileJSONBuilder.fromJsonValue({
      'profile_id': 'profile-id',
      'segment_hash': 'segment-hash',
      'timestamp': 1760436000000,
      'is_test_user': false,
      'paid_access_levels': {'premium': accessLevel},
      'subscriptions': {'weekly.premium.599': subscription},
    });

Map<String, dynamic> _accessLevel({required String store, String? offerId, String? activePromotionalOfferId}) => {
  'id': 'premium',
  'is_active': true,
  'vendor_product_id': 'weekly.premium.599',
  'store': store,
  'activated_at': '2026-10-14T10:00:00.000Z',
  'is_lifetime': false,
  'will_renew': true,
  'is_in_grace_period': false,
  'is_refund': false,
  if (offerId != null) 'offer_id': offerId,
  if (activePromotionalOfferId != null) 'active_promotional_offer_id': activePromotionalOfferId,
};

Map<String, dynamic> _subscription({required String store, String? offerId, String? activePromotionalOfferId}) => {
  'store': store,
  'vendor_product_id': 'weekly.premium.599',
  'vendor_transaction_id': 'transaction-id',
  'vendor_original_transaction_id': 'original-transaction-id',
  'is_active': true,
  'is_lifetime': false,
  'activated_at': '2026-10-14T10:00:00.000Z',
  'is_in_grace_period': false,
  'is_sandbox': false,
  'is_refund': false,
  'will_renew': true,
  'billing_plan_id': 'up_front',
  if (offerId != null) 'offer_id': offerId,
  if (activePromotionalOfferId != null) 'active_promotional_offer_id': activePromotionalOfferId,
};

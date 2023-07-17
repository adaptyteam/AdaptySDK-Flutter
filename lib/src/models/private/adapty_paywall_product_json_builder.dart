//
//  adapty_paywall_product_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../adapty_paywall_product.dart';

extension AdaptyPaywallProductJSONBuilder on AdaptyPaywallProduct {
  dynamic get jsonValue => {
        _Keys.vendorProductId: vendorProductId,
        if (AdaptySDKNative.isIOS && promotionalOfferId != null) _Keys.promotionalOfferId: promotionalOfferId,
        _Keys.variationId: variationId,
        _Keys.paywallABTestName: paywallABTestName,
        _Keys.paywallName: paywallName,
        if (_payloadData != null) _Keys.payloadData: _payloadData,
      };

  static AdaptyPaywallProduct fromJsonValue(Map<String, dynamic> json) {
    return AdaptyPaywallProduct._(
      json.string(_Keys.vendorProductId),
      AdaptySDKNative.isAndroid ? json.eligibility(_Keys.androidIntroductoryOfferEligibility) : null,
      json.stringIfPresent(_Keys.payloadData),
      json.string(_Keys.variationId),
      json.string(_Keys.paywallABTestName),
      json.string(_Keys.paywallName),
      json.string(_Keys.localizedDescription),
      json.string(_Keys.localizedTitle),
      json.float(_Keys.price),
      json.stringIfPresent(_Keys.currencyCode),
      json.stringIfPresent(_Keys.currencySymbol),
      AdaptySDKNative.isIOS ? json.stringIfPresent(_Keys.regionCode) : null,
      AdaptySDKNative.isIOS ? (json.booleanIfPresent(_Keys.isFamilyShareable) ?? false) : false,
      json.subscriptionPeriodIfPresent(_Keys.subscriptionPeriod),
      json.productDiscountIfPresent(_Keys.introductoryDiscount),
      AdaptySDKNative.isIOS ? json.stringIfPresent(_Keys.subscriptionGroupIdentifier) : null,
      AdaptySDKNative.isIOS ? json.productDiscountIfPresent(_Keys.promotionalOffer) : null,
      json.stringIfPresent(_Keys.localizedPrice),
      json.stringIfPresent(_Keys.localizedSubscriptionPeriod),
      AdaptySDKNative.isAndroid ? json.subscriptionPeriodIfPresent(_Keys.androidFreeTrialPeriod) : null,
      AdaptySDKNative.isAndroid ? json.stringIfPresent(_Keys.androidLocalizedFreeTrialPeriod) : null,
    );
  }
}

class _Keys {
  static const vendorProductId = 'vendor_product_id';
  static const androidIntroductoryOfferEligibility = 'introductory_offer_eligibility';
  static const payloadData = 'payload_data';

  static const promotionalOfferId = 'promotional_offer_id';
  static const variationId = 'variation_id';
  static const paywallABTestName = 'paywall_ab_test_name';
  static const paywallName = 'paywall_name';

  static const localizedDescription = "localized_description";
  static const localizedTitle = "localized_title";
  static const price = 'price';
  static const currencyCode = "currency_code";
  static const currencySymbol = "currency_symbol";
  static const regionCode = "region_code";
  static const isFamilyShareable = "is_family_shareable";
  static const subscriptionPeriod = "subscription_period";
  static const introductoryDiscount = "introductory_discount";
  static const subscriptionGroupIdentifier = "subscription_group_identifier";
  static const promotionalOffer = 'promotional_offer';
  static const localizedPrice = "localized_price";
  static const localizedSubscriptionPeriod = "localized_subscription_period";
  static const androidLocalizedFreeTrialPeriod = 'localized_free_trial_period';
  static const androidFreeTrialPeriod = 'free_trial_period';
}

//
//  adapty_deferred_product_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../models/adapty_deferred_product.dart';

extension AdaptyDeferredProductJSONBuilder on AdaptyDeferredProduct {
  static AdaptyDeferredProduct fromJsonValue(Map<String, dynamic> json) {
    return AdaptyDeferredProduct._(
      json.string(_Keys.vendorProductId),
      json.boolean(_Keys.promotionalOfferEligibility),
      json.stringIfPresent(_Keys.promotionalOfferId),
      json.string(_Keys.localizedDescription),
      json.string(_Keys.localizedTitle),
      json.float(_Keys.price),
      json.stringIfPresent(_Keys.currencyCode),
      json.stringIfPresent(_Keys.currencySymbol),
      json.stringIfPresent(_Keys.regionCode),
      json.boolean(_Keys.isFamilyShareable),
      json.subscriptionPeriodIfPresent(_Keys.subscriptionPeriod),
      json.productDiscountIfPresent(_Keys.introductoryDiscount),
      json.stringIfPresent(_Keys.subscriptionGroupIdentifier),
      json.productDiscountListIfPresent(_Keys.discounts) ?? <AdaptyProductDiscount>[],
      json.stringIfPresent(_Keys.localizedPrice),
      json.stringIfPresent(_Keys.localizedSubscriptionPeriod),
    );
  }
}

class _Keys {
  static const vendorProductId = 'vendor_product_id';
  static const promotionalOfferEligibility = 'promotional_offer_eligibility';
  static const promotionalOfferId = 'promotional_offer_id';

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
  static const discounts = 'discounts';
  static const localizedPrice = "localized_price";
  static const localizedSubscriptionPeriod = "localized_subscription_period";
}

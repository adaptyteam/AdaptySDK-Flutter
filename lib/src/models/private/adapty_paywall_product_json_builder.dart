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
        if (AdaptySDKNative.isIOS && subscriptionDetails?.offerId != null) _Keys.iosDiscountId: subscriptionDetails?.offerId,
        _Keys.paywallVariationId: paywallVariationId,
        _Keys.paywallABTestName: paywallABTestName,
        _Keys.paywallName: paywallName,
        if (_payloadData != null) _Keys.payloadData: _payloadData,
      };

  static AdaptyPaywallProduct fromJsonValue(Map<String, dynamic> json) {
    var productCategory = json.productCategory(_Keys.category);
    return AdaptyPaywallProduct._(
      json.string(_Keys.vendorProductId),
      productCategory,
      json.string(_Keys.localizedDescription),
      json.string(_Keys.localizedTitle),
      json.stringIfPresent(_Keys.regionCode),
      AdaptySDKNative.isIOS ? (json.booleanIfPresent(_Keys.isFamilyShareable) ?? false) : false,
      json.string(_Keys.paywallVariationId),
      json.string(_Keys.paywallABTestName),
      json.string(_Keys.paywallName),
      (productCategory == AdaptyProductCategory.nonSubscription) ? json.nonSubscriptionDetails(_Keys.nonSubscriptionDetails) : null,
      (productCategory == AdaptyProductCategory.subscription) ? json.subscriptionDetails(_Keys.subscriptionDetails) : null,
      json.stringIfPresent(_Keys.payloadData),
    );
  }
}

class _Keys {
  static const vendorProductId = 'vendor_product_id';
  static const iosDiscountId = 'promotional_offer_id';
  static const localizedDescription = "localized_description";
  static const localizedTitle = "localized_title";
  static const regionCode = "region_code";
  static const isFamilyShareable = "is_family_shareable";
  static const paywallVariationId = 'paywall_variation_id';
  static const paywallABTestName = 'paywall_ab_test_name';
  static const paywallName = 'paywall_name';
  static const category = 'product_category';
  static const nonSubscriptionDetails = 'one_time_purchase_details';
  static const subscriptionDetails = 'subscription_details';
  static const payloadData = 'payload_data';
}

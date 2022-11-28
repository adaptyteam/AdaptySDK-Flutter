//
//  BackendProduct.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../entities/BackendProduct.dart';

extension BackendProductExtension on BackendProduct {
  static const _vendorId = 'vendor_product_id';
  static const _promotionalOfferEligibility = 'promotional_offer_eligibility';
  static const _introductoryOfferEligibility = 'introductory_offer_eligibility';
  static const _promotionalOfferId = 'promotional_offer_id';
  static const _version = 'timestamp';

  Map<String, dynamic> jsonValue() {
    return {
      _vendorId: vendorId,
      if (!Platform.isAndroid) _promotionalOfferEligibility: promotionalOfferEligibility,
      _introductoryOfferEligibility: introductoryOfferEligibility.stringValue(),
      _promotionalOfferId: promotionalOfferId,
      _version: _version2,
    };
  }

  static BackendProduct fromJsonValue(Map<String, dynamic> json) {
    return BackendProduct(
      json[_vendorId],
      json[_promotionalOfferEligibility] ?? false,
      json.eligibility(_introductoryOfferEligibility),
      json[_promotionalOfferId],
      json[_version],
    );
  }
}

extension MapExtension on Map<String, dynamic> {
  BackendProduct subscriptionPeriod(String key) {
    return BackendProductExtension.fromJsonValue(this[key]);
  }

  BackendProduct? subscriptionPeriodIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return BackendProductExtension.fromJsonValue(value);
  }
}

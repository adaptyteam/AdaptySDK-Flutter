//
//  BackendProductJSONBuilder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../entities/BackendProduct.dart';

extension BackendProductJSONBuilder on BackendProduct {
  dynamic jsonValue() {
    return {
      _Keys.vendorId: vendorId,
      if (!Platform.isAndroid) _Keys.promotionalOfferEligibility: promotionalOfferEligibility,
      _Keys.introductoryOfferEligibility: introductoryOfferEligibility.jsonValue(),
      if (promotionalOfferId != null) _Keys.promotionalOfferId: promotionalOfferId,
      _Keys.version: _version,
    };
  }

  static BackendProduct fromJsonValue(Map<String, dynamic> json) {
    return BackendProduct._(
      json.string(_Keys.vendorId),
      json.booleanIfPresent(_Keys.promotionalOfferEligibility) ?? false,
      json.eligibility(_Keys.introductoryOfferEligibility),
      json.stringIfPresent(_Keys.promotionalOfferId),
      json.integer(_Keys.version),
    );
  }
}

class _Keys {
  static const vendorId = 'vendor_product_id';
  static const promotionalOfferEligibility = 'promotional_offer_eligibility';
  static const introductoryOfferEligibility = 'introductory_offer_eligibility';
  static const promotionalOfferId = 'promotional_offer_id';
  static const version = 'timestamp';
}

extension MapExtension on Map<String, dynamic> {
  List<BackendProduct> backendProductList(String key) {
    return (this[key] as List<dynamic>).map((e) => BackendProductJSONBuilder.fromJsonValue(e)).toList(growable: false);
  }
}

//
//  backend_product_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../backend_product.dart';

extension BackendProductJSONBuilder on BackendProduct {
  dynamic get jsonValue => {
        _Keys.vendorId: vendorId,
        if (AdaptySDKNative.isIOS) _Keys.promotionalOfferEligibility: promotionalOfferEligibility,
        _Keys.introductoryOfferEligibility: introductoryOfferEligibility.jsonValue,
        if (AdaptySDKNative.isIOS && promotionalOfferId != null) _Keys.promotionalOfferId: promotionalOfferId,
        _Keys.version: _version,
      };

  static BackendProduct fromJsonValue(Map<String, dynamic> json) {
    return BackendProduct._(
      json.string(_Keys.vendorId),
      AdaptySDKNative.isIOS ? (json.booleanIfPresent(_Keys.promotionalOfferEligibility) ?? false) : false,
      json.eligibility(_Keys.introductoryOfferEligibility),
      AdaptySDKNative.isIOS ? json.stringIfPresent(_Keys.promotionalOfferId) : null,
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

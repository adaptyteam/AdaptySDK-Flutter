//
//  product_reference_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../product_reference.dart';

extension ProductReferenceJSONBuilder on ProductReference {
  dynamic get jsonValue => {
        _Keys.vendorId: vendorId,
        if (AdaptySDKNative.isIOS) _Keys.promotionalOfferEligibility: promotionalOfferEligibility,
        if (AdaptySDKNative.isIOS && promotionalOfferId != null) _Keys.promotionalOfferId: promotionalOfferId,
      };

  static ProductReference fromJsonValue(Map<String, dynamic> json) {
    return ProductReference._(
      json.string(_Keys.vendorId),
      AdaptySDKNative.isIOS ? (json.booleanIfPresent(_Keys.promotionalOfferEligibility) ?? false) : false,
      AdaptySDKNative.isIOS ? json.stringIfPresent(_Keys.promotionalOfferId) : null,
    );
  }
}

class _Keys {
  static const vendorId = 'vendor_product_id';
  static const promotionalOfferEligibility = 'promotional_offer_eligibility';
  static const promotionalOfferId = 'promotional_offer_id';
}

extension MapExtension on Map<String, dynamic> {
  List<ProductReference> productReferenceList(String key) {
    return (this[key] as List<dynamic>).map((e) => ProductReferenceJSONBuilder.fromJsonValue(e)).toList(growable: false);
  }
}

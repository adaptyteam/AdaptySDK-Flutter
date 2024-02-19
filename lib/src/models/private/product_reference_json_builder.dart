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
        _Keys.adaptyProductId: _adaptyProductId,
        if (AdaptySDKNative.isAndroid) _Keys.androidIsConsumable: androidIsConsumable,
        if (AdaptySDKNative.isAndroid) _Keys.androidBasePlanId: androidBasePlanId,
        if (AdaptySDKNative.isAndroid) _Keys.androidOfferId: androidOfferId,
        if (AdaptySDKNative.isIOS && iosDiscountId != null) _Keys.iosDiscountId: iosDiscountId,
      };

  static ProductReference fromJsonValue(Map<String, dynamic> json) {
    return ProductReference._(
      json.string(_Keys.vendorId),
      json.string(_Keys.adaptyProductId),
      AdaptySDKNative.isAndroid ? json.boolean(_Keys.androidIsConsumable) : null,
      AdaptySDKNative.isAndroid ? json.stringIfPresent(_Keys.androidBasePlanId) : null,
      AdaptySDKNative.isAndroid ? json.stringIfPresent(_Keys.androidOfferId) : null,
      AdaptySDKNative.isIOS ? json.stringIfPresent(_Keys.iosDiscountId) : null,
    );
  }
}

class _Keys {
  static const vendorId = 'vendor_product_id';
  static const adaptyProductId = 'adapty_product_id';
  static const androidIsConsumable = 'is_consumable';
  static const androidBasePlanId = 'base_plan_id';
  static const androidOfferId = 'offer_id';
  static const iosDiscountId = 'promotional_offer_id';
}

extension MapExtension on Map<String, dynamic> {
  List<ProductReference> productReferenceList(String key) {
    return (this[key] as List<dynamic>).map((e) => ProductReferenceJSONBuilder.fromJsonValue(e)).toList(growable: false);
  }
}

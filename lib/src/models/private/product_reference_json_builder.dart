//
//  product_reference_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../product_reference.dart';

extension ProductReferenceJSONBuilder on ProductReference {
  dynamic get jsonValue => {
        if (flowProductId != null) _Keys.flowProductId: flowProductId,
        _Keys.vendorId: vendorId,
        _Keys.adaptyProductId: _adaptyProductId,
        _Keys.accessLevelId: accessLevelId,
        _Keys.productType: productType,
        if (_pricingTerms != null) _Keys.pricingTerms: _pricingTerms,
        if (AdaptySDKNative.isAndroid && basePlanId != null) _Keys.basePlanId: basePlanId,
        if (AdaptySDKNative.isAndroid && offerId != null) _Keys.offerId: offerId,
      };

  static ProductReference fromJsonValue(Map<String, dynamic> json) {
    return ProductReference._(
      json.stringIfPresent(_Keys.flowProductId),
      json.string(_Keys.vendorId),
      json.string(_Keys.adaptyProductId),
      json.string(_Keys.accessLevelId),
      json.string(_Keys.productType),
      json._productReferencePricingTermsIfPresent(_Keys.pricingTerms),
      AdaptySDKNative.isAndroid ? json.stringIfPresent(_Keys.basePlanId) : null,
      AdaptySDKNative.isAndroid ? json.stringIfPresent(_Keys.offerId) : null,
    );
  }
}

class _Keys {
  static const flowProductId = 'flow_product_id';
  static const vendorId = 'vendor_product_id';
  static const adaptyProductId = 'adapty_product_id';
  static const accessLevelId = 'access_level_id';
  static const productType = 'product_type';
  static const pricingTerms = 'pricing_terms';
  static const basePlanId = 'base_plan_id'; // Android Only
  static const offerId = 'offer_id'; // Android Only

  static const billingPlan = 'billing_plan_id'; // in each pricing_terms item
}

extension MapExtension on Map<String, dynamic> {
  List<ProductReference> productReferenceList(String key) {
    return (this[key] as List<dynamic>).map((e) => ProductReferenceJSONBuilder.fromJsonValue(e)).toList(growable: false);
  }

  /// The items of `pricing_terms` kept verbatim, unknown keys included: Dart never reads them, it
  /// only sends them back. Each item must still be an object with a string `billing_plan_id`.
  List<Map<String, dynamic>>? _productReferencePricingTermsIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return List<Map<String, dynamic>>.unmodifiable(
      (value as List<dynamic>).map((e) {
        final item = e as Map<String, dynamic>;
        item.string(_Keys.billingPlan);
        return Map<String, dynamic>.unmodifiable(item);
      }),
    );
  }
}

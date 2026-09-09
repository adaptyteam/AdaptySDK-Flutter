part of '../adapty_promoted_product.dart';

extension AdaptyPromotedProductJSONBuilder on AdaptyPromotedProduct {
  dynamic get jsonValue => {
        _Keys.vendorProductId: vendorProductId,
        if (subscription?.offer?.identifier != null)
          _Keys.subscription: {
            _Keys.offer: {
              _Keys.offerIdentifier: subscription!.offer!.identifier.jsonValue,
            },
          },
        if (_payloadData != null) _Keys.payloadData: _payloadData,
      };

  static AdaptyPromotedProduct fromJsonValue(Map<String, dynamic> json) {
    return AdaptyPromotedProduct._(
      json.string(_Keys.vendorProductId),
      json.string(_Keys.localizedDescription),
      json.string(_Keys.localizedTitle),
      json.booleanIfPresent(_Keys.isFamilyShareable) ?? false,
      json.stringIfPresent(_Keys.regionCode),
      json.price(_Keys.price),
      json.productSubscriptionIfPresent(_Keys.subscription),
      json.stringIfPresent(_Keys.payloadData),
    );
  }
}

class _Keys {
  static const vendorProductId = 'vendor_product_id';
  static const localizedDescription = 'localized_description';
  static const localizedTitle = 'localized_title';
  static const isFamilyShareable = 'is_family_shareable';
  static const regionCode = 'region_code';
  static const price = 'price';
  static const subscription = 'subscription';
  static const offer = 'offer';
  static const offerIdentifier = 'offer_identifier';
  static const payloadData = 'payload_data';
}

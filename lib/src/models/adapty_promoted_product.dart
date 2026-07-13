import 'package:meta/meta.dart' show immutable;

import 'adapty_price.dart';
import 'adapty_product_subscription.dart';
import 'adapty_subscription_offer_identifier.dart';
import 'private/json_builder.dart';

part 'private/adapty_promoted_product_json_builder.dart';

@immutable
class AdaptyPromotedProduct {
  /// Unique identifier of a product from App Store Connect.
  final String vendorProductId;

  /// A description of the product.
  ///
  /// The description's language is determined by the storefront that the user's device is connected to, not the preferred language set on the device.
  final String localizedDescription;

  /// The name of the product.
  ///
  /// The title's language is determined by the storefront that the user's device is connected to, not the preferred language set on the device.
  final String localizedTitle;

  /// A Boolean value that indicates whether the product is available for family sharing in App Store Connect.
  final bool isFamilyShareable;

  /// The region code of the locale used to format the price of the product.
  final String? regionCode;

  /// The object which represents the main price for the product.
  final AdaptyPrice price;

  /// Detailed information about subscription (intro, offers, etc.)
  final AdaptyProductSubscription? subscription;

  final String? _payloadData;

  const AdaptyPromotedProduct._(
    this.vendorProductId,
    this.localizedDescription,
    this.localizedTitle,
    this.isFamilyShareable,
    this.regionCode,
    this.price,
    this.subscription,
    this._payloadData,
  );

  @override
  String toString() => '(vendorProductId: $vendorProductId, '
      'localizedDescription: $localizedDescription, '
      'localizedTitle: $localizedTitle, '
      'isFamilyShareable: $isFamilyShareable, '
      'regionCode: $regionCode, '
      'price: $price, '
      'subscription: $subscription)';
}

//
//  adapty_paywall_product.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart' show immutable;
import 'adapty_sdk_native.dart';
import 'private/json_builder.dart';
import 'adapty_subscription_details.dart';
import 'adapty_price.dart';

part 'private/adapty_paywall_product_json_builder.dart';

@immutable
class AdaptyPaywallProduct {
  /// Unique identifier of a product from App Store Connect or Google Play Console.
  final String vendorProductId;

  /// A description of the product.
  ///
  /// The description's language is determined by the storefront that the user's device is connected to, not the preferred language set on the device.
  final String localizedDescription;

  /// The name of the product.
  ///
  /// The title's language is determined by the storefront that the user's device is connected to, not the preferred language set on the device.
  final String localizedTitle;

  /// The region code of the locale used to format the price of the product.
  final String? regionCode;

  /// A Boolean value that indicates whether the product is available for family sharing in App Store Connect. (Will be `false` for iOS version below 14.0 and macOS version below 11.0).
  final bool isFamilyShareable;

  /// Same as `variationId` property of the parent AdaptyPaywall.
  final String paywallVariationId;

  /// Same as `abTestName` property of the parent AdaptyPaywall.
  final String paywallABTestName;

  /// Same as `name` property of the parent AdaptyPaywall.
  final String paywallName;

  /// The object which represents the main price for the product.
  final AdaptyPrice price;

  /// Detailed information about subscription (intro, offers, etc.)
  final AdaptySubscriptionDetails? subscriptionDetails;

  final String? _payloadData;

  const AdaptyPaywallProduct._(
    this.vendorProductId,
    this.localizedDescription,
    this.localizedTitle,
    this.regionCode,
    this.isFamilyShareable,
    this.paywallVariationId,
    this.paywallABTestName,
    this.paywallName,
    this.price,
    this.subscriptionDetails,
    this._payloadData,
  );

  @override
  String toString() => '(vendorProductId: $vendorProductId, '
      'localizedDescription: $localizedDescription, '
      'localizedTitle: $localizedTitle, '
      'regionCode: $regionCode, '
      'isFamilyShareable: $isFamilyShareable, '
      'paywallVariationId: $paywallVariationId, '
      'paywallABTestName: $paywallABTestName, '
      'paywallName: $paywallName, '
      'price: $price, '
      'subscriptionDetails: $subscriptionDetails)';
}

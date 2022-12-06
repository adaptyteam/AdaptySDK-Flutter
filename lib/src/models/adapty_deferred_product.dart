//
//  adapty_deferred_product.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;
import 'private/json_builder.dart';
import 'adapty_product_discount.dart';
import 'adapty_subscription_period.dart';

part 'private/adapty_deferred_product_json_builder.dart';

@immutable
class AdaptyDeferredProduct {
  /// Unique identifier of a product from App Store Connect or Google Play Console.
  final String vendorProductId;

  /// User's eligibility for the promotional offers. Check this property before displaying info about promotional offers.
  bool get promotionalOfferEligibility => promotionalOfferId != null;

  /// An identifier of a promotional offer, provided by Adapty for this specific user.
  final String? promotionalOfferId;

  const AdaptyDeferredProduct._(
    this.vendorProductId,
    this.promotionalOfferId,
    this.localizedDescription,
    this.localizedTitle,
    this.price,
    this.currencyCode,
    this.currencySymbol,
    this.regionCode,
    this.isFamilyShareable,
    this.subscriptionPeriod,
    this.introductoryDiscount,
    this.subscriptionGroupIdentifier,
    this.discounts,
    this.localizedPrice,
    this.localizedSubscriptionPeriod,
  );

  /// A description of the product.
  ///
  /// The description's language is determined by the storefront that the user's device is connected to, not the preferred language set on the device.
  final String localizedDescription;

  /// The name of the product.
  ///
  /// The title's language is determined by the storefront that the user's device is connected to, not the preferred language set on the device.
  final String localizedTitle;

  /// The cost of the product in the local currency.
  final double price;

  /// The currency code of the locale used to format the price of the product.
  final String? currencyCode;

  /// The currency symbol of the locale used to format the price of the product.
  final String? currencySymbol;

  /// The region code of the locale used to format the price of the product.
  final String? regionCode;

  /// A Boolean value that indicates whether the product is available for family sharing in App Store Connect. (Will be `false` for iOS version below 14.0 and macOS version below 11.0).
  final bool isFamilyShareable;

  /// The period details for products that are subscriptions. (Will be `nil` for iOS version below 11.2 and macOS version below 10.14.4).
  final AdaptySubscriptionPeriod? subscriptionPeriod;

  /// The object containing introductory price information for the product. (Will be `nil` for iOS version below 11.2 and macOS version below 10.14.4).
  final AdaptyProductDiscount? introductoryDiscount;

  /// The identifier of the subscription group to which the subscription belongs. (Will be `nil` for iOS version below 12.0 and macOS version below 10.14).
  final String? subscriptionGroupIdentifier;

  /// An array of subscription offers available for the auto-renewable subscription. (Will be empty for iOS version below 12.2 and macOS version below 10.14.4).
  final List<AdaptyProductDiscount> discounts;

  /// The price's language is determined by the preferred language set on the device.
  final String? localizedPrice;

  /// The period's language is determined by the preferred language set on the device.
  final String? localizedSubscriptionPeriod;

  @override
  String toString() => '(vendorProductId: $vendorProductId, '
      'promotionalOfferEligibility: $promotionalOfferEligibility, '
      'promotionalOfferId: $promotionalOfferId, '
      'localizedDescription: $localizedDescription, '
      'localizedTitle: $localizedTitle, '
      'price: $price, '
      'currencyCode: $currencyCode, '
      'currencySymbol: $currencySymbol, '
      'regionCode: $regionCode, '
      'isFamilyShareable: $isFamilyShareable, '
      'subscriptionPeriod: $subscriptionPeriod, '
      'introductoryDiscount: $introductoryDiscount, '
      'subscriptionGroupIdentifier: $subscriptionGroupIdentifier, '
      'discounts: $discounts, '
      'localizedPrice: $localizedPrice, '
      'localizedSubscriptionPeriod: $localizedSubscriptionPeriod)';
}

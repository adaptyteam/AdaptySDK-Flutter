import 'dart:core';

import 'adapty_period.dart';
import 'adapty_product_discount.dart';

class AdaptyProduct {
  /// Unique identifier of the product.
  final String vendorProductId;

  /// Eligibility of user for introductory offer.
  final bool introductoryOfferEligibility;

  /// Eligibility of user for promotional offer.
  bool get promotionalOfferEligibility => promotionalOfferId != null;

  /// Id of the offer, provided by Adapty for this specific user.
  ///
  /// [Nullable]
  final String? promotionalOfferId;

  /// The identifier of the variation, used to attribute purchases to the paywall.
  ///
  /// [Nullable]
  final String variationId;

  /// A description of the product.
  final String? localizedDescription;

  /// The name of the product.
  final String? localizedTitle;

  /// The cost of the product in the local currency.
  final double? price;

  /// Product locale currency code.
  ///
  /// [Nullable]
  final String? currencyCode;

  /// Product locale currency symbol.
  ///
  /// [Nullable]
  final String? currencySymbol;

  /// Product locale region code.
  ///
  /// [Nullable]
  final String? regionCode;

  /// A ProductSubscriptionPeriodModel object.
  /// The period details for products that are subscriptions.
  ///
  /// [Nullable]
  final AdaptyPeriod? subscriptionPeriod;

  /// A ProductDiscountModel object, containing introductory price information for the product.
  ///
  /// [Nullable]
  final AdaptyProductDiscount? introductoryDiscount;

  /// The identifier of the subscription group to which the subscription belongs.
  ///
  /// [Nullable]
  final String? subscriptionGroupIdentifier;

  /// An array of [AdaptyProductDiscount] discount offers available for the product.
  final List<AdaptyProductDiscount>? discounts;

  /// Localized price of the product.
  ///
  /// [Nullable]
  final String? localizedPrice;

  /// Localized subscription period of the product.
  ///
  /// [Nullable]
  final String? localizedSubscriptionPeriod;

  /// Parent A/B test name
  final String paywallABTestName;

  /// Indicates whether the product is available for family sharing in App Store Connect.
  final bool? isFamilyShareable;

  /// Parent paywall name
  final String paywallName;

  AdaptyProduct.fromMap(Map<String, dynamic> map)
      : vendorProductId = map[_Keys.vendorProductId],
        introductoryOfferEligibility = false, // map[_Keys.introductoryOfferEligibility], TODO:
        promotionalOfferId = map[_Keys.promotionalOfferId],
        variationId = map[_Keys.variationId],
        localizedDescription = map[_Keys.localizedDescription],
        localizedTitle = map[_Keys.localizedTitle],
        price = map[_Keys.price] != null ? double.tryParse('${map[_Keys.price]}') : null,
        currencyCode = map[_Keys.currencyCode],
        currencySymbol = map[_Keys.currencySymbol],
        regionCode = map[_Keys.regionCode],
        subscriptionPeriod = map[_Keys.subscriptionPeriod] != null ? AdaptyPeriod.fromJson(map[_Keys.subscriptionPeriod]) : null,
        introductoryDiscount = map[_Keys.introductoryDiscount] != null ? AdaptyProductDiscount.fromJson(map[_Keys.introductoryDiscount]) : null,
        discounts = map[_Keys.discounts] != null ? (map[_Keys.discounts] as List).map((e) => AdaptyProductDiscount.fromJson(e)).toList() : List<AdaptyProductDiscount>.empty(),
        subscriptionGroupIdentifier = map[_Keys.subscriptionGroupIdentifier],
        localizedPrice = map[_Keys.localizedPrice],
        localizedSubscriptionPeriod = map[_Keys.localizedSubscriptionPeriod],
        paywallABTestName = map[_Keys.paywallABTestName],
        paywallName = map[_Keys.paywallName],
        isFamilyShareable = map[_Keys.isFamilyShareable];

  @override
  String toString() => '${_Keys.vendorProductId}: $vendorProductId, '
      '${_Keys.introductoryOfferEligibility}: $introductoryOfferEligibility, '
      '${_Keys.promotionalOfferId}: $promotionalOfferId, '
      '${_Keys.variationId}: $variationId, '
      '${_Keys.localizedDescription}: $localizedDescription, '
      '${_Keys.price}: $price, '
      '${_Keys.currencyCode}: $currencyCode, '
      '${_Keys.currencySymbol}: $currencySymbol, '
      '${_Keys.regionCode}: $regionCode, '
      '${_Keys.subscriptionPeriod}: $subscriptionPeriod, '
      '${_Keys.introductoryDiscount}: $introductoryDiscount, '
      '${_Keys.discounts}: $discounts, '
      '${_Keys.subscriptionGroupIdentifier}: $subscriptionGroupIdentifier, '
      '${_Keys.localizedPrice}: $localizedPrice, '
      '${_Keys.localizedSubscriptionPeriod}: $localizedSubscriptionPeriod, '
      '${_Keys.paywallABTestName}: $paywallABTestName, '
      '${_Keys.paywallName}: $paywallName, '
      '${_Keys.isFamilyShareable}: $isFamilyShareable';
}

class _Keys {
  static const vendorProductId = 'vendor_product_id';
  static const introductoryOfferEligibility = 'introductory_offer_eligibility';
  static const promotionalOfferId = 'promotional_offer_id';
  static const variationId = 'variation_id';
  static const localizedDescription = 'localized_description';
  static const localizedTitle = 'localized_title';
  static const price = 'price';
  static const currencyCode = 'currency_code';
  static const currencySymbol = 'currency_symbol';
  static const regionCode = 'region_code';
  static const subscriptionPeriod = 'subscription_period';
  static const introductoryDiscount = 'introductory_discount';
  static const subscriptionGroupIdentifier = 'subscription_group_identifier';
  static const discounts = 'discounts';
  static const localizedPrice = 'localized_price';
  static const localizedSubscriptionPeriod = 'localized_subscription_period';
  static const paywallABTestName = 'paywall_ab_test_name';
  static const paywallName = 'paywall_name';
  static const isFamilyShareable = 'is_family_shareable';
}

import 'dart:core';

import 'adapty_period.dart';
import 'adapty_product_discount.dart';

class AdaptyProduct {
  /// Unique identifier of the product.
  final String vendorProductId;

  /// Eligibility of user for introductory offer.
  final bool introductoryOfferEligibility;

  /// Eligibility of user for promotional offer.
  final bool promotionalOfferEligibility;

  /// Id of the offer, provided by Adapty for this specific user.
  ///
  /// [Nullable]
  final String promotionalOfferId;

  /// TODO: write docs
  ///
  /// [Nullable]
  final String variationId;

  /// A description of the product.
  final String localizedDescription;

  /// The name of the product.
  final String localizedTitle;

  /// The cost of the product in the local currency.
  final double price;

  /// Product locale currency code.
  ///
  /// [Nullable]
  final String currencyCode;

  /// Product locale currency symbol.
  ///
  /// [Nullable]
  final String currencySymbol;

  /// Product locale region code.
  ///
  /// [Nullable]
  final String regionCode;

  /// A ProductSubscriptionPeriodModel object.
  /// The period details for products that are subscriptions.
  ///
  /// [Nullable]
  final AdaptyPeriod subscriptionPeriod;

  /// A ProductDiscountModel object, containing introductory price information for the product.
  ///
  /// [Nullable]
  final AdaptyProductDiscount introductoryDiscount;

  /// The identifier of the subscription group to which the subscription belongs.
  ///
  /// [Nullable]
  final String subscriptionGroupIdentifier;

  /// An array of [AdaptyProductDiscount] discount offers available for the product.
  final List<AdaptyProductDiscount> discounts;

  /// Localized price of the product.
  ///
  /// [Nullable]
  final String localizedPrice;

  /// Localized subscription period of the product.
  ///
  /// [Nullable]
  final String localizedSubscriptionPeriod;

  AdaptyProduct.fromJson(Map<String, dynamic> json)
      : vendorProductId = json[_Keys.vendorProductId],
        introductoryOfferEligibility = json[_Keys.introductoryOfferEligibility],
        promotionalOfferEligibility = json[_Keys.promotionalOfferEligibility],
        promotionalOfferId = json[_Keys.promotionalOfferId],
        variationId = json[_Keys.variationId],
        localizedDescription = json[_Keys.localizedDescription],
        localizedTitle = json[_Keys.localizedTitle],
        price = json[_Keys.price] != null ? double.tryParse('${json[_Keys.price]}') : null,
        currencyCode = json[_Keys.currencyCode],
        currencySymbol = json[_Keys.currencySymbol],
        regionCode = json[_Keys.regionCode],
        subscriptionPeriod = json[_Keys.subscriptionPeriod] != null ? AdaptyPeriod.fromJson(json[_Keys.subscriptionPeriod]) : null,
        introductoryDiscount = json[_Keys.introductoryDiscount] != null ? AdaptyProductDiscount.fromJson(json[_Keys.introductoryDiscount]) : null,
        discounts = json[_Keys.discounts] != null ? (json[_Keys.discounts] as List).map((e) => AdaptyProductDiscount.fromJson(e)).toList() : null,
        subscriptionGroupIdentifier = json[_Keys.subscriptionGroupIdentifier],
        localizedPrice = json[_Keys.localizedPrice],
        localizedSubscriptionPeriod = json[_Keys.localizedSubscriptionPeriod];

  @override
  String toString() => '${_Keys.vendorProductId}: $vendorProductId, '
      '${_Keys.introductoryOfferEligibility}: $introductoryOfferEligibility, '
      '${_Keys.promotionalOfferEligibility}: $promotionalOfferEligibility, '
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
      '${_Keys.localizedSubscriptionPeriod}: $localizedSubscriptionPeriod, ';
}

class _Keys {
  static const vendorProductId = 'vendorProductId';
  static const introductoryOfferEligibility = 'introductoryOfferEligibility';
  static const promotionalOfferEligibility = 'promotionalOfferEligibility';
  static const promotionalOfferId = 'promotionalOfferId';
  static const variationId = 'variationId';
  static const localizedDescription = 'localizedDescription';
  static const localizedTitle = 'localizedTitle';
  static const price = 'price';
  static const currencyCode = 'currencyCode';
  static const currencySymbol = 'currencySymbol';
  static const regionCode = 'regionCode';
  static const subscriptionPeriod = 'subscriptionPeriod';
  static const introductoryDiscount = 'introductoryDiscount';
  static const subscriptionGroupIdentifier = 'subscriptionGroupIdentifier';
  static const discounts = 'discounts';
  static const localizedPrice = 'localizedPrice';
  static const localizedSubscriptionPeriod = 'localizedSubscriptionPeriod';
}

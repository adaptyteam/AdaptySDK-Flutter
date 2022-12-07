//
//  adapty_product_discount_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../adapty_product_discount.dart';

extension AdaptyProductDiscountJSONBuilder on AdaptyProductDiscount {
  static AdaptyProductDiscount fromJsonValue(Map<String, dynamic> json) {
    return AdaptyProductDiscount._(
      json.float(_Keys.price),
      AdaptySDKNative.isIOS ? json.stringIfPresent(_Keys.identifier) : null,
      json.subscriptionPeriod(_Keys.subscriptionPeriod),
      json.integer(_Keys.numberOfPeriods),
      AdaptySDKNative.isIOS ? json.paymentMode(_Keys.paymentMode) : AdaptyPaymentMode.unknown,
      json.stringIfPresent(_Keys.localizedPrice),
      json.stringIfPresent(_Keys.localizedSubscriptionPeriod),
      AdaptySDKNative.isIOS ? json.stringIfPresent(_Keys.localizedNumberOfPeriods) : null,
    );
  }
}

class _Keys {
  static const price = 'price';
  static const identifier = 'identifier';
  static const subscriptionPeriod = 'subscription_period';
  static const numberOfPeriods = 'number_of_periods';
  static const paymentMode = 'payment_mode';
  static const localizedPrice = 'localized_price';
  static const localizedSubscriptionPeriod = 'localized_subscription_period';
  static const localizedNumberOfPeriods = 'localized_number_of_periods';
}

extension MapExtension on Map<String, dynamic> {
  AdaptyProductDiscount? productDiscountIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyProductDiscountJSONBuilder.fromJsonValue(value);
  }

  List<AdaptyProductDiscount>? productDiscountListIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return (value as List<dynamic>).map((e) => AdaptyProductDiscountJSONBuilder.fromJsonValue(e)).toList(growable: false);
  }
}

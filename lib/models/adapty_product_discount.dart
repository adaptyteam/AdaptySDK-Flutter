import 'dart:core';

import 'package:adapty_flutter/models/adapty_enums.dart';
import 'package:adapty_flutter/models/adapty_period.dart';

class AdaptyProductDiscount {
  /// The discount price of the product in the user's local currency.
  final double price; // Decimal

  /// An identifier of the discount offer for the product.
  ///
  /// [Nullable]
  final String identifier; // nullable

  /// A [AdaptyPeriod] object that defines the period for the product discount.
  final AdaptyPeriod subscriptionPeriod;

  /// An integer that indicates the number of periods the product discount is available.
  final int numberOfPeriods;

  /// The payment mode for this product discount.
  /// The possible values are: free_trial, pay_as_you_go, pay_up_front.
  final AdaptyPaymentMode paymentMode;

  /// The formatted price of the discount for the user's localization.
  ///
  /// [Nullable]
  final String localizedPrice; // nullable

  /// The formatted subscription period of the discount for the user's localization.
  ///
  /// [Nullable]
  final String localizedSubscriptionPeriod; // nullable

  /// The formatted number of periods of the discount for the user's localization.
  ///
  /// [Nullable]
  final String localizedNumberOfPeriods; // nullable

  AdaptyProductDiscount.fromJson(Map<String, dynamic> json)
      : price = double.parse('${json[_Keys.price]}'),
        identifier = json[_Keys.identifier],
        subscriptionPeriod = AdaptyPeriod.fromJson(json[_Keys.subscriptionPeriod]),
        numberOfPeriods = json[_Keys.numberOfPeriods],
        paymentMode = paymentModeFromInt(json[_Keys.paymentMode]),
        localizedPrice = json[_Keys.localizedPrice],
        localizedSubscriptionPeriod = json[_Keys.localizedSubscriptionPeriod],
        localizedNumberOfPeriods = json[_Keys.localizedNumberOfPeriods];

  @override
  String toString() => '${_Keys.price}: $price, '
      '${_Keys.identifier}: $identifier, '
      '${_Keys.subscriptionPeriod}: $subscriptionPeriod, '
      '${_Keys.paymentMode}: $paymentMode, '
      '${_Keys.localizedPrice}: $localizedPrice, '
      '${_Keys.localizedSubscriptionPeriod}: $localizedSubscriptionPeriod, '
      '${_Keys.localizedNumberOfPeriods}: $localizedNumberOfPeriods';
}

class _Keys {
  static const price = 'price';
  static const identifier = 'identifier';
  static const subscriptionPeriod = 'subscriptionPeriod';
  static const numberOfPeriods = 'numberOfPeriods';
  static const paymentMode = 'paymentMode';
  static const localizedPrice = 'localizedPrice';
  static const localizedSubscriptionPeriod = 'localizedSubscriptionPeriod';
  static const localizedNumberOfPeriods = 'localizedNumberOfPeriods';
}

//
//  adapty_product_discount.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;
import 'adapty_sdk_native.dart';
import 'private/json_builder.dart';
import 'adapty_payment_mode.dart';
import 'adapty_subscription_period.dart';

part 'private/adapty_product_discount_json_builder.dart';

@immutable
class AdaptyProductDiscount {
  /// Discount price of a product in a local currency.
  final double price;

  /// Unique identifier of a discount offer for a product.
  ///
  /// [Nullable]
  final String? identifier;

  /// An information about period for a product discount.
  final AdaptySubscriptionPeriod subscriptionPeriod;

  /// A number of periods this product discount is available
  final int numberOfPeriods;

  /// A payment mode for this product discount.
  final AdaptyPaymentMode paymentMode;

  /// A formatted price of a discount for a user's locale.
  ///
  /// [Nullable]
  final String? localizedPrice;

  /// A formatted subscription period of a discount for a user's locale.
  ///
  /// [Nullable]
  final String? localizedSubscriptionPeriod;

  /// A formatted number of periods of a discount for a user's locale.
  ///
  /// [Nullable]
  final String? localizedNumberOfPeriods;

  const AdaptyProductDiscount._(
    this.price,
    this.identifier,
    this.subscriptionPeriod,
    this.numberOfPeriods,
    this.paymentMode,
    this.localizedPrice,
    this.localizedSubscriptionPeriod,
    this.localizedNumberOfPeriods,
  );

  @override
  String toString() => '(price: $price, '
      'identifier: $identifier, '
      'subscriptionPeriod: $subscriptionPeriod, '
      'numberOfPeriods: $numberOfPeriods, '
      'paymentMode: $paymentMode, '
      'localizedPrice: $localizedPrice, '
      'localizedSubscriptionPeriod: $localizedSubscriptionPeriod, '
      'localizedNumberOfPeriods: $localizedNumberOfPeriods)';
}

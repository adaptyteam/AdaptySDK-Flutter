//
//  adapty_subscription_phase.dart
//  Adapty
//
//  Created by Aleksei Valiano on 20.07.2023.
//

import 'package:meta/meta.dart' show immutable;
import 'private/json_builder.dart';
import 'adapty_payment_mode.dart';
import 'adapty_subscription_period.dart';
import 'adapty_price.dart';
import 'adapty_subscription_phase_category.dart';
import 'adapty_subscription_recurrence_mode.dart';

part 'private/adapty_subscription_phase_json_builder.dart';

@immutable
class AdaptySubscriptionPhase {
  final AdaptySubscriptionPhaseCategory category;

  final AdaptyPrice price;

  /// [Nullable]
  final String? identifier;

  final AdaptySubscriptionRecurrenceMode recurrenceMode;

  /// A number of periods this product discount is available
  final int numberOfPeriods;

  /// A payment mode for this product discount.
  final AdaptyPaymentMode paymentMode;

  /// An information about period for a product discount.
  final AdaptySubscriptionPeriod subscriptionPeriod;

  /// A formatted subscription period of a discount for a user's locale.
  ///
  /// [Nullable]
  final String? localizedSubscriptionPeriod;

  /// A formatted number of periods of a discount for a user's locale.
  ///
  /// [Nullable]
  final String? localizedNumberOfPeriods;

  const AdaptySubscriptionPhase._(
    this.category,
    this.price,
    this.identifier,
    this.recurrenceMode,
    this.numberOfPeriods,
    this.paymentMode,
    this.subscriptionPeriod,
    this.localizedSubscriptionPeriod,
    this.localizedNumberOfPeriods,
  );

  @override
  String toString() => '(category: $category, '
      'price: $price, '
      'identifier: $identifier, '
      'recurrenceMode: $recurrenceMode, '
      'numberOfPeriods: $numberOfPeriods, '
      'paymentMode: $paymentMode, '
      'subscriptionPeriod: $subscriptionPeriod, '
      'localizedSubscriptionPeriod: $localizedSubscriptionPeriod, '
      'localizedNumberOfPeriods: $localizedNumberOfPeriods)';
}

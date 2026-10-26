import 'package:meta/meta.dart' show immutable;

import 'adapty_price.dart';
import 'adapty_subscription_period.dart';

part 'private/adapty_subscription_commitment_info_json_builder.dart';

/// The total price and period a user commits to with a billing plan.
///
/// For a product billed up front, the commitment is one subscription period at the product's
/// price.
@immutable
class AdaptySubscriptionCommitmentInfo {
  /// The total price of the commitment, for example the sum of 12 monthly installments.
  final AdaptyPrice price;

  /// The total period of the commitment, for example 1 year.
  final AdaptySubscriptionPeriod period;

  const AdaptySubscriptionCommitmentInfo._(this.price, this.period);

  @override
  String toString() =>
      '(price: $price, '
      'period: $period)';
}

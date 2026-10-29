import 'package:meta/meta.dart' show immutable;

import 'adapty_price.dart';
import 'adapty_subscription_billing_plan.dart';
import 'adapty_subscription_commitment_info.dart';
import 'adapty_subscription_period.dart';

part 'private/adapty_subscription_pricing_terms_json_builder.dart';

/// How a subscription product is billed: its billing plan, the payment for each billing
/// period, and the total the user commits to. Read it from
/// [AdaptyProductSubscription.pricingTerms].
@immutable
class AdaptySubscriptionPricingTerms {
  /// The billing plan these terms describe.
  final AdaptySubscriptionBillingPlan billingPlan;

  /// The price charged for each billing period, for example the monthly installment.
  final AdaptyPrice billingPrice;

  /// The time between two payments.
  final AdaptySubscriptionPeriod billingPeriod;

  /// The total price and period the user commits to.
  final AdaptySubscriptionCommitmentInfo commitmentInfo;

  const AdaptySubscriptionPricingTerms._(this.billingPlan, this.billingPrice, this.billingPeriod, this.commitmentInfo);

  @override
  String toString() =>
      '(billingPlan: $billingPlan, '
      'billingPrice: $billingPrice, '
      'billingPeriod: $billingPeriod, '
      'commitmentInfo: $commitmentInfo)';
}

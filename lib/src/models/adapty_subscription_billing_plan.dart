import 'package:meta/meta.dart' show immutable;

part 'private/adapty_subscription_billing_plan_json_builder.dart';

/// How a subscription is billed: in full for each period, or in installments over a
/// commitment.
///
/// The set of plans is open. A plan this version has no constant for keeps its [value], so
/// compare against the constants rather than expecting only them.
@immutable
class AdaptySubscriptionBillingPlan {
  /// The plan identifier, for example `up_front` or `monthly`.
  final String value;

  /// A plan with the given [value]. Equal to the constant with the same value, if there is one.
  const AdaptySubscriptionBillingPlan(this.value);

  /// The whole price of each subscription period is paid at its start: the way every
  /// subscription is billed unless its product offers another plan.
  static const upFront = AdaptySubscriptionBillingPlan('up_front');

  /// The user commits to 12 months of the subscription and pays for them in monthly
  /// installments. iOS only; see [AdaptyProductSubscription.pricingTerms] for what it needs.
  static const monthly = AdaptySubscriptionBillingPlan('monthly');

  @override
  bool operator ==(Object other) => other is AdaptySubscriptionBillingPlan && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AdaptySubscriptionBillingPlan($value)';
}

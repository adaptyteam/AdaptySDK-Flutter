import 'package:meta/meta.dart' show immutable;

import 'private/json_builder.dart';

part 'private/adapty_profile_subscription_commitment_info_json_builder.dart';

/// The progress of a subscription bought with a commitment billing plan, such as
/// [AdaptySubscriptionBillingPlan.monthly].
@immutable
class AdaptyProfileSubscriptionCommitmentInfo {
  /// The number of the current billing period within the commitment.
  final int billingPeriodNumber;

  /// The number of billing periods in the whole commitment, for example 12.
  final int totalBillingPeriods;

  /// The time when the whole commitment ends.
  final DateTime expiresAt;

  const AdaptyProfileSubscriptionCommitmentInfo._(this.billingPeriodNumber, this.totalBillingPeriods, this.expiresAt);

  @override
  String toString() =>
      '(billingPeriodNumber: $billingPeriodNumber, '
      'totalBillingPeriods: $totalBillingPeriods, '
      'expiresAt: $expiresAt)';
}

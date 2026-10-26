part of '../adapty_profile_subscription_commitment_info.dart';

extension AdaptyProfileSubscriptionCommitmentInfoJSONBuilder on AdaptyProfileSubscriptionCommitmentInfo {
  static AdaptyProfileSubscriptionCommitmentInfo fromJsonValue(Map<String, dynamic> json) {
    return AdaptyProfileSubscriptionCommitmentInfo._(
      json.integer(_Keys.billingPeriodNumber),
      json.integer(_Keys.totalBillingPeriods),
      json.dateTime(_Keys.expiresAt),
    );
  }
}

class _Keys {
  static const billingPeriodNumber = 'billing_period_number';
  static const totalBillingPeriods = 'total_billing_periods';
  static const expiresAt = 'expires_at';
}

extension MapExtension on Map<String, dynamic> {
  AdaptyProfileSubscriptionCommitmentInfo? profileSubscriptionCommitmentInfoIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyProfileSubscriptionCommitmentInfoJSONBuilder.fromJsonValue(value);
  }
}

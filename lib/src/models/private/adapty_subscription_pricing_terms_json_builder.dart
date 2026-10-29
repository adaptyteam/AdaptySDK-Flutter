part of '../adapty_subscription_pricing_terms.dart';

extension AdaptySubscriptionPricingTermsJSONBuilder on AdaptySubscriptionPricingTerms {
  static AdaptySubscriptionPricingTerms fromJsonValue(Map<String, dynamic> json) {
    return AdaptySubscriptionPricingTerms._(
      json.subscriptionBillingPlan(_Keys.billingPlan),
      json.price(_Keys.billingPrice),
      json.subscriptionPeriod(_Keys.billingPeriod),
      json.subscriptionCommitmentInfo(_Keys.commitmentInfo),
    );
  }
}

class _Keys {
  static const billingPlan = 'billing_plan_id';
  static const billingPrice = 'billing_price';
  static const billingPeriod = 'billing_period';
  static const commitmentInfo = 'commitment_info';
}

extension MapExtension on Map<String, dynamic> {
  AdaptySubscriptionPricingTerms? subscriptionPricingTermsIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptySubscriptionPricingTermsJSONBuilder.fromJsonValue(value);
  }
}

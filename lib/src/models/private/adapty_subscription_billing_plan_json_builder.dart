part of '../adapty_subscription_billing_plan.dart';

extension MapExtension on Map<String, dynamic> {
  AdaptySubscriptionBillingPlan subscriptionBillingPlan(String key) {
    return AdaptySubscriptionBillingPlan(this[key] as String);
  }

  AdaptySubscriptionBillingPlan? subscriptionBillingPlanIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptySubscriptionBillingPlan(value as String);
  }
}

//
//  adapty_product_subscription_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 20.07.2023.
//

part of '../adapty_product_subscription.dart';

extension AdaptyProductSubscriptionJSONBuilder on AdaptyProductSubscription {
  /// The `subscription` object of a product sent back to the native side: the billing plan and
  /// the offer the product carries, never the rest of its pricing terms. `null` when the product
  /// carries neither, so the key is left out.
  Map<String, dynamic>? get requestJsonValue {
    final billingPlan = pricingTerms?.billingPlan;
    final offerIdentifier = offer?.identifier;
    if (billingPlan == null && offerIdentifier == null) return null;

    return {
      if (billingPlan != null) _Keys.pricingTerms: {_Keys.billingPlan: billingPlan.value},
      if (offerIdentifier != null) _Keys.offer: {_Keys.offerIdentifier: offerIdentifier.jsonValue},
    };
  }

  static AdaptyProductSubscription fromJsonValue(Map<String, dynamic> json) {
    return AdaptyProductSubscription._(
      json.stringIfPresent(_Keys.groupIdentifier),
      json.subscriptionPeriod(_Keys.period),
      json.stringIfPresent(_Keys.localizedPeriod),
      json.subscriptionOfferIfPresent(_Keys.offer),
      json.renewalTypeIfPresent(_Keys.renewalType) ?? AdaptyRenewalType.autorenewable,
      json.stringIfPresent(_Keys.basePlanId),
      json.subscriptionPricingTermsIfPresent(_Keys.pricingTerms),
    );
  }
}

class _Keys {
  static const groupIdentifier = 'group_identifier';
  static const period = 'period';
  static const localizedPeriod = 'localized_period';
  static const offer = 'offer';
  static const renewalType = 'renewal_type';
  static const basePlanId = 'base_plan_id';
  static const pricingTerms = 'pricing_terms';
  static const billingPlan = 'billing_plan_id';
  static const offerIdentifier = 'offer_identifier';
}

extension MapExtension on Map<String, dynamic> {
  AdaptyProductSubscription? productSubscriptionIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyProductSubscriptionJSONBuilder.fromJsonValue(value);
  }
}

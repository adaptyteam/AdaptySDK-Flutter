//
//  adapty_subscription_details_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 20.07.2023.
//

part of '../adapty_subscription_details.dart';

extension AdaptySubscriptionDetailsJSONBuilder on AdaptySubscriptionDetails {
  static AdaptySubscriptionDetails fromJsonValue(Map<String, dynamic> json) {
    return AdaptySubscriptionDetails._(
      json.stringIfPresent(_Keys.subscriptionGroupIdentifier),
      AdaptySDKNative.isAndroid ? json.eligibility(_Keys.androidIntroductoryOfferEligibility) : null,
      AdaptySDKNative.isAndroid ? json.stringIfPresent(_Keys.androidBasePlanId) : null,
      AdaptySDKNative.isAndroid ? json.stringIfPresent(_Keys.androidOfferId) : null,
      (AdaptySDKNative.isAndroid ? json.stringListIfPresent(_Keys.androidOfferTags) : null) ?? [],
      json.subscriptionPhaseListIfPresent(_Keys.introductoryOfferPhases) ?? [],
      json.subscriptionPhaseIfPresent(_Keys.promotionalOffer),
      json.renewalTypeIfPresent(_Keys.renewalType) ?? AdaptyRenewalType.autorenewable,
      json.subscriptionPeriod(_Keys.subscriptionPeriod),
      json.stringIfPresent(_Keys.localizedSubscriptionPeriod),
    );
  }
}

class _Keys {
  static const subscriptionGroupIdentifier = 'subscription_group_identifier';
  static const androidIntroductoryOfferEligibility = 'introductory_offer_eligibility';
  static const androidOfferId = 'android_offer_id';
  static const androidBasePlanId = 'android_base_plan_id';
  static const androidOfferTags = 'android_offer_tags';
  static const introductoryOfferPhases = 'introductory_offer_phases';
  static const promotionalOffer = 'promotional_offer';
  static const subscriptionPeriod = 'subscription_period';
  static const localizedSubscriptionPeriod = 'localized_subscription_period';
  static const renewalType = 'renewal_type';
}

extension MapExtension on Map<String, dynamic> {
  AdaptySubscriptionDetails? subscriptionDetailsIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptySubscriptionDetailsJSONBuilder.fromJsonValue(value);
  }
}

//
//  adapty_subscription_details_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 20.07.2023.
//

part of '../adapty_subscription_details.dart';

extension AdaptySubscriptionDetailsJSONBuilder on AdaptySubscriptionDetails {
  static AdaptySubscriptionDetails fromJsonValue(Map<String, dynamic> json) {
    List<dynamic> list = json[_Keys.subscriptionPhases];
    Map<String, dynamic> regular = list.firstWhere((e) => e[_Keys.phaseCategory] == 'regular');
    Map<String, dynamic> promotionalOffer = list.firstWhere((e) => e[_Keys.phaseCategory] == 'promotional_offer');
    List<dynamic> introductoryOffer = list.where((e) => e[_Keys.phaseCategory] == 'introductory_offer').toList(growable: false);

    return AdaptySubscriptionDetails._(
      json.stringIfPresent(_Keys.subscriptionGroupIdentifier),
      AdaptySDKNative.isAndroid ? json.eligibility(_Keys.androidIntroductoryOfferEligibility) : null,
      (AdaptySDKNative.isAndroid ? json.stringListIfPresent(_Keys.offerTags) : null) ?? [],
      introductoryOffer.asSubscriptionPhases,
      promotionalOffer != null ? promotionalOffer.asSubscriptionPhase : null,
      regular.subscriptionPeriod(_Keys.subscriptionPeriod),
      regular.stringIfPresent(_Keys.localizedSubscriptionPeriod),
    );
  }
}

class _Keys {
  static const subscriptionGroupIdentifier = 'subscription_group_identifier';
  static const androidIntroductoryOfferEligibility = 'introductory_offer_eligibility';
  static const offerTags = 'offer_tags';
  static const subscriptionPhases = 'subscription_phases';
  static const phaseCategory = 'phase_category';
  static const subscriptionPeriod = 'subscription_period';
  static const localizedSubscriptionPeriod = 'localized_subscription_period';
}

extension MapExtension on Map<String, dynamic> {
  AdaptySubscriptionDetails subscriptionDetails(String key) => AdaptySubscriptionDetailsJSONBuilder.fromJsonValue(this[key]);
}

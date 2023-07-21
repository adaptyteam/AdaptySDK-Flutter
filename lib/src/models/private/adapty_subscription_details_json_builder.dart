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
      json.string(_Keys.offerId),
      json.stringListIfPresent(_Keys.offerTags) ?? [],
      json.subscriptionPhaseListIfPresent(_Keys.subscriptionPhases) ?? [],
    );
  }
}

class _Keys {
  static const subscriptionGroupIdentifier = 'subscription_group_identifier';
  static const androidIntroductoryOfferEligibility = 'introductory_offer_eligibility';
  static const offerId = 'offer_id';
  static const offerTags = 'offer_tags';
  static const subscriptionPhases = 'subscription_phases';
}

extension MapExtension on Map<String, dynamic> {
  AdaptySubscriptionDetails subscriptionDetails(String key) => AdaptySubscriptionDetailsJSONBuilder.fromJsonValue(this[key]);
}

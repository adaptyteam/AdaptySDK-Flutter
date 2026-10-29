part of '../adapty_subscription_commitment_info.dart';

extension AdaptySubscriptionCommitmentInfoJSONBuilder on AdaptySubscriptionCommitmentInfo {
  static AdaptySubscriptionCommitmentInfo fromJsonValue(Map<String, dynamic> json) {
    return AdaptySubscriptionCommitmentInfo._(json.price(_Keys.price), json.subscriptionPeriod(_Keys.period));
  }
}

class _Keys {
  static const price = 'price';
  static const period = 'period';
}

extension MapExtension on Map<String, dynamic> {
  AdaptySubscriptionCommitmentInfo subscriptionCommitmentInfo(String key) {
    return AdaptySubscriptionCommitmentInfoJSONBuilder.fromJsonValue(this[key]);
  }
}

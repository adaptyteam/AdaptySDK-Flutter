//
//  adapty_non_subscription_details_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 20.07.2023.
//

part of '../adapty_non_subscription_details.dart';

extension AdaptyNonSubscriptionDetailsJSONBuilder on AdaptyNonSubscriptionDetails {
  static AdaptyNonSubscriptionDetails fromJsonValue(Map<String, dynamic> json) {
    return AdaptyNonSubscriptionDetails._(
      json.price(_Keys.price),
    );
  }
}

class _Keys {
  static const price = 'price';
}

extension MapExtension on Map<String, dynamic> {
  AdaptyNonSubscriptionDetails nonSubscriptionDetails(String key) => AdaptyNonSubscriptionDetailsJSONBuilder.fromJsonValue(this[key]);
}

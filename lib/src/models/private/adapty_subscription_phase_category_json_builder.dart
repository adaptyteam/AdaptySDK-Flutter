//
//  adapty_subscription_phase_category_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 21.07.2023.
//

part of '../adapty_subscription_phase_category.dart';

extension AdaptySubscriptionPhaseCategoryJSONBuilder on AdaptySubscriptionPhaseCategory {
  dynamic get jsonValue {
    switch (this) {
      case AdaptySubscriptionPhaseCategory.introductoryOffer:
        return _Keys.introductoryOffer;
      case AdaptySubscriptionPhaseCategory.promotionalOffer:
        return _Keys.promotionalOffer;
      case AdaptySubscriptionPhaseCategory.regular:
        return _Keys.regular;
    }
  }

  static AdaptySubscriptionPhaseCategory fromJsonValue(String json) {
    switch (json) {
      case _Keys.introductoryOffer:
        return AdaptySubscriptionPhaseCategory.introductoryOffer;
      case _Keys.promotionalOffer:
        return AdaptySubscriptionPhaseCategory.promotionalOffer;
      case _Keys.regular:
        return AdaptySubscriptionPhaseCategory.regular;
      default:
        return AdaptySubscriptionPhaseCategory.regular;
    }
  }
}

class _Keys {
  static const introductoryOffer = 'introductory_offer';
  static const promotionalOffer = 'promotional_offer';
  static const regular = 'regular';
}

extension MapExtension on Map<String, dynamic> {
  AdaptySubscriptionPhaseCategory subscriptionPhaseCategory(String key) {
    return AdaptySubscriptionPhaseCategoryJSONBuilder.fromJsonValue(this[key] as String);
  }

  AdaptySubscriptionPhaseCategory? subscriptionPhaseCategoryIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptySubscriptionPhaseCategoryJSONBuilder.fromJsonValue(value);
  }
}

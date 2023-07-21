//
//  adapty_subscription_recurrence_mode_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 21.07.2023.
//

part of '../adapty_subscription_recurrence_mode.dart';

extension AdaptySubscriptionRecurrenceModeJSONBuilder on AdaptySubscriptionRecurrenceMode {
  dynamic get jsonValue {
    switch (this) {
      case AdaptySubscriptionRecurrenceMode.infiniteRecurring:
        return _Keys.infiniteRecurring;
      case AdaptySubscriptionRecurrenceMode.finiteRecurring:
        return _Keys.finiteRecurring;
      case AdaptySubscriptionRecurrenceMode.nonRecurring:
        return _Keys.nonRecurring;
    }
  }

  static AdaptySubscriptionRecurrenceMode fromJsonValue(String json) {
    switch (json) {
      case _Keys.infiniteRecurring:
        return AdaptySubscriptionRecurrenceMode.infiniteRecurring;
      case _Keys.finiteRecurring:
        return AdaptySubscriptionRecurrenceMode.finiteRecurring;
      case _Keys.nonRecurring:
        return AdaptySubscriptionRecurrenceMode.nonRecurring;
      default:
        return AdaptySubscriptionRecurrenceMode.nonRecurring;
    }
  }
}

class _Keys {
  static const infiniteRecurring = 'infinite_recurring';
  static const finiteRecurring = 'finite_recurring';
  static const nonRecurring = 'non_recurring';
}

extension MapExtension on Map<String, dynamic> {
  AdaptySubscriptionRecurrenceMode subscriptionRecurrenceMode(String key) {
    return AdaptySubscriptionRecurrenceModeJSONBuilder.fromJsonValue(this[key] as String);
  }

  AdaptySubscriptionRecurrenceMode? subscriptionRecurrenceModeIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptySubscriptionRecurrenceModeJSONBuilder.fromJsonValue(value);
  }
}

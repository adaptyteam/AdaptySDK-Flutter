//
//  adapty_subscription_phase_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 20.07.2023.
//

part of '../adapty_subscription_phase.dart';

extension AdaptySubscriptionPhaseJSONBuilder on AdaptySubscriptionPhase {
  static AdaptySubscriptionPhase fromJsonValue(Map<String, dynamic> json) {
    return AdaptySubscriptionPhase._(
      json.price(_Keys.price),
      json.stringIfPresent(_Keys.identifier),
      json.subscriptionRecurrenceMode(_Keys.recurrenceMode),
      json.integer(_Keys.numberOfPeriods),
      json.paymentModeIfPresent(_Keys.paymentMode) ?? AdaptyPaymentMode.unknown,
      json.subscriptionPeriod(_Keys.subscriptionPeriod),
      json.stringIfPresent(_Keys.localizedSubscriptionPeriod),
      json.stringIfPresent(_Keys.localizedNumberOfPeriods),
    );
  }
}

class _Keys {
  static const price = 'price';
  static const identifier = 'identifier';
  static const recurrenceMode = 'recurrence_mode';
  static const numberOfPeriods = 'number_of_periods';
  static const paymentMode = 'payment_mode';
  static const subscriptionPeriod = 'subscription_period';
  static const localizedSubscriptionPeriod = 'localized_subscription_period';
  static const localizedNumberOfPeriods = 'localized_number_of_periods';
}

extension MapExtension on Map<String, dynamic> {
  AdaptySubscriptionPhase get asSubscriptionPhase => AdaptySubscriptionPhaseJSONBuilder.fromJsonValue(this);
}

extension ListExtension on List<dynamic> {
  List<AdaptySubscriptionPhase> get asSubscriptionPhases => this.map((e) => AdaptySubscriptionPhaseJSONBuilder.fromJsonValue(e)).toList(growable: false);
}

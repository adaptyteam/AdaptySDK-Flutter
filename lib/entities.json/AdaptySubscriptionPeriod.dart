//
//  AdaptySubscriptionPeriod.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//
import '../entities/AdaptySubscriptionPeriod.dart';
import 'AdaptyPeriodUnit.dart';

extension AdaptySubscriptionPeriodExtension on AdaptySubscriptionPeriod {
  static const _unit = 'unit';
  static const _numberOfUnits = 'number_of_units';

  Map<String, dynamic> jsonValue() {
    return {
      _unit: unit.stringValue(),
      _numberOfUnits: numberOfUnits,
    };
  }

  static AdaptySubscriptionPeriod fromJsonValue(Map<String, dynamic> json) {
    return AdaptySubscriptionPeriod(json.periodUnit(_unit), json[_numberOfUnits]);
  }
}

extension MapExtension on Map<String, dynamic> {
  AdaptySubscriptionPeriod subscriptionPeriod(String key) {
    return AdaptySubscriptionPeriodExtension.fromJsonValue(this[key]);
  }

  AdaptySubscriptionPeriod? subscriptionPeriodIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptySubscriptionPeriodExtension.fromJsonValue(value);
  }
}

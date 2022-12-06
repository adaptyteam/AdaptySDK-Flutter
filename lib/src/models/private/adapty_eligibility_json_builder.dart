//
//  adapty_eligibility_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../adapty_eligibility.dart';

extension AdaptyEligibilityJSONBuilder on AdaptyEligibility {
  dynamic get jsonValue {
    switch (this) {
      case AdaptyEligibility.unknown:
        return _Keys.unknown;
      case AdaptyEligibility.ineligible:
        return _Keys.ineligible;
      case AdaptyEligibility.eligible:
        return _Keys.eligible;
    }
  }

  static AdaptyEligibility fromJsonValue(String json) {
    switch (json) {
      case _Keys.ineligible:
        return AdaptyEligibility.ineligible;
      case _Keys.eligible:
        return AdaptyEligibility.eligible;
      default:
        return AdaptyEligibility.unknown;
    }
  }
}

class _Keys {
  static const unknown = 'unknown';
  static const ineligible = 'ineligible';
  static const eligible = 'eligible';
}

extension MapExtension on Map<String, dynamic> {
  AdaptyEligibility eligibility(String key) {
    return AdaptyEligibilityJSONBuilder.fromJsonValue(this[key] as String);
  }

  AdaptyEligibility? eligibilityIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyEligibilityJSONBuilder.fromJsonValue(value);
  }
}

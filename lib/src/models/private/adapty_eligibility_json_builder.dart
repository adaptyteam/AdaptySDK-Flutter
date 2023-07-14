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
      case AdaptyEligibility.ineligible:
        return _Keys.ineligible;
      case AdaptyEligibility.eligible:
        return _Keys.eligible;
      case AdaptyEligibility.notApplicable:
        return _Keys.notApplicable;
    }
  }

  static AdaptyEligibility fromJsonValue(String json) {
    switch (json) {
      case _Keys.ineligible:
        return AdaptyEligibility.ineligible;
      case _Keys.eligible:
        return AdaptyEligibility.eligible;
      case _Keys.notApplicable:
        return AdaptyEligibility.notApplicable;
      default:
        return AdaptyEligibility.ineligible;
    }
  }
}

class _Keys {
  static const ineligible = 'ineligible';
  static const eligible = 'eligible';
  static const notApplicable = 'not_applicable';
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

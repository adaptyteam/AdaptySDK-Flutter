//
//  AdaptyEligibility.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of  '../entities/AdaptyEligibility.dart';

extension AdaptyEligibilityExtension on AdaptyEligibility {
  static const _unknown = 'unknown';
  static const _ineligible = 'ineligible';
  static const _eligible = 'eligible';

  String stringValue() {
    switch (this) {
      case AdaptyEligibility.unknown:
        return _unknown;
      case AdaptyEligibility.ineligible:
        return _ineligible;
      case AdaptyEligibility.eligible:
        return _eligible;
    }
  }

  static AdaptyEligibility fromStringValue(String value) {
    switch (value) {
      case _ineligible:
        return AdaptyEligibility.ineligible;
      case _eligible:
        return AdaptyEligibility.eligible;
      default:
        return AdaptyEligibility.unknown;
    }
  }
}

extension MapExtension on Map<String, dynamic> {
  AdaptyEligibility eligibility(String key) {
    return AdaptyEligibilityExtension.fromStringValue(this[key] as String);
  }

  AdaptyEligibility? eligibilityIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyEligibilityExtension.fromStringValue(value);
  }
}

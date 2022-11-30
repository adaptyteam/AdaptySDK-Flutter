//
//  AdaptyProfileGenderJSONBuilder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../entities/AdaptyProfileGender.dart';

extension AdaptyProfileGenderJSONBuilder on AdaptyProfileGender {
  String jsonValue() {
    switch (this) {
      case AdaptyProfileGender.female:
        return _Keys.female;
      case AdaptyProfileGender.male:
        return _Keys.male;
      case AdaptyProfileGender.other:
        return _Keys.other;
    }
  }

  static AdaptyProfileGender fromJsonValue(String json) {
    switch (json) {
      case _Keys.female:
        return AdaptyProfileGender.female;
      case _Keys.male:
        return AdaptyProfileGender.male;
      default:
        return AdaptyProfileGender.other;
    }
  }
}

class _Keys {
  static const female = 'f';
  static const male = 'm';
  static const other = 'o';
}

extension MapExtension on Map<String, dynamic> {
  AdaptyProfileGender gender(String key) {
    return AdaptyProfileGenderJSONBuilder.fromJsonValue(this[key] as String);
  }

  AdaptyProfileGender? genderIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyProfileGenderJSONBuilder.fromJsonValue(value);
  }
}

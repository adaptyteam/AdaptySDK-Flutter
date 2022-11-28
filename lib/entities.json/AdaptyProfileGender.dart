//
//  AdaptyProfileGender.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of  '../entities/AdaptyProfileGender.dart';

extension AdaptyProfileGenderExtension on AdaptyProfileGender {
  static const _female = 'f';
  static const _male = 'm';
  static const _other = 'o';

  String stringValue() {
    switch (this) {
      case AdaptyProfileGender.female:
        return _female;
      case AdaptyProfileGender.male:
        return _male;
      case AdaptyProfileGender.other:
        return _other;
    }
  }

  static AdaptyProfileGender fromStringValue(String value) {
    switch (value) {
      case _female:
        return AdaptyProfileGender.female;
      case _male:
        return AdaptyProfileGender.male;
      default:
        return AdaptyProfileGender.other;
    }
  }
}

extension MapExtension on Map<String, dynamic> {
  AdaptyProfileGender gender(String key) {
    return AdaptyProfileGenderExtension.fromStringValue(this[key] as String);
  }

  AdaptyProfileGender? genderIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyProfileGenderExtension.fromStringValue(value);
  }
}

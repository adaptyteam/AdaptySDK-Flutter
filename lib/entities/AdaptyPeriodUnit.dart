//
//  AdaptyPeriodUnit.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

enum AdaptyPeriodUnit {
  day,
  week,
  month,
  year,
  unknown,
}

extension AdaptyPeriodUnitExtension on AdaptyPeriodUnit {
  static const _day = 'day';
  static const _week = 'week';
  static const _month = 'month';
  static const _year = "year";
  static const _unknown = "unknown";

  String stringValue() {
    switch (this) {
      case AdaptyPeriodUnit.day:
        return _day;
      case AdaptyPeriodUnit.week:
        return _week;
      case AdaptyPeriodUnit.month:
        return _month;
      case AdaptyPeriodUnit.year:
        return _year;
      case AdaptyPeriodUnit.unknown:
        return _unknown;
    }
  }

  static AdaptyPeriodUnit fromStringValue(String value) {
    switch (value) {
      case _day:
        return AdaptyPeriodUnit.day;
      case _week:
        return AdaptyPeriodUnit.week;
      case _month:
        return AdaptyPeriodUnit.month;
      case _year:
        return AdaptyPeriodUnit.year;
      default:
        return AdaptyPeriodUnit.unknown;
    }
  }
}

extension MapExtension on Map<String, dynamic> {
  AdaptyPeriodUnit periodUnit(String key) {
    return AdaptyPeriodUnitExtension.fromStringValue(this[key] as String);
  }

  AdaptyPeriodUnit? periodUnitIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyPeriodUnitExtension.fromStringValue(value);
  }
}

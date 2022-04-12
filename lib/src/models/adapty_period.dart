import 'adapty_enums.dart';

class AdaptyPeriod {
  /// The unit of time that a subscription period is specified in.
  /// The possible values are: day, week, month, year.
  final AdaptyPeriodUnit unit;

  /// The number of period units.
  final int? numberOfUnits;

  AdaptyPeriod.fromJson(Map<String, dynamic> json)
      : unit = periodUnitFromInt(json['unit']),
        numberOfUnits = json['numberOfUnits'];

  @override
  String toString() => 'unit: $unit, numberOfUnits: $numberOfUnits';
}

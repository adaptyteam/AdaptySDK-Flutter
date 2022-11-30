//
//  AdaptySubscriptionPeriod.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//
import 'package:meta/meta.dart' show immutable;
import 'AdaptyPeriodUnit.dart';

part '../entities.json/AdaptySubscriptionPeriodJSONBuilder.dart';

@immutable
class AdaptySubscriptionPeriod {
  /// The unit of time that a subscription period is specified in.
  /// The possible values are: day, week, month, year.
  final AdaptyPeriodUnit unit;

  /// The number of period units.
  final int numberOfUnits;

  const AdaptySubscriptionPeriod._(this.unit, this.numberOfUnits,);

  @override
  String toString() => '(unit: $unit, numberOfUnits: $numberOfUnits)';
}

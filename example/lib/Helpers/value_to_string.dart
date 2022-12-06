import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:intl/intl.dart';

String valueToString(dynamic value) {
  if (value == null) {
    return 'null';
  }
  if (value is String) {
    return value;
  } else if (value is num) {
    return value.toString();
  } else if (value is DateTime) {
    final localDate = value.toLocal();
    return DateFormat.yMd().add_Hm().format(localDate) + localDate.timeZoneName;
  } else if (value is bool) {
    return value.toString();
  }
  return value.toString();
}

String adaptyPeriodToString(AdaptySubscriptionPeriod? adaptyPeriod) {
  if (adaptyPeriod == null) {
    return 'null';
  }
  final periodUnit = adaptyPeriod.unit;
  String periodUnitStr;
  switch (periodUnit) {
    case AdaptyPeriodUnit.day:
      periodUnitStr = 'day(s)';
      break;
    case AdaptyPeriodUnit.week:
      periodUnitStr = 'week(s)';
      break;
    case AdaptyPeriodUnit.month:
      periodUnitStr = 'month(s)';
      break;
    case AdaptyPeriodUnit.year:
      periodUnitStr = 'year(s)';
      break;
    default:
      return 'Unknown';
  }
  return '${adaptyPeriod.numberOfUnits} $periodUnitStr';
}

extension AdaptyPaymentModeExtension on AdaptyPaymentMode {
  String toReadableString() {
    switch (this) {
      case AdaptyPaymentMode.freeTrial:
        return 'freeTrial';
      case AdaptyPaymentMode.payAsYouGo:
        return 'payAsYouGo';
      case AdaptyPaymentMode.payUpFront:
        return 'payUpFront';
      default:
        return 'unknown';
    }
  }
}

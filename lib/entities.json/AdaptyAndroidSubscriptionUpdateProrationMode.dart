//
//  AdaptySubscriptionUpdateParametersProrationMode.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import '../entities/AdaptyAndroidSubscriptionUpdateProrationMode.dart';

extension AdaptyAndroidSubscriptionUpdateProrationModeExtension on AdaptyAndroidSubscriptionUpdateProrationMode {
  static const String _immediateWithTimeProration = "immediate_with_time_proration";
  static const String _immediateAndChargeProratedPrice = "immediate_and_charge_prorated_price";
  static const String _immediateWithoutProration = "immediate_without_proration";
  static const String _deferred = "deferred";
  static const String _immediateAndChargeFullPrice = "immediate_and_charge_full_price";

  String stringValue() {
    switch (this) {
      case AdaptyAndroidSubscriptionUpdateProrationMode.immediateWithTimeProration:
        return _immediateWithTimeProration;
      case AdaptyAndroidSubscriptionUpdateProrationMode.immediateAndChargeProratedPrice:
        return _immediateAndChargeProratedPrice;
      case AdaptyAndroidSubscriptionUpdateProrationMode.immediateWithoutProration:
        return _immediateWithoutProration;
      case AdaptyAndroidSubscriptionUpdateProrationMode.deferred:
        return _deferred;
      case AdaptyAndroidSubscriptionUpdateProrationMode.immediateAndChargeFullPrice:
        return _immediateAndChargeFullPrice;
    }
  }

  static AdaptyAndroidSubscriptionUpdateProrationMode fromStringValue(String value) {
    switch (value) {
      case _immediateWithTimeProration:
        return AdaptyAndroidSubscriptionUpdateProrationMode.immediateWithTimeProration;
      case _immediateAndChargeProratedPrice:
        return AdaptyAndroidSubscriptionUpdateProrationMode.immediateAndChargeProratedPrice;
      case _immediateWithoutProration:
        return AdaptyAndroidSubscriptionUpdateProrationMode.immediateWithoutProration;
      case _deferred:
        return AdaptyAndroidSubscriptionUpdateProrationMode.deferred;
      case _immediateAndChargeFullPrice:
        return AdaptyAndroidSubscriptionUpdateProrationMode.immediateAndChargeFullPrice;
      default:
        throw FormatException("Unknown AdaptyAndroidSubscriptionUpdateProrationMode value == $value");
    }
  }
}

extension MapExtension on Map<String, dynamic> {
  AdaptyAndroidSubscriptionUpdateProrationMode androidSubscriptionUpdateProrationMode(String key) {
    return AdaptyAndroidSubscriptionUpdateProrationModeExtension.fromStringValue(this[key] as String);
  }

  AdaptyAndroidSubscriptionUpdateProrationMode? androidSubscriptionUpdateProrationModeIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyAndroidSubscriptionUpdateProrationModeExtension.fromStringValue(value);
  }
}

//
//  AdaptyAndroidSubscriptionUpdateProrationModeJSONBuilder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../entities/AdaptyAndroidSubscriptionUpdateProrationMode.dart';

extension AdaptyAndroidSubscriptionUpdateProrationModeJSONBuilder on AdaptyAndroidSubscriptionUpdateProrationMode {
  String jsonValue() {
    switch (this) {
      case AdaptyAndroidSubscriptionUpdateProrationMode.immediateWithTimeProration:
        return _Keys.immediateWithTimeProration;
      case AdaptyAndroidSubscriptionUpdateProrationMode.immediateAndChargeProratedPrice:
        return _Keys.immediateAndChargeProratedPrice;
      case AdaptyAndroidSubscriptionUpdateProrationMode.immediateWithoutProration:
        return _Keys.immediateWithoutProration;
      case AdaptyAndroidSubscriptionUpdateProrationMode.deferred:
        return _Keys.deferred;
      case AdaptyAndroidSubscriptionUpdateProrationMode.immediateAndChargeFullPrice:
        return _Keys.immediateAndChargeFullPrice;
    }
  }

  static AdaptyAndroidSubscriptionUpdateProrationMode fromJsonValue(String json) {
    switch (json) {
      case _Keys.immediateWithTimeProration:
        return AdaptyAndroidSubscriptionUpdateProrationMode.immediateWithTimeProration;
      case _Keys.immediateAndChargeProratedPrice:
        return AdaptyAndroidSubscriptionUpdateProrationMode.immediateAndChargeProratedPrice;
      case _Keys.immediateWithoutProration:
        return AdaptyAndroidSubscriptionUpdateProrationMode.immediateWithoutProration;
      case _Keys.deferred:
        return AdaptyAndroidSubscriptionUpdateProrationMode.deferred;
      case _Keys.immediateAndChargeFullPrice:
        return AdaptyAndroidSubscriptionUpdateProrationMode.immediateAndChargeFullPrice;
      default:
        throw FormatException("Unknown AdaptyAndroidSubscriptionUpdateProrationMode value == $json");
    }
  }
}

class _Keys {
  static const String immediateWithTimeProration = "immediate_with_time_proration";
  static const String immediateAndChargeProratedPrice = "immediate_and_charge_prorated_price";
  static const String immediateWithoutProration = "immediate_without_proration";
  static const String deferred = "deferred";
  static const String immediateAndChargeFullPrice = "immediate_and_charge_full_price";
}

extension MapExtension on Map<String, dynamic> {
  AdaptyAndroidSubscriptionUpdateProrationMode androidSubscriptionUpdateProrationMode(String key) {
    return AdaptyAndroidSubscriptionUpdateProrationModeJSONBuilder.fromJsonValue(this[key] as String);
  }

  AdaptyAndroidSubscriptionUpdateProrationMode? androidSubscriptionUpdateProrationModeIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyAndroidSubscriptionUpdateProrationModeJSONBuilder.fromJsonValue(value);
  }
}

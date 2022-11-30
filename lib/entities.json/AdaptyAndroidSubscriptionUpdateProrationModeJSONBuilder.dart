//
//  AdaptyAndroidSubscriptionUpdateProrationModeJSONBuilder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../entities/AdaptyAndroidSubscriptionUpdateProrationMode.dart';

extension AdaptyAndroidSubscriptionUpdateProrationModeJSONBuilder on AdaptyAndroidSubscriptionUpdateProrationMode {
  dynamic jsonValue() {
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
}

class _Keys {
  static const String immediateWithTimeProration = "immediate_with_time_proration";
  static const String immediateAndChargeProratedPrice = "immediate_and_charge_prorated_price";
  static const String immediateWithoutProration = "immediate_without_proration";
  static const String deferred = "deferred";
  static const String immediateAndChargeFullPrice = "immediate_and_charge_full_price";
}

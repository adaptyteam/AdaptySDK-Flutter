//
//  AdaptySubscriptionUpdateParametersJSONBuilder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../entities/AdaptySubscriptionUpdateParameters.dart';

extension AdaptySubscriptionUpdateParametersJSONBuilder on AdaptySubscriptionUpdateParameters {
  Map<String, dynamic> jsonValue() {
    return {
      _Keys.oldSubVendorProductId: oldSubVendorProductId,
      _Keys.prorationMode: prorationMode,
    };
  }

  static AdaptySubscriptionUpdateParameters fromJsonValue(Map<String, dynamic> json) {
    return AdaptySubscriptionUpdateParameters._(
      json[_Keys.oldSubVendorProductId],
      json.androidSubscriptionUpdateProrationMode(_Keys.prorationMode),
    );
  }
}

class _Keys {
  static const oldSubVendorProductId = 'old_sub_vendor_product_id';
  static const prorationMode = 'proration_mode';
}

extension MapExtension on Map<String, dynamic> {
  AdaptySubscriptionUpdateParameters subscriptionPeriod(String key) {
    return AdaptySubscriptionUpdateParametersJSONBuilder.fromJsonValue(this[key]);
  }

  AdaptySubscriptionUpdateParameters? subscriptionPeriodIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptySubscriptionUpdateParametersJSONBuilder.fromJsonValue(value);
  }
}

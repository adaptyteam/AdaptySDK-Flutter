//
//  AdaptySubscriptionUpdateParameters.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import '../entities/AdaptySubscriptionUpdateParameters.dart';
import 'AdaptyAndroidSubscriptionUpdateProrationMode.dart';

extension AdaptySubscriptionUpdateParametersExtension on AdaptySubscriptionUpdateParameters {
  static const _oldSubVendorProductId = 'old_sub_vendor_product_id';
  static const _prorationMode = 'proration_mode';

  Map<String, dynamic> jsonValue() {
    return {
      _oldSubVendorProductId: oldSubVendorProductId,
      _prorationMode: prorationMode,
    };
  }

  static AdaptySubscriptionUpdateParameters fromJsonValue(Map<String, dynamic> json) {
    return AdaptySubscriptionUpdateParameters(
      json[_oldSubVendorProductId],
      json.androidSubscriptionUpdateProrationMode(_prorationMode),
    );
  }
}

extension MapExtension on Map<String, dynamic> {
  AdaptySubscriptionUpdateParameters subscriptionPeriod(String key) {
    return AdaptySubscriptionUpdateParametersExtension.fromJsonValue(this[key]);
  }

  AdaptySubscriptionUpdateParameters? subscriptionPeriodIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptySubscriptionUpdateParametersExtension.fromJsonValue(value);
  }
}

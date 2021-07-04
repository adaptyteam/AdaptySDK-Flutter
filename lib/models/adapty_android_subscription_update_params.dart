import 'dart:core';

import 'package:adapty_flutter/models/adapty_enums.dart';
import 'package:flutter/foundation.dart';

class AdaptyAndroidSubscriptionUpdateParams {
  /// The product id for current subscription to change.
  late String _oldSubVendorProductId;

  /// The proration mode for subscription update.
  /// The possible values are: immediateWithTimeProration, immediateAndChargeProratedPrice, immediateWithoutProration, deferred, immediateAndChargeFullPrice.
  late AdaptyAndroidSubscriptionUpdateProrationMode _prorationMode;

  AdaptyAndroidSubscriptionUpdateParams(String oldSubVendorProductId,
      AdaptyAndroidSubscriptionUpdateProrationMode prorationMode) {
    this._oldSubVendorProductId = oldSubVendorProductId;
    this._prorationMode = prorationMode;
  }

  Map<String, String> toMap() => {
    'old_sub_vendor_product_id': _oldSubVendorProductId,
    'proration_mode': describeEnum(_prorationMode)
  };
}

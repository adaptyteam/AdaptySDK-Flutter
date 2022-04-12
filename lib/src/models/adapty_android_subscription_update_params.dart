import 'dart:core';

import 'package:flutter/foundation.dart';

import 'adapty_enums.dart';

class AdaptyAndroidSubscriptionUpdateParams {
  /// The product id for current subscription to change.
  final String oldSubVendorProductId;

  /// The proration mode for subscription update.
  /// The possible values are: immediateWithTimeProration, immediateAndChargeProratedPrice, immediateWithoutProration, deferred, immediateAndChargeFullPrice.
  final AdaptyAndroidSubscriptionUpdateProrationMode prorationMode;

  AdaptyAndroidSubscriptionUpdateParams(
    this.oldSubVendorProductId,
    this.prorationMode,
  );

  Map<String, String> toMap() => {
        _Keys.oldSubVendorProductId: oldSubVendorProductId,
        _Keys.prorationMode: describeEnum(prorationMode),
      };
}

class _Keys {
  static const oldSubVendorProductId = 'old_sub_vendor_product_id';
  static const prorationMode = 'proration_mode';
}

//
//  AdaptySubscriptionUpdateParametersJSONBuilder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../entities/AdaptySubscriptionUpdateParameters.dart';

extension AdaptySubscriptionUpdateParametersJSONBuilder on AdaptySubscriptionUpdateParameters {
  dynamic jsonValue() {
    return {
      _Keys.oldSubVendorProductId: oldSubVendorProductId,
      _Keys.prorationMode: prorationMode,
    };
  }
}

class _Keys {
  static const oldSubVendorProductId = 'old_sub_vendor_product_id';
  static const prorationMode = 'proration_mode';
}
//
//  adapty_android_subscription_update_parameters.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;
import 'adapty_android_subscription_update_proration_mode.dart';

part 'private/adapty_android_subscription_update_parameters_json_builder.dart';

@immutable
class AdaptyAndroidSubscriptionUpdateParameters {
  /// The product id for current subscription to change.
  final String oldSubVendorProductId;

  /// The proration mode for subscription update.
  /// The possible values are: immediateWithTimeProration, immediateAndChargeProratedPrice, immediateWithoutProration, deferred, immediateAndChargeFullPrice.
  final AdaptyAndroidSubscriptionUpdateProrationMode prorationMode;

  const AdaptyAndroidSubscriptionUpdateParameters._(
    this.oldSubVendorProductId,
    this.prorationMode,
  );

  String toString() => '(oldSubVendorProductId: $oldSubVendorProductId, prorationMode: $prorationMode)';
}

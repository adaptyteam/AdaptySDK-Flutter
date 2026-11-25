//
//  adapty_android_subscription_update_parameters.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;
import 'adapty_android_subscription_update_replacement_mode.dart';

part 'private/adapty_android_subscription_update_parameters_json_builder.dart';

@immutable
class AdaptyAndroidSubscriptionUpdateParameters {
  /// The product id for current subscription to change.
  final String oldSubVendorProductId;

  /// The replacement mode for subscription update: one of
  /// [AdaptyAndroidSubscriptionUpdateReplacementMode.withTimeProration],
  /// [AdaptyAndroidSubscriptionUpdateReplacementMode.chargeProratedPrice],
  /// [AdaptyAndroidSubscriptionUpdateReplacementMode.withoutProration],
  /// [AdaptyAndroidSubscriptionUpdateReplacementMode.deferred] and
  /// [AdaptyAndroidSubscriptionUpdateReplacementMode.chargeFullPrice].
  final AdaptyAndroidSubscriptionUpdateReplacementMode replacementMode;

  const AdaptyAndroidSubscriptionUpdateParameters(
    this.oldSubVendorProductId,
    this.replacementMode,
  );

  String toString() => '(oldSubVendorProductId: $oldSubVendorProductId, replacementMode: $replacementMode)';
}

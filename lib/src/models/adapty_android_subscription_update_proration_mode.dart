//
//  adapty_android_subscription_update_proration_mode.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part 'private/adapty_android_subscription_update_proration_mode_json_builder.dart';

enum AdaptyAndroidSubscriptionUpdateProrationMode {
  immediateWithTimeProration,
  immediateAndChargeProratedPrice,
  immediateWithoutProration,
  deferred,
  immediateAndChargeFullPrice,
}

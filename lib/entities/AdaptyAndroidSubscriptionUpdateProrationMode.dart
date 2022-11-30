//
//  AdaptySubscriptionUpdateParametersProrationMode.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part '../entities.json/AdaptyAndroidSubscriptionUpdateProrationModeJSONBuilder.dart';

enum AdaptyAndroidSubscriptionUpdateProrationMode {
  immediateWithTimeProration,
  immediateAndChargeProratedPrice,
  immediateWithoutProration,
  deferred,
  immediateAndChargeFullPrice,
}

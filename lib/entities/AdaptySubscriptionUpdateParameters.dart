//
//  AdaptySubscriptionUpdateParameters.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart';
import 'AdaptyAndroidSubscriptionUpdateProrationMode.dart';
part '../entities.json/AdaptySubscriptionUpdateParameters.dart';

@immutable
class AdaptySubscriptionUpdateParameters {
  final String oldSubVendorProductId;
  final AdaptyAndroidSubscriptionUpdateProrationMode prorationMode;

  const AdaptySubscriptionUpdateParameters(
    this.oldSubVendorProductId,
    this.prorationMode,
  );
}
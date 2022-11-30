//
//  AdaptySubscriptionUpdateParameters.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;
import 'AdaptyAndroidSubscriptionUpdateProrationMode.dart';

part '../entities.json/AdaptySubscriptionUpdateParametersJSONBuilder.dart';

@immutable
class AdaptySubscriptionUpdateParameters {
  final String oldSubVendorProductId;
  final AdaptyAndroidSubscriptionUpdateProrationMode prorationMode;

  const AdaptySubscriptionUpdateParameters._(
    this.oldSubVendorProductId,
    this.prorationMode,
  );

  String toString() => '(oldSubVendorProductId: $oldSubVendorProductId, prorationMode: $prorationMode)';
}

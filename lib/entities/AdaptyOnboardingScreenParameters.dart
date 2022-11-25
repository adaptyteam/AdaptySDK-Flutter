//
//  AdaptyOnboardingScreenParameters.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart';

@immutable
class AdaptyOnboardingScreenParameters {
  final String? name;
  final String? screenName;
  final int screenOrder;

  const AdaptyOnboardingScreenParameters(
    this.name,
    this.screenName,
    this.screenOrder,
  );
}
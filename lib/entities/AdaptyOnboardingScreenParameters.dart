//
//  AdaptyOnboardingScreenParameters.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;
part '../entities.json/AdaptyOnboardingScreenParametersJSONBuilder.dart';

@immutable
class AdaptyOnboardingScreenParameters {
  final String? name;
  final String? screenName;
  final int screenOrder;

  const AdaptyOnboardingScreenParameters._(
    this.name,
    this.screenName,
    this.screenOrder,
  );

    @override
  String toString() => '(name: $name, screenName: $screenName, screenOrder: $screenOrder)';
}
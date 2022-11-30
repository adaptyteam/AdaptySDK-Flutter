//
//  adapty_onboarding_screen_parameters.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;
part '../json.builders/adapty_onboarding_screen_parameters_json_builder.dart';

@immutable
class AdaptyOnboardingScreenParameters {
  /// [Nullable]
  final String? name;

  /// [Nullable]
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

//
//  AdaptyOnboardingScreenParameters.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of  '../entities/AdaptyOnboardingScreenParameters.dart';

extension AdaptyOnboardingScreenParametersExtension on AdaptyOnboardingScreenParameters {
  static const _name = 'onboarding_name';
  static const _screenName = 'onboarding_screen_name';
  static const _screenOrder = 'onboarding_screen_order';

  Map<String, dynamic> jsonValue() {
    return {
      _name: name,
      _screenName: screenName,
      _screenOrder: screenOrder,
    };
  }
}

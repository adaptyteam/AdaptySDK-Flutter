//
//  AdaptyOnboardingScreenParametersJSONBuilder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../entities/AdaptyOnboardingScreenParameters.dart';

extension AdaptyOnboardingScreenParametersJSONBuilder on AdaptyOnboardingScreenParameters {
  dynamic jsonValue() {
    return {
      if (name != null) _Keys.name: name,
      if (screenName != null) _Keys.screenName: screenName,
      _Keys.screenOrder: screenOrder,
    };
  }
}

class _Keys {
  static const name = 'onboarding_name';
  static const screenName = 'onboarding_screen_name';
  static const screenOrder = 'onboarding_screen_order';
}

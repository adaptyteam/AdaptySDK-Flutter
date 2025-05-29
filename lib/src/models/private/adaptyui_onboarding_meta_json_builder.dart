part of '../adaptyui/adaptyui_onboarding_meta.dart';

extension AdaptyUIOnboardingMetaJSONBuilder on AdaptyUIOnboardingMeta {
  dynamic get jsonValue => {
        _Keys.onboardingId: onboardingId,
        _Keys.screenClientId: screenClientId,
        _Keys.screenIndex: screenIndex,
        _Keys.screensTotal: screensTotal,
      };

  static AdaptyUIOnboardingMeta fromJsonValue(Map<String, dynamic> json) {
    return AdaptyUIOnboardingMeta(
      onboardingId: json[_Keys.onboardingId],
      screenClientId: json[_Keys.screenClientId],
      screenIndex: json[_Keys.screenIndex],
      screensTotal: json[_Keys.screensTotal],
    );
  }
}

class _Keys {
  static const onboardingId = 'onboarding_id';
  static const screenClientId = 'screen_cid';
  static const screenIndex = 'screen_index';
  static const screensTotal = 'total_screens';
}

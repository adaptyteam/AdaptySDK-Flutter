//
//  adapty_profile_parameters_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../models/adapty_profile_parameters.dart';

extension AdaptyProfileParametersJSONBuilder on AdaptyProfileParameters {
  dynamic jsonValue() {
    return {
      if (firstName != null) _Keys.firstName: firstName,
      if (lastName != null) _Keys.lastName: lastName,
      if (gender != null) _Keys.gender: gender?.jsonValue(),
      if (birthday != null) _Keys.birthday: birthday?.toString().substring(0, 10),
      if (email != null) _Keys.email: email,
      if (phoneNumber != null) _Keys.phoneNumber: phoneNumber,
      if (facebookAnonymousId != null) _Keys.facebookAnonymousId: facebookAnonymousId,
      if (amplitudeUserId != null) _Keys.amplitudeUserId: amplitudeUserId,
      if (amplitudeDeviceId != null) _Keys.amplitudeDeviceId: amplitudeDeviceId,
      if (mixpanelUserId != null) _Keys.mixpanelUserId: mixpanelUserId,
      if (appmetricaProfileId != null) _Keys.appmetricaProfileId: appmetricaProfileId,
      if (appmetricaDeviceId != null) _Keys.appmetricaDeviceId: appmetricaDeviceId,
      if (appTrackingTransparencyStatus != null) _Keys.appTrackingTransparencyStatus: appTrackingTransparencyStatus?.jsonValue(),
      if (_customAttributes.isNotEmpty) _Keys.customAttributes: _customAttributes,
      if (analyticsDisabled != null) _Keys.analyticsDisabled: analyticsDisabled,
      if (oneSignalPlayerId != null) _Keys.oneSignalPlayerId: oneSignalPlayerId,
      if (pushwooshHWID != null) _Keys.pushwooshHWID: pushwooshHWID,
    };
  }
}

class _Keys {
  static const firstName = 'first_name';
  static const lastName = 'last_name';
  static const gender = 'gender';
  static const birthday = 'birthday';
  static const email = 'email';
  static const phoneNumber = 'phone_number';
  static const facebookAnonymousId = 'facebook_anonymous_id';
  static const amplitudeUserId = 'amplitude_user_id';
  static const amplitudeDeviceId = 'amplitude_device_id';
  static const mixpanelUserId = 'mixpanel_user_id';
  static const appmetricaProfileId = 'appmetrica_profile_id';
  static const appmetricaDeviceId = 'appmetrica_device_id';
  static const appTrackingTransparencyStatus = 'att_status';
  static const customAttributes = 'custom_attributes';
  static const analyticsDisabled = 'analytics_disabled';
  static const oneSignalPlayerId = 'one_signal_player_id';
  static const pushwooshHWID = 'pushwoosh_hwid';
}

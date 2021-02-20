import 'dart:ffi';

import 'adapty_enums.dart';

class AdaptyProfileParameterBuilder {
  var _params = Map<String, dynamic>();

  Map<String, dynamic> get map {
    return _params;
  }

  void setEmail(String email) {
    _params['email'] = email;
  }

  void setPhoneNumber(String phoneNumber) {
    _params['phone_number'] = phoneNumber;
  }

  void setFacebookUserId(String facebookUserId) {
    _params['facebook_user_id'] = facebookUserId;
  }

  void setAmplitudeUserId(String amplitudeUserId) {
    _params['amplitude_user_id'] = amplitudeUserId;
  }

  void setAmplitudeDeviceId(String amplitudeDeviceId) {
    _params['amplitude_device_id'] = amplitudeDeviceId;
  }

  void setMixpanelUserId(String mixpanelUserId) {
    _params['mixpanel_user_id'] = mixpanelUserId;
  }

  void setAppmetricaProfileId(String appmetricaProfileId) {
    _params['appmetrica_profile_id'] = appmetricaProfileId;
  }

  void setAppmetricaDeviceId(String appmetricaDeviceId) {
    _params['appmetrica_device_id'] = appmetricaDeviceId;
  }

  void setFirstName(String firstName) {
    _params['first_name'] = firstName;
  }

  void setLastName(String lastName) {
    _params['last_name'] = lastName;
  }

  void setGender(AdaptyGender gender) {
    switch (gender) {
      case AdaptyGender.female:
        _params['gender'] = 'f';
        break;
      case AdaptyGender.male:
        _params['gender'] = 'm';
        break;
      case AdaptyGender.other:
        _params['gender'] = 'o';
        break;
    }
  }

  void setBirthday(DateTime birthday) {
    _params['birthday'] = birthday.toString().substring(0, 10);
  }

  void setCustomAttributes(Map<String, dynamic> customAttributes) {
    _params['custom_attributes'] = customAttributes;
  }

  void setAppTrackingTransparencyStatus(Uint64 appTrackingTransparencyStatus) {
    _params['att_status'] = appTrackingTransparencyStatus;
  }

  void setFacebookAnonymousId(String facebookAnonymousId) {
    _params['facebook_anonymous_id'] = facebookAnonymousId;
  }
}

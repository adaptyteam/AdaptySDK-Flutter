//
//  adapty_profile_parameters.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'adapty_ios_app_tracking_transparency_status.dart';
import 'adapty_profile_gender.dart';

part '../json.builders/adapty_profile_parameters_json_builder.dart';

class AdaptyProfileParameters {
  String? firstName;
  String? lastName;
  AdaptyProfileGender? gender;
  DateTime? birthday;
  String? email;
  String? phoneNumber;

  String? facebookAnonymousId;
  String? amplitudeUserId;
  String? amplitudeDeviceId;
  String? mixpanelUserId;
  String? appmetricaProfileId;
  String? appmetricaDeviceId;
  String? oneSignalPlayerId;
  String? pushwooshHWID;
  AdaptyIOSAppTrackingTransparencyStatus? appTrackingTransparencyStatus;
  bool? analyticsDisabled;
  var _customAttributes = <String, dynamic>{};
  Map<String, dynamic> get customAttributes => _customAttributes;

  void setCustomStringAttribute(String value, String key) {
    if (value.isEmpty || value.length > 30) {
      //   throw  AdaptyError.wrongStringValueOfCustomAttribute();
    }
    if (!_validateCustomAttributeKey(key, true)) {
      return;
    }
    customAttributes[key] = value;
  }

  void setCustomDoubleAttribute(double value, String key) {
    if (!_validateCustomAttributeKey(key, true)) {
      return;
    }
    customAttributes[key] = value;
  }

  void removeCustomAttribute(String key) {
    if (!_validateCustomAttributeKey(key, false)) {
      return;
    }
    customAttributes[key] = null;
  }

  bool _validateCustomAttributeKey(String addingKey, bool testCount) {
    // if (key.isEmpty || key.length > 30 || key.range(of: ".*[^A-Za-z0-9._-].*", options: .regularExpression) != nil) {
    //     // throw AdaptyError.wrongKeyOfCustomAttribute();
    //     return false;
    // }

    if (!testCount) {
      return true;
    }

    var count = 0;
    _customAttributes.forEach((key, value) {
      if (value != null && key != addingKey) {
        count += 1;
      }
    });

    if (count > 10) {
      // throw  AdaptyError.wrongCountCustomAttributes();
      return false;
    }

    return true;
  }
}

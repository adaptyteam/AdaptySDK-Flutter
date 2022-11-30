//
//  AdaptyProfileParameters.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'AdaptyAppTrackingTransparencyStatus.dart';
import 'AdaptyProfileGender.dart';

part '../entities.json/ProfileParametersJSONBuilder.dart';

class ProfileParameters {
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
  AdaptyAppTrackingTransparencyStatus? appTrackingTransparencyStatus;
  bool? analyticsDisabled;
  var customAttributes = <String, dynamic>{};
}

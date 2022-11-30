//
//  adapty_app_tracking_transparency_status_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../models/adapty_app_tracking_transparency_status.dart';

extension AdaptyAppTrackingTransparencyStatusJSONBuilder on AdaptyAppTrackingTransparencyStatus {
  dynamic jsonValue() {
    switch (this) {
      case AdaptyAppTrackingTransparencyStatus.notDetermined:
        return 0;
      case AdaptyAppTrackingTransparencyStatus.restricted:
        return 1;
      case AdaptyAppTrackingTransparencyStatus.denied:
        return 2;
      case AdaptyAppTrackingTransparencyStatus.authorized:
        return 3;
    }
  }
}

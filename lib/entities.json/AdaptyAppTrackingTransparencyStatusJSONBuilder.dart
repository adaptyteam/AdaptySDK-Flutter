//
//  AdaptyAppTrackingTransparencyStatusJSONBuilder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../entities/AdaptyAppTrackingTransparencyStatus.dart';

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

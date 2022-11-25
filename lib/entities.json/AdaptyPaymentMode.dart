//
//  AdaptyPaymentMode.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import '../entities/AdaptyPaymentMode.dart';

extension AdaptyPaymentModeExtension on AdaptyPaymentMode {
  static const _payAsYouGo = 'pay_as_you_go';
  static const _payUpFront = 'pay_up_front';
  static const _freeTrial = 'free_trial';
  static const _unknown = "unknown";

  String stringValue() {
    switch (this) {
      case AdaptyPaymentMode.payAsYouGo:
        return _payAsYouGo;
      case AdaptyPaymentMode.payUpFront:
        return _payUpFront;
      case AdaptyPaymentMode.freeTrial:
        return _freeTrial;
      case AdaptyPaymentMode.unknown:
        return _unknown;
    }
  }

  static AdaptyPaymentMode fromStringValue(String value) {
    switch (value) {
      case _payAsYouGo:
        return AdaptyPaymentMode.payAsYouGo;
      case _payUpFront:
        return AdaptyPaymentMode.payUpFront;
      case _freeTrial:
        return AdaptyPaymentMode.freeTrial;
      default:
        return AdaptyPaymentMode.unknown;
    }
  }
}

extension MapExtension on Map<String, dynamic> {
  AdaptyPaymentMode paymentMode(String key) {
    return AdaptyPaymentModeExtension.fromStringValue(this[key] as String);
  }

  AdaptyPaymentMode? paymentModeIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyPaymentModeExtension.fromStringValue(value);
  }
}

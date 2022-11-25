//
//  AdaptyProductDiscountPaymentMode.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

enum AdaptyProductDiscountPaymentMode {
  payAsYouGo,
  payUpFront,
  freeTrial,
  unknown,
}

extension AdaptyProductDiscountPaymentModeExtension on AdaptyProductDiscountPaymentMode {
  static const _payAsYouGo = 'pay_as_you_go';
  static const _payUpFront = 'pay_up_front';
  static const _freeTrial = 'free_trial';
  static const _unknown = "unknown";

  String stringValue() {
    switch (this) {
      case AdaptyProductDiscountPaymentMode.payAsYouGo:
        return _payAsYouGo;
      case AdaptyProductDiscountPaymentMode.payUpFront:
        return _payUpFront;
      case AdaptyProductDiscountPaymentMode.freeTrial:
        return _freeTrial;
      case AdaptyProductDiscountPaymentMode.unknown:
        return _unknown;
    }
  }

  static AdaptyProductDiscountPaymentMode fromStringValue(String value) {
    switch (value) {
      case _payAsYouGo:
        return AdaptyProductDiscountPaymentMode.payAsYouGo;
      case _payUpFront:
        return AdaptyProductDiscountPaymentMode.payUpFront;
      case _freeTrial:
        return AdaptyProductDiscountPaymentMode.freeTrial;
      default:
        return AdaptyProductDiscountPaymentMode.unknown;
    }
  }
}

extension MapExtension on Map<String, dynamic> {
  AdaptyProductDiscountPaymentMode periodUnit(String key) {
    return AdaptyProductDiscountPaymentModeExtension.fromStringValue(this[key] as String);
  }

  AdaptyProductDiscountPaymentMode? periodUnitIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyProductDiscountPaymentModeExtension.fromStringValue(value);
  }
}

//
//  adapty_error_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../models/adapty_error.dart';

extension AdaptyErrorJSONBuilder on AdaptyError {
  static AdaptyError fromJsonValue(Map<String, dynamic> json) {
    return AdaptyError(
      json.string(_Keys.message),
      json.integer(_Keys.code),
      AdaptySDKNative.isAndroid ? null : json.string(_Keys.detail),
    );
  }
}

class _Keys {
  static const message = 'message';
  static const detail = 'detail';
  static const code = 'adapty_code';
}

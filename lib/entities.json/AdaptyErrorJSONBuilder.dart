//
//  AdaptyErrorJSONBuilder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../entities/AdaptyError.dart';

extension AdaptyErrorJSONBuilder on AdaptyError {
  static AdaptyError fromJsonValue(Map<String, dynamic> json) {
    return AdaptyError(
      json.string(_Keys.message),
      json.integer(_Keys.code),
    );
  }
}

class _Keys {
  static const message = 'message';
  static const code = 'adapty_code';
}

//
//  AdaptyResultJSONBuilder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//
part of '../entities/AdaptyResult.dart';

extension AdaptyResultJSONBuilder on AdaptyResult {
  static AdaptyResult fromJsonValue(Map<String, dynamic> json) {
    var error = json[_Keys.error];
    if (error != null) return AdaptyResult._error(AdaptyErrorJSONBuilder.fromJsonValue(error));
    return AdaptyResult._success(json[_Keys.success]);
  }
}

class _Keys {
  static const success = 'success';
  static const error = 'error';
}

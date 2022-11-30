//
//  AdaptyResultJSONBuilder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//
part of '../entities/AdaptyResult.dart';

extension AdaptyResultJSONBuilder<T> on AdaptyResult<T> {
  static AdaptyResult<T> fromJsonValue(Map<String, dynamic> json) {
    var error = json[_Keys.error];
    if (error != null) return AdaptyResult<T>._error(AdaptyErrorJSONBuilder.fromJsonValue(error));

    var success = json[_Keys.success];
    if (success == null) return AdaptyResult<T>._success(null);
    if (T == String || T == int || T == bool || T == double) return AdaptyResult<T>._success(success as T);

    throw UnimplementedError("Unknown type $T");
  }
}

class _Keys {
  static const success = 'success';
  static const error = 'error';
}

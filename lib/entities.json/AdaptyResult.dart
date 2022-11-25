//
//  AdaptyResult.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//
import '../entities/AdaptyResult.dart';
import 'AdaptyError.dart';

extension AdaptyResultExtension<T> on AdaptyResult<T> {
  static const _success = 'success';
  static const _error = 'error';

  static AdaptyResult<T> fromJsonValue(Map<String, dynamic> json) {
    var error = json[_error];
    if (error != null) return AdaptyResult<T>.error(AdaptyErrorExtension.fromJsonValue(error));

    var success = json[_success];
    if (success == null) return AdaptyResult<T>.success(null);
    if (T == String || T == int || T == bool || T == double) return AdaptyResult<T>.success(success as T);

    throw UnimplementedError("Unknown type $T");
  }
}

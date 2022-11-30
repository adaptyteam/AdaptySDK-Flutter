//
//  AdaptyResult.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//
import 'package:meta/meta.dart' show immutable;
import 'AdaptyError.dart';

part '../entities.json/AdaptyResultJSONBuilder.dart';

@immutable
class AdaptyResult<T> {
  final T? success;
  final AdaptyError? error;

  const AdaptyResult._error(this.error) : this.success = null;
  const AdaptyResult._success(this.success) : this.error = null;

  @override
  String toString() => error == null ? '(success: $success)' : '(error: $error)';
}

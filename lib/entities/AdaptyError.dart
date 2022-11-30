//
//  AdaptyError.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;
import '../entities.json/JSONBuilder.dart';

part '../entities.json/AdaptyErrorJSONBuilder.dart';

@immutable
class AdaptyError implements Exception {
  final String message;
  final int code;

  const AdaptyError(this.message, this.code);

  @override
  String toString() => '(code: $code, message: $message)';
}
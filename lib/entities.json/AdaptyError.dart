//
//  AdaptyError.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of  '../entities/AdaptyError.dart';

extension AdaptyErrorExtension on AdaptyError {
  static AdaptyError fromJsonValue(Map<String, dynamic> json) {
    return AdaptyError();
  }
}

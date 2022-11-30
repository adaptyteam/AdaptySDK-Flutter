//
//  AdaptyErrorJSONBuilder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../entities/AdaptyError.dart';

extension AdaptyErrorJSONBuilder on AdaptyError {
  static AdaptyError fromJsonValue(Map<String, dynamic> json) {
    return AdaptyError();
  }
}

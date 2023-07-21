//
//  adapty_product_category_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 21.07.2023.
//

part of '../adapty_product_category.dart';

extension AdaptyProductCategoryJSONBuilder on AdaptyProductCategory {
  dynamic get jsonValue {
    switch (this) {
      case AdaptyProductCategory.subscription:
        return _Keys.subscription;
      case AdaptyProductCategory.nonSubscription:
        return _Keys.nonSubscription;
    }
  }

  static AdaptyProductCategory fromJsonValue(String json) {
    switch (json) {
      case _Keys.subscription:
        return AdaptyProductCategory.subscription;
      case _Keys.nonSubscription:
        return AdaptyProductCategory.nonSubscription;
      default:
        return AdaptyProductCategory.nonSubscription;
    }
  }
}

class _Keys {
  static const subscription = 'subscription';
  static const nonSubscription = 'non_subscription';
}

extension MapExtension on Map<String, dynamic> {
  AdaptyProductCategory productCategory(String key) {
    return AdaptyProductCategoryJSONBuilder.fromJsonValue(this[key] as String);
  }

  AdaptyProductCategory? productCategoryIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyProductCategoryJSONBuilder.fromJsonValue(value);
  }
}

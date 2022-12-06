//
//  adapty_attribution_source_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../models/adapty_attribution_source.dart';

extension AdaptyAttributionSourceJSONBuilder on AdaptyAttributionSource {
  dynamic get jsonValue {
    switch (this) {
      case AdaptyAttributionSource.adjust:
        return _Keys.adjust;
      case AdaptyAttributionSource.appsflyer:
        return _Keys.appsflyer;
      case AdaptyAttributionSource.branch:
        return _Keys.branch;
      case AdaptyAttributionSource.appleSearchAds:
        return _Keys.appleSearchAds;
      case AdaptyAttributionSource.custom:
        return _Keys.custom;
    }
  }

  static AdaptyAttributionSource fromJsonValue(String json) {
    switch (json) {
      case _Keys.adjust:
        return AdaptyAttributionSource.adjust;
      case _Keys.appsflyer:
        return AdaptyAttributionSource.appsflyer;
      case _Keys.branch:
        return AdaptyAttributionSource.branch;
      case _Keys.appleSearchAds:
        return AdaptyAttributionSource.appleSearchAds;
      case _Keys.custom:
        return AdaptyAttributionSource.custom;
      default:
        throw FormatException("Unknown AdaptyAttributionSource value == $json");
    }
  }
}

class _Keys {
  static const String adjust = "adjust";
  static const String appsflyer = "appsflyer";
  static const String branch = "branch";
  static const String appleSearchAds = "apple_search_ads";
  static const String custom = "custom";
}

extension MapExtension on Map<String, dynamic> {
  AdaptyAttributionSource attributionSource(String key) {
    return AdaptyAttributionSourceJSONBuilder.fromJsonValue(this[key] as String);
  }

  AdaptyAttributionSource? attributionSourceIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyAttributionSourceJSONBuilder.fromJsonValue(value);
  }
}

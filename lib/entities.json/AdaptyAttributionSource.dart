//
//  AdaptyAttributionSource.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import '../entities/AdaptyAttributionSource.dart';

extension AdaptyAttributionSourceExtension on AdaptyAttributionSource {
  static const String _adjust = "adjust";
  static const String _appsflyer = "appsflyer";
  static const String _branch = "branch";
  static const String _appleSearchAds = "apple_search_ads";
  static const String _custom = "custom";

  String stringValue() {
    switch (this) {
      case AdaptyAttributionSource.adjust:
        return _adjust;
      case AdaptyAttributionSource.appsflyer:
        return _appsflyer;
      case AdaptyAttributionSource.branch:
        return _branch;
      case AdaptyAttributionSource.appleSearchAds:
        return _appleSearchAds;
      case AdaptyAttributionSource.custom:
        return _custom;
    }
  }

  static AdaptyAttributionSource fromStringValue(String value) {
    switch (value) {
      case _adjust:
        return AdaptyAttributionSource.adjust;
      case _appsflyer:
        return AdaptyAttributionSource.appsflyer;
      case _branch:
        return AdaptyAttributionSource.branch;
      case _appleSearchAds:
        return AdaptyAttributionSource.appleSearchAds;
      case _custom:
        return AdaptyAttributionSource.custom;
      default:
        throw FormatException("Unknown AdaptyAttributionSource value == $value");
    }
  }
}

extension MapExtension on Map<String, dynamic> {
  AdaptyAttributionSource attributionSource(String key) {
    return AdaptyAttributionSourceExtension.fromStringValue(this[key] as String);
  }

  AdaptyAttributionSource? attributionSourceIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return AdaptyAttributionSourceExtension.fromStringValue(value);
  }
}

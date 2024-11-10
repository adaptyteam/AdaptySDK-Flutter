//
//  adapty_access_level_json_builder.dart
//  Adapty
//
//  Created by Alexey Goncharov on 10.11.2024.
//

import 'adapty_log_level.dart';

part 'private/adapty_configuration_json_builder.dart';

enum AdaptyServerCluster {
  eu,
  us,
}

class AdaptyConfiguration {
  /// Your Adapty API key.
  final String _apiKey;

  /// Your customer user ID.
  String? _customerUserId = null;

  /// If `true`, the SDK will be in observer mode.
  bool _observerMode = false;

  /// If `true`, the SDK will not collect IDFA.
  bool _idfaCollectionDisabled = false;

  /// If `true`, the SDK will not collect IP address.
  bool _ipAddressCollectionDisabled = false;

  /// The log level.
  AdaptyLogLevel? _logLevel = AdaptyLogLevel.info;

  final String _crossPlatformSDKName = 'flutter';
  final String _crossPlatformSDKVersion = '3.2.0-SNAPSHOT';

  AdaptyConfiguration({
    required String apiKey,
  }) : _apiKey = apiKey;

  void withCustomerUserId(String? customerUserId) {
    _customerUserId = customerUserId;
  }

  void withObserverMode(bool observerMode) {
    _observerMode = observerMode;
  }

  void withIdfaCollectionDisabled(bool idfaCollectionDisabled) {
    _idfaCollectionDisabled = idfaCollectionDisabled;
  }

  void withIpAddressCollectionDisabled(bool ipAddressCollectionDisabled) {
    _ipAddressCollectionDisabled = ipAddressCollectionDisabled;
  }

  void withLogLevel(AdaptyLogLevel logLevel) {
    _logLevel = logLevel;
  }
}

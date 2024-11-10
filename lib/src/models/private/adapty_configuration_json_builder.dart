//
//  adapty_access_level_json_builder.dart
//  Adapty
//
//  Created by Alexey Goncharov on 10.11.2024.
//

part of '../adapty_configuration.dart';

extension AdaptyConfigurationJSONBuilder on AdaptyConfiguration {
  dynamic get jsonValue => {
        _Keys.apiKey: _apiKey,
        _Keys.customerUserId: _customerUserId,
        _Keys.observerMode: _observerMode,
        _Keys.idfaCollectionDisabled: _idfaCollectionDisabled,
        _Keys.ipAddressCollectionDisabled: _ipAddressCollectionDisabled,
        _Keys.logLevel: _logLevel?.name ?? 'info',
        _Keys.sdkName: _crossPlatformSDKName,
        _Keys.sdkVersion: _crossPlatformSDKVersion,
      };
}

class _Keys {
  static const apiKey = 'api_key';
  static const customerUserId = 'customer_user_id';
  static const observerMode = 'observer_mode';
  static const idfaCollectionDisabled = 'idfa_collection_disabled';
  static const ipAddressCollectionDisabled = 'ip_address_collection_disabled';
  static const logLevel = 'log_level';
  static const sdkName = 'sdk_name';
  static const sdkVersion = 'sdk_version';
}

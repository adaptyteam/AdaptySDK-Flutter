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
        if (_customerUserId != null) _Keys.customerUserId: _customerUserId,
        _Keys.observerMode: _observerMode,
        _Keys.idfaCollectionDisabled: _idfaCollectionDisabled,
        _Keys.ipAddressCollectionDisabled: _ipAddressCollectionDisabled,
        if (_backendBaseUrl != null) _Keys.backendBaseUrl: _backendBaseUrl,
        if (_backendFallbackBaseUrl != null) _Keys.backendFallbackBaseUrl: _backendFallbackBaseUrl,
        if (_backendConfigsBaseUrl != null) _Keys.backendConfigsBaseUrl: _backendConfigsBaseUrl,
        if (_backendProxyHost != null) _Keys.backendProxyHost: _backendProxyHost,
        if (_backendProxyPort != null) _Keys.backendProxyPort: _backendProxyPort,
        if (_logLevel != null) _Keys.logLevel: _logLevel!.name,
        _Keys.crossPlatformSDKName: _crossPlatformSDKName,
        _Keys.crossPlatformSDKVersion: _crossPlatformSDKVersion,
        _Keys.serverCluster: _serverCluster,
      };
}

class _Keys {
  static const apiKey = 'api_key';
  static const customerUserId = 'customer_user_id';
  static const observerMode = 'observer_mode';
  static const idfaCollectionDisabled = 'idfa_collection_disabled';
  static const ipAddressCollectionDisabled = 'ip_address_collection_disabled';
  static const backendBaseUrl = 'backend_base_url';
  static const backendFallbackBaseUrl = 'backend_fallback_base_url';
  static const backendProxyHost = 'backend_proxy_host';
  static const backendProxyPort = 'backend_proxy_port';
  static const logLevel = 'log_level';
  static const crossPlatformSDKName = 'cross_platform_sdk_name';
  static const crossPlatformSDKVersion = 'cross_platform_sdk_version';
  static const backendConfigsBaseUrl = 'backend_configs_base_url';
  static const serverCluster = 'server_cluster';
}

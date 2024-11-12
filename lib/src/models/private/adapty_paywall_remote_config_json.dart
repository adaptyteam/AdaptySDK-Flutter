part of '../adapty_paywall_remote_config.dart';

extension AdaptyPaywallRemoteConfigJSONBuilder on AdaptyPaywallRemoteConfig {
  dynamic get jsonValue => {
        _Keys.locale: locale,
        _Keys.data: data,
      };

  static AdaptyPaywallRemoteConfig fromJsonValue(Map<String, dynamic> json) {
    return AdaptyPaywallRemoteConfig._(
      json.string(_Keys.locale),
      json.string(_Keys.data),
    );
  }
}

class _Keys {
  static const locale = 'lang';
  static const data = 'data';
}

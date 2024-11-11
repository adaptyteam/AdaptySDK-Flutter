part of '../adapty_paywall_remote_config.dart';

extension AdaptyPaywallRemoteConfigJSONBuilder on AdaptyPaywallRemoteConfig {
  dynamic get jsonValue => {
        _Keys.locale: _adaptyLocale.jsonValue,
        _Keys.jsonString: jsonString,
      };

  static AdaptyPaywallRemoteConfig fromJsonValue(Map<String, dynamic> json) {
    return AdaptyPaywallRemoteConfig._(
      AdaptyLocaleJSONBuilder.fromJsonValue(json.object(_Keys.locale)),
      json.string(_Keys.jsonString),
    );
  }
}

class _Keys {
  static const locale = 'locale';
  static const jsonString = 'json_string';
}

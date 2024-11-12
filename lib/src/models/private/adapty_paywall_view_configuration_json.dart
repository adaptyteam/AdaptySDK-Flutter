part of '../adapty_paywall_view_configuration.dart';

extension AdaptyPaywallViewConfigurationJSONBuilder on AdaptyPaywallViewConfiguration {
  dynamic get jsonValue => {
        _Keys.paywallBuilderId: paywallBuilderId,
        _Keys.locale: locale,
      };

  static AdaptyPaywallViewConfiguration fromJsonValue(Map<String, dynamic> json) {
    return AdaptyPaywallViewConfiguration._(
      json.string(_Keys.paywallBuilderId),
      json.string(_Keys.locale),
    );
  }
}

class _Keys {
  static const paywallBuilderId = 'paywall_builder_id';
  static const locale = 'lang';
}

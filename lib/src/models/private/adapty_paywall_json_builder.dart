//
//  adapty_paywall_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../adapty_paywall.dart';

extension AdaptyPaywallJSONBuilder on AdaptyPaywall {
  dynamic get jsonValue => {
        _Keys.placementId: placementId,
        _Keys.instanceIdentity: _instanceIdentity,
        _Keys.name: name,
        _Keys.abTestName: abTestName,
        _Keys.variationId: variationId,
        _Keys.revision: revision,
        _Keys.hasViewConfiguration: hasViewConfiguration,
        // _Keys.remoteConfig: {
        //   _Keys.locale: locale,
        //   if (remoteConfig != null) _Keys.remoteConfigString: remoteConfig.jsonValue,
        // },
        _Keys.products: _products.map((e) => e.jsonValue).toList(growable: false),
        _Keys.version: _version,
      };

  static AdaptyPaywall fromJsonValue(Map<String, dynamic> json) {
    var remoteConfig = json.object(_Keys.remoteConfig);
    // var viewConfiguration = json.object(_Keys.viewConfiguration);

    return AdaptyPaywall._(
      json.string(_Keys.placementId),
      json.string(_Keys.instanceIdentity),
      json.string(_Keys.name),
      json.string(_Keys.abTestName),
      json.string(_Keys.variationId),
      json.integer(_Keys.revision),
      AdaptyPaywallRemoteConfigJSONBuilder.fromJsonValue(remoteConfig),
      null, // AdaptyPaywallViewConfiguration.fromJsonValue(remoteConfig), // TODO: implement
      json.productReferenceList(_Keys.products),
      json.integer(_Keys.version),
    );
  }
}

class _Keys {
  static const placementId = 'developer_id';
  static const instanceIdentity = 'paywall_id';
  static const revision = 'revision';
  static const hasViewConfiguration = 'use_paywall_builder';
  static const variationId = 'variation_id';
  static const abTestName = 'ab_test_name';
  static const name = 'paywall_name';
  static const products = 'products';
  static const remoteConfig = 'remote_config';
  static const version = 'paywall_updated_at';
  static const viewConfiguration = 'view_configuration';
}

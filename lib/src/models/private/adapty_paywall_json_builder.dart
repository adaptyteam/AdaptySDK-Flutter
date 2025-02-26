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
        _Keys.instanceIdentity: instanceIdentity,
        _Keys.name: name,
        _Keys.audienceName: audienceName,
        _Keys.abTestName: abTestName,
        _Keys.variationId: variationId,
        _Keys.revision: revision,
        if (remoteConfig != null) _Keys.remoteConfig: remoteConfig!.jsonValue,
        if (_viewConfiguration != null)
          _Keys.paywallBuilder: _viewConfiguration!.jsonValue,
        _Keys.products:
            _products.map((e) => e.jsonValue).toList(growable: false),
        if (_payloadData != null) _Keys.payloadData: _payloadData,
        _Keys.version: _version,
      };

  static AdaptyPaywall fromJsonValue(Map<String, dynamic> json) {
    var remoteConfig = json.objectIfPresent(_Keys.remoteConfig);
    var viewConfiguration = json.objectIfPresent(_Keys.paywallBuilder);

    return AdaptyPaywall._(
      json.string(_Keys.placementId),
      json.string(_Keys.instanceIdentity),
      json.string(_Keys.name),
      json.string(_Keys.audienceName),
      json.string(_Keys.abTestName),
      json.string(_Keys.variationId),
      json.integer(_Keys.revision),
      remoteConfig != null
          ? AdaptyPaywallRemoteConfigJSONBuilder.fromJsonValue(remoteConfig)
          : null,
      viewConfiguration != null
          ? AdaptyPaywallViewConfigurationJSONBuilder.fromJsonValue(
              viewConfiguration)
          : null,
      json.productReferenceList(_Keys.products),
      json.stringIfPresent(_Keys.payloadData),
      json.integer(_Keys.version),
    );
  }
}

class _Keys {
  static const placementId = 'developer_id';
  static const instanceIdentity = 'paywall_id';
  static const name = 'paywall_name';
  static const audienceName = 'audience_name';
  static const version = 'response_created_at';
  static const revision = 'revision';
  static const variationId = 'variation_id';
  static const abTestName = 'ab_test_name';

  static const remoteConfig = 'remote_config';
  static const paywallBuilder = 'paywall_builder';
  static const products = 'products';
  static const payloadData = 'payload_data';
}

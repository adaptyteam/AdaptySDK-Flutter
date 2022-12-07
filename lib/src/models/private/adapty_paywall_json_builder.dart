//
//  adapty_paywall_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../adapty_paywall.dart';

extension AdaptyPaywallJSONBuilder on AdaptyPaywall {
  dynamic get jsonValue => {
        _Keys.id: id,
        _Keys.name: name,
        _Keys.abTestName: abTestName,
        _Keys.variationId: variationId,
        _Keys.revision: revision,
        if (remoteConfigString != null) _Keys.remoteConfigString: remoteConfigString,
        _Keys.products: _products.map((e) => e.jsonValue).toList(growable: false),
        _Keys.version: _version,
        if (_payloadData != null) _Keys.payloadData: _payloadData,
      };

  static AdaptyPaywall fromJsonValue(Map<String, dynamic> json) {
    return AdaptyPaywall._(
      json.string(_Keys.id),
      json.string(_Keys.name),
      json.string(_Keys.abTestName),
      json.string(_Keys.variationId),
      json.integer(_Keys.revision),
      json.stringIfPresent(_Keys.remoteConfigString),
      json.backendProductList(_Keys.products),
      json.integer(_Keys.version),
      json.stringIfPresent(_Keys.payloadData),
    );
  }
}

class _Keys {
  static const id = 'developer_id';
  static const revision = 'revision';
  static const variationId = 'variation_id';
  static const abTestName = 'ab_test_name';
  static const name = 'paywall_name';
  static const products = 'products';
  static const remoteConfigString = 'custom_payload';
  static const version = 'paywall_updated_at';
  static const payloadData = 'payload_data';
}

//
//  AdaptyPaywallJSONBuilder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../entities/AdaptyPaywall.dart';

extension AdaptyPaywallJSONBuilder on AdaptyPaywall {
  Map<String, dynamic> jsonValue() {
    return {
      _Keys.id: id,
      _Keys.name: name,
      _Keys.abTestName: abTestName,
      _Keys.variationId: variationId,
      _Keys.revision: revision,
      _Keys.remoteConfigString: remoteConfigString,
      _Keys.products: _products.map((e) => e.jsonValue).toList(growable: false),
      _Keys.version: _version,
    };
  }

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
}

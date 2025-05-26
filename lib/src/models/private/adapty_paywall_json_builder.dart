//
//  adapty_paywall_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../adapty_paywall.dart';

extension AdaptyPaywallJSONBuilder on AdaptyPaywall {
  dynamic get jsonValue => {
        _Keys.placement: placement.jsonValue,
        _Keys.paywallId: instanceIdentity,
        _Keys.paywallName: name,
        _Keys.variationId: variationId,
        if (remoteConfig != null) _Keys.remoteConfig: remoteConfig!.jsonValue,
        if (_viewConfiguration != null) _Keys.paywallBuilder: _viewConfiguration!.jsonValue,
        _Keys.products: _products.map((e) => e.jsonValue).toList(growable: false),
        if (_payloadData != null) _Keys.payloadData: _payloadData,
        if (_webPurchaseUrl != null) _Keys.webPurchaseUrl: _webPurchaseUrl,
      };

  static AdaptyPaywall fromJsonValue(Map<String, dynamic> json) {
    var remoteConfig = json.objectIfPresent(_Keys.remoteConfig);
    var viewConfiguration = json.objectIfPresent(_Keys.paywallBuilder);

    return AdaptyPaywall._(
      AdaptyPlacementJSONBuilder.fromJsonValue(
        json.object(_Keys.placement),
        json.integerIfPresent('response_created_at') ?? 0, // TODO: remove this
      ),
      json.string(_Keys.paywallId),
      json.string(_Keys.paywallName),
      json.string(_Keys.variationId),
      remoteConfig != null ? AdaptyPaywallRemoteConfigJSONBuilder.fromJsonValue(remoteConfig) : null,
      viewConfiguration != null ? AdaptyPaywallViewConfigurationJSONBuilder.fromJsonValue(viewConfiguration) : null,
      json.productReferenceList(_Keys.products),
      json.stringIfPresent(_Keys.payloadData),
      json.stringIfPresent(_Keys.webPurchaseUrl),
    );
  }
}

class _Keys {
  static const placement = 'placement';
  static const paywallId = 'paywall_id';
  static const paywallName = 'paywall_name';
  static const variationId = 'variation_id';
  static const products = 'products';

  static const remoteConfig = 'remote_config';
  static const paywallBuilder = 'paywall_builder';
  static const webPurchaseUrl = 'web_purchase_url';
  static const payloadData = 'payload_data';
}

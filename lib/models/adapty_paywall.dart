import 'dart:convert';

import 'adapty_product.dart';

class AdaptyPaywall {
  /// The identifier of the paywall, configured in Adapty Dashboard.
  final String developerId;

  /// The identifier of the variation, used to attribute purchases to the paywall.
  final String variationId;

  /// The current revision (version) of the paywall.
  /// Every change within the paywall creates a new revision.
  final int revision;

  /// Whether this paywall is a part of the Promo Campaign.
  final bool isPromo;

  /// An array of ProductModel objects related to this paywall.
  final List<AdaptyProduct> products;

  ///  TODO: write docs
  final String visualPaywall;

  /// The custom JSON formatted data configured in Adapty Dashboard.
  final Map<String, dynamic> customPayload;
  final String customPayloadString;

  AdaptyPaywall.fromMap(Map<String, dynamic> map)
      : developerId = map[_AdaptyPaywallKeys.developerId],
        variationId = map[_AdaptyPaywallKeys.variationId],
        revision = map[_AdaptyPaywallKeys.revision],
        isPromo = map[_AdaptyPaywallKeys.isPromo],
        products = map[_AdaptyPaywallKeys.products] == null ? null : (map[_AdaptyPaywallKeys.products] as List).map((json) => AdaptyProduct.fromMap(json)).toList(),
        visualPaywall = map[_AdaptyPaywallKeys.visualPaywall],
        customPayload = map[_AdaptyPaywallKeys.customPayloadString] == null ? null : json.decode(map[_AdaptyPaywallKeys.customPayloadString]),
        customPayloadString = map[_AdaptyPaywallKeys.customPayloadString];

  @override
  String toString() => '${_AdaptyPaywallKeys.developerId}: $developerId, '
      '${_AdaptyPaywallKeys.variationId}: $variationId, '
      '${_AdaptyPaywallKeys.revision}: $revision, '
      '${_AdaptyPaywallKeys.isPromo}: $isPromo, '
      '${_AdaptyPaywallKeys.products}: $products, '
      '${_AdaptyPaywallKeys.visualPaywall}: $visualPaywall, '
      '${_AdaptyPaywallKeys.customPayloadString}: $customPayloadString';
}

class _AdaptyPaywallKeys {
  static const developerId = 'developerId';
  static const variationId = 'variationId';
  static const revision = 'revision';
  static const isPromo = 'isPromo';
  static const products = 'products';
  static const visualPaywall = 'visualPaywall';
  static const customPayloadString = 'customPayloadString';
}

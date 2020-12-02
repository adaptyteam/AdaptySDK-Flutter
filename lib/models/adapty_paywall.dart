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

  AdaptyPaywall.fromJson(Map<String, dynamic> json)
      : developerId = json[_AdaptyPaywallKeys.developerId],
        variationId = json[_AdaptyPaywallKeys.variationId],
        revision = json[_AdaptyPaywallKeys.revision],
        isPromo = json[_AdaptyPaywallKeys.isPromo],
        products = json[_AdaptyPaywallKeys.products] == null ? null : (json[_AdaptyPaywallKeys.products] as List).map((json) => AdaptyProduct.fromJson(json)).toList(),
        visualPaywall = json[_AdaptyPaywallKeys.visualPaywall],
        customPayload = json[_AdaptyPaywallKeys.customPayload];

  @override
  String toString() => '${_AdaptyPaywallKeys.developerId}: $developerId, '
      '${_AdaptyPaywallKeys.variationId}: $variationId, '
      '${_AdaptyPaywallKeys.revision}: $revision, '
      '${_AdaptyPaywallKeys.isPromo}: $isPromo, '
      '${_AdaptyPaywallKeys.products}: $products, '
      '${_AdaptyPaywallKeys.visualPaywall}: $visualPaywall, '
      '${_AdaptyPaywallKeys.customPayload}: $customPayload';
}

class _AdaptyPaywallKeys {
  static const developerId = 'developerId';
  static const variationId = 'variationId';
  static const revision = 'revision';
  static const isPromo = 'isPromo';
  static const products = 'products';
  static const visualPaywall = 'visualPaywall';
  static const customPayload = 'customPayload';
}

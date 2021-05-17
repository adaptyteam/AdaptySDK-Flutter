import 'dart:convert';

import 'adapty_product.dart';

class AdaptyPaywall {
  /// The identifier of the paywall, configured in Adapty Dashboard.
  final String? developerId;

  /// The identifier of the variation, used to attribute purchases to the paywall.
  final String? variationId;

  /// The current revision (version) of the paywall.
  /// Every change within the paywall creates a new revision.
  final int? revision;

  /// Whether this paywall is a part of the Promo Campaign.
  final bool? isPromo;

  /// An array of ProductModel objects related to this paywall.
  final List<AdaptyProduct>? products;

  ///  TODO: write docs
  final String? visualPaywall;

  /// The custom JSON formatted data configured in Adapty Dashboard.
  final Map<String, dynamic>? customPayload;

  /// The custom JSON formatted data configured in Adapty Dashboard.
  /// (String representation)
  final String? customPayloadString;

  /// Paywall A/B test name
  final String? abTestName;

  /// Paywall name
  final String? name;

  AdaptyPaywall.fromMap(Map<String, dynamic> map)
      : developerId = map[_Keys.developerId],
        variationId = map[_Keys.variationId],
        revision = map[_Keys.revision],
        isPromo = map[_Keys.isPromo],
        products = map[_Keys.products] == null ? List<AdaptyProduct>.empty() : (map[_Keys.products] as List).map((json) => AdaptyProduct.fromMap(json)).toList(),
        visualPaywall = map[_Keys.visualPaywall],
        customPayload = _parsePayloadOrNull(map[_Keys.customPayloadString]),
        customPayloadString = map[_Keys.customPayloadString],
        abTestName = map[_Keys.abTestName],
        name = map[_Keys.name];

  static Map<String, dynamic>? _parsePayloadOrNull(String? payloadString) {
    if (payloadString == null || payloadString.isEmpty) return null;
    return json.decode(payloadString);
  }

  @override
  String toString() => '${_Keys.developerId}: $developerId, '
      '${_Keys.variationId}: $variationId, '
      '${_Keys.revision}: $revision, '
      '${_Keys.isPromo}: $isPromo, '
      '${_Keys.products}: $products, '
      '${_Keys.visualPaywall}: $visualPaywall, '
      '${_Keys.customPayloadString}: $customPayloadString'
      '${_Keys.abTestName}: $abTestName'
      '${_Keys.name}: $name';
}

class _Keys {
  static const developerId = 'developerId';
  static const variationId = 'variationId';
  static const revision = 'revision';
  static const isPromo = 'isPromo';
  static const products = 'products';
  static const visualPaywall = 'visualPaywall';
  static const customPayloadString = 'customPayloadString';
  static const abTestName = 'abTestName';
  static const name = 'name';
}

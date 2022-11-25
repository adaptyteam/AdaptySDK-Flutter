import 'dart:convert';

import 'adapty_product.dart';

class AdaptyPaywall {
  /// An identifier of a paywall, configured in Adapty Dashboard.
  final String id;

  /// A paywall name.
  final String? name;

  /// An identifier of a variation, used to attribute purchases to this paywall.
  final String variationId;

  /// Parent A/B test name.
  final String? abTestName;

  /// Current revision (version) of a paywall. Every change within a paywall creates a new revision.
  final int revision;

  /// A custom JSON string configured in Adapty Dashboard for this paywall.
  final String? remoteConfigString;

  /// A custom dictionary configured in Adapty Dashboard for this paywall (same as `remoteConfigString`)
  final Map<String, dynamic>? remoteConfig;

  ///  Array of related products ids.
  final List<String> vendorProductIds;

  AdaptyPaywall.fromMap(Map<String, dynamic> map)
      : id = map[_Keys.id],
        name = map[_Keys.name],
        variationId = map[_Keys.variationId],
        abTestName = map[_Keys.abTestName],
        revision = map[_Keys.revision],
        remoteConfigString = map[_Keys.remoteConfigString],
        remoteConfig = _parsePayloadOrNull(map[_Keys.remoteConfigString]),
        vendorProductIds = _parseProductIds(map[_Keys.products]); // (map[_Keys.products] as List).map((json) => AdaptyProduct.fromMap(json).vendorProductId).toList();

  static List<String> _parseProductIds(List paywalls) {
    return paywalls.map((e) => (e as Map<String, dynamic>)['vendor_product_id'] as String).toList();
  }

  static Map<String, dynamic>? _parsePayloadOrNull(String? payloadString) {
    if (payloadString == null || payloadString.isEmpty) return null;
    return json.decode(payloadString);
  }

  Map<String, dynamic> toMap() {
    return {
      _Keys.id: id,
      _Keys.name: name,
      _Keys.variationId: variationId,
      _Keys.abTestName: abTestName,
      _Keys.revision: revision,
    };
  }

  @override
  String toString() => '${_Keys.id}: $id, '
      '${_Keys.variationId}: $variationId, '
      '${_Keys.revision}: $revision, '
      'vendor_product_ids: $vendorProductIds, '
      '${_Keys.remoteConfigString}: $remoteConfigString'
      '${_Keys.abTestName}: $abTestName'
      '${_Keys.name}: $name';
}

class _Keys {
  static const id = 'developer_id';
  static const variationId = 'variation_id';
  static const revision = 'revision';
  static const products = 'products';
  static const remoteConfigString = 'custom_payload';
  static const abTestName = 'ab_test_name';
  static const name = 'paywall_name';
}

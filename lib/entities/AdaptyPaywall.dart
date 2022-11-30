//
//  AdaptyPaywall.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;
import 'dart:convert';
import '../entities.json/JSONBuilder.dart';
import 'BackendProduct.dart';

part '../entities.json/AdaptyPaywallJSONBuilder.dart';

@immutable
class AdaptyPaywall {
  /// An identifier of a paywall, configured in Adapty Dashboard.
  final String id;

  /// A paywall name.
  final String name;

  /// Parent A/B test name.
  final String abTestName;

  /// An identifier of a variation, used to attribute purchases to this paywall.
  final String variationId;

  /// Current revision (version) of a paywall. Every change within a paywall creates a new revision.
  final int revision;

  /// A custom JSON string configured in Adapty Dashboard for this paywall.
  /// 
  /// [Nullable]
  final String? remoteConfigString;

  /// A custom dictionary configured in Adapty Dashboard for this paywall (same as `remoteConfigString`)
  Map<String, dynamic>? get remoteConfig {
    final data = remoteConfigString;
    if (data == null || data.isEmpty) return null;
    return json.decode(data);
  }

  final List<BackendProduct> _products;

  /// Array of related products ids.
  List<String> get vendorProductIds {
    return _products.map((e) => e.vendorId).toList(growable: false);
  }

  final int _version;

  const AdaptyPaywall._(
    this.id,
    this.name,
    this.abTestName,
    this.variationId,
    this.revision,
    this.remoteConfigString,
    this._products,
    this._version,
  );

  @override
  String toString() => '(id: $id, '
      'name: $name, '
      'abTestName: $abTestName, '
      'variationId: $variationId, '
      'revision: $revision, '
      'remoteConfigString: $remoteConfigString, '
      '_products: $_products, '
      '_version: $_version)';

}

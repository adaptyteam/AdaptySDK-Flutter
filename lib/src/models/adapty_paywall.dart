//
//  adapty_paywall.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;
import 'dart:convert';
import 'private/json_builder.dart';
import 'product_reference.dart';

part 'private/adapty_paywall_json_builder.dart';

@immutable
class AdaptyPaywall {
  /// An identifier of a paywall, configured in Adapty Dashboard.
  final String placementId;

  final String _instanceIdentity;

  /// A paywall name.
  final String name;

  /// Parent A/B test name.
  final String abTestName;

  /// An identifier of a variation, used to attribute purchases to this paywall.
  final String variationId;

  /// Current revision (version) of a paywall. Every change within a paywall creates a new revision.
  final int revision;

  /// If `true`, it is possible to use Adapty Paywall Builder.
  /// Read more here: https://docs.adapty.io/docs/paywall-builder-getting-started
  final bool hasViewConfiguration;

  /// And identifier of a paywall locale.
  final String locale;

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

  final List<ProductReference> _products;

  /// Array of related products ids.
  List<String> get vendorProductIds {
    return _products.map((e) => e.vendorId).toList(growable: false);
  }

  final int _version;
  final String? _payloadData;

  const AdaptyPaywall._(
    this.placementId,
    this._instanceIdentity,
    this.name,
    this.abTestName,
    this.variationId,
    this.revision,
    this.hasViewConfiguration,
    this.locale,
    this.remoteConfigString,
    this._products,
    this._version,
    this._payloadData,
  );

  @override
  String toString() => '(placementId: $placementId, '
      '_instanceIdentity: $_instanceIdentity, '
      'name: $name, '
      'abTestName: $abTestName, '
      'variationId: $variationId, '
      'revision: $revision, '
      'locale: $locale, '
      'remoteConfigString: $remoteConfigString, '
      '_products: $_products, '
      '_version: $_version)';
}

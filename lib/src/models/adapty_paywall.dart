//
//  adapty_paywall.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;

import 'private/json_builder.dart';
import 'product_reference.dart';
import 'adapty_remote_config.dart';
import 'adapty_paywall_view_configuration.dart';
import 'adapty_placement.dart';
import 'adapty_product_identifier.dart';

part 'private/adapty_paywall_json_builder.dart';

@immutable
class AdaptyPaywall {
  /// An `AdaptyPlacement` object, that contains information about the placement of the paywall.
  final AdaptyPlacement placement;

  /// An identifier of a paywall, configured in Adapty Dashboard.
  final String instanceIdentity;

  /// A paywall name.
  final String name;

  /// An identifier of a variation, used to attribute purchases to this paywall.
  final String variationId;

  /// A custom dictionary configured in Adapty Dashboard for this paywall.
  final AdaptyRemoteConfig? remoteConfig;

  /// If `true`, it is possible to use Adapty Paywall Builder.
  /// Read more here: https://docs.adapty.io/docs/paywall-builder-getting-started
  bool get hasViewConfiguration => _viewConfiguration != null;

  final AdaptyPaywallViewConfiguration? _viewConfiguration;

  final List<ProductReference> _products;

  final int _responseCreatedAt;
  final String? _payloadData;
  final String? _webPurchaseUrl;
  final String? _requestLocale;

  /// Array of related product identifiers.
  List<AdaptyProductIdentifier> get productIdentifiers {
    return _products
        .map((e) => e.toAdaptyProductIdentifier())
        .toList(growable: false);
  }

  /// Array of related products ids.
  @Deprecated('Use productIdentifiers instead')
  List<String> get vendorProductIds {
    return _products.map((e) => e.vendorId).toList(growable: false);
  }

  @Deprecated('Use placement.id instead')
  String get placementId => placement.id;

  @Deprecated('Use placement.revision instead')
  int get revision => placement.revision;

  const AdaptyPaywall._(
    this.placement,
    this.instanceIdentity,
    this.name,
    this.variationId,
    this.remoteConfig,
    this._viewConfiguration,
    this._products,
    this._responseCreatedAt,
    this._payloadData,
    this._webPurchaseUrl,
    this._requestLocale,
  );

  @override
  String toString() => '(placement: $placement, '
      'instanceIdentity: $instanceIdentity, '
      'name: $name, '
      'variationId: $variationId, '
      'hasViewConfiguration: $hasViewConfiguration, '
      'remoteConfig: $remoteConfig, '
      '_products: $_products, '
      '_responseCreatedAt: $_responseCreatedAt, '
      '_payloadData: $_payloadData, '
      '_webPurchaseUrl: $_webPurchaseUrl, '
      '_requestLocale: $_requestLocale)';
}

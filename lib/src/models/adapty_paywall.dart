//
//  adapty_paywall.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;

import 'private/json_builder.dart';
import 'product_reference.dart';
import 'adapty_paywall_remote_config.dart';
import 'adapty_paywall_view_configuration.dart';
part 'private/adapty_paywall_json_builder.dart';

@immutable
class AdaptyPaywall {
  /// An identifier of a paywall, configured in Adapty Dashboard.
  final String placementId;

  final String instanceIdentity;

  /// A paywall name.
  final String name;

  /// A name of an audience to which the paywall belongs.
  final String audienceName;

  /// Parent A/B test name.
  final String abTestName;

  /// An identifier of a variation, used to attribute purchases to this paywall.
  final String variationId;

  /// Current revision (version) of a paywall. Every change within a paywall creates a new revision.
  final int revision;

  /// A custom dictionary configured in Adapty Dashboard for this paywall.
  final AdaptyPaywallRemoteConfig? remoteConfig;

  /// If `true`, it is possible to use Adapty Paywall Builder.
  /// Read more here: https://docs.adapty.io/docs/paywall-builder-getting-started
  bool get hasViewConfiguration => _viewConfiguration != null;

  final AdaptyPaywallViewConfiguration? _viewConfiguration;

  final List<ProductReference> _products;

  final String? _payloadData;

  /// Array of related products ids.
  List<String> get vendorProductIds {
    return _products.map((e) => e.vendorId).toList(growable: false);
  }

  final int _version;

  const AdaptyPaywall._(
    this.placementId,
    this.instanceIdentity,
    this.name,
    this.audienceName,
    this.abTestName,
    this.variationId,
    this.revision,
    this.remoteConfig,
    this._viewConfiguration,
    this._products,
    this._payloadData,
    this._version,
  );

  @override
  String toString() => '(placementId: $placementId, '
      'instanceIdentity: $instanceIdentity, '
      'name: $name, '
      'audienceName: $audienceName, '
      'abTestName: $abTestName, '
      'variationId: $variationId, '
      'revision: $revision, '
      'hasViewConfiguration: $hasViewConfiguration, '
      'remoteConfig: $remoteConfig, '
      '_products: $_products, '
      '_payloadData: $_payloadData, '
      '_version: $_version)';
}

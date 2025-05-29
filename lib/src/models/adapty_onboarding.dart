import 'package:meta/meta.dart';

import 'private/json_builder.dart';
import 'adapty_placement.dart';
import 'adapty_remote_config.dart';

part 'private/adapty_onboarding_json_builder.dart';

@immutable
class AdaptyOnboarding {
  /// An `AdaptyPlacement` object, that contains information about the placement of the paywall.
  final AdaptyPlacement placement;

  /// An identifier of a onboarding, configured in Adapty Dashboard.
  final String id;

  /// A onboarding name.
  final String name;

  /// An identifier of a variation, used to attribute purchases to this onboarding.
  final String variationId;

  /// A custom dictionary configured in Adapty Dashboard for this paywall.
  final AdaptyRemoteConfig? remoteConfig;

  final int _responseCreatedAt;
  final String _onboardingBuilderLang;
  final String _onboardingBuilderConfigUrl;
  final String? _payloadData;

  const AdaptyOnboarding._(
    this.placement,
    this.id,
    this.name,
    this.variationId,
    this.remoteConfig,
    this._responseCreatedAt,
    this._onboardingBuilderLang,
    this._onboardingBuilderConfigUrl,
    this._payloadData,
  );

  @override
  String toString() => '(placement: $placement, '
      'id: $id, '
      'name: $name, '
      'variationId: $variationId, '
      'remoteConfig: $remoteConfig, '
      '_responseCreatedAt: $_responseCreatedAt, '
      '_onboardingBuilderLang: $_onboardingBuilderLang, '
      '_onboardingBuilderConfigUrl: $_onboardingBuilderConfigUrl, '
      '_payloadData: $_payloadData)';
}

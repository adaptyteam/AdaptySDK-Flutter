//
//  adapty_external_attribution_provider.dart
//  Adapty
//

import 'package:meta/meta.dart' show immutable;

/// Identifier of an external attribution provider.
///
/// This is an open wrapper over a raw string so identifiers introduced by
/// future SDK versions remain valid.
@immutable
class AdaptyExternalAttributionProvider {
  final String rawValue;

  AdaptyExternalAttributionProvider(String rawValue) : rawValue = rawValue.trim();

  const AdaptyExternalAttributionProvider._known(this.rawValue);

  static const appleAds = AdaptyExternalAttributionProvider._known('apple_search_ads');
  static const adjust = AdaptyExternalAttributionProvider._known('adjust');
  static const appsflyer = AdaptyExternalAttributionProvider._known('appsflyer');
  static const branch = AdaptyExternalAttributionProvider._known('branch');
  static const tenjin = AdaptyExternalAttributionProvider._known('tenjin');
  static const custom = AdaptyExternalAttributionProvider._known('custom');

  @override
  bool operator ==(Object other) => other is AdaptyExternalAttributionProvider && other.rawValue == rawValue;

  @override
  int get hashCode => rawValue.hashCode;

  @override
  String toString() => rawValue;
}

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

  static final appleAds = AdaptyExternalAttributionProvider('apple_search_ads');
  static final adjust = AdaptyExternalAttributionProvider('adjust');
  static final appsflyer = AdaptyExternalAttributionProvider('appsflyer');
  static final branch = AdaptyExternalAttributionProvider('branch');
  static final tenjin = AdaptyExternalAttributionProvider('tenjin');
  static final custom = AdaptyExternalAttributionProvider('custom');

  @override
  bool operator ==(Object other) => other is AdaptyExternalAttributionProvider && other.rawValue == rawValue;

  @override
  int get hashCode => rawValue.hashCode;

  @override
  String toString() => rawValue;
}

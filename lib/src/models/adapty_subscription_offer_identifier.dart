import 'package:meta/meta.dart' show immutable;

import 'private/json_builder.dart';

part 'private/adapty_subscription_offer_identifier_json_builder.dart';

enum AdaptySubscriptionOfferType {
  introductory,
  promotional,
  winBack,
  code,
}

@immutable
class AdaptySubscriptionOfferIdentifier {
  final String? id;
  final AdaptySubscriptionOfferType type;

  /// The type as the native side sent it, written back unchanged so that a type this version
  /// doesn't know, which [type] reads as `introductory`, still names the same offer.
  final String _wireType;

  const AdaptySubscriptionOfferIdentifier._(this.id, this.type, this._wireType);
}

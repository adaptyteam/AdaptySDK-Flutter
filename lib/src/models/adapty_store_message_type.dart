/// The reason the App Store wants to show a store message.
///
/// Four reasons are known: [generic], [priceIncreaseConsent], [billingIssue] and [winBackOffer].
/// Reasons unknown to the SDK arrive as `storekit_<number>`, so do not assume the list is
/// complete; compare values with `==`. Store messages require iOS 16 or later; on Android no
/// message type is ever reported.
///
/// You can create a value yourself, for example to pass it in the `iosFilter` of
/// [Adapty.showStoreMessages].
class AdaptyStoreMessageType {
  /// The identifier of the reason, such as `billing_issue` or `storekit_42`.
  final String value;

  const AdaptyStoreMessageType(this.value);

  /// A message with no more specific reason.
  static const generic = AdaptyStoreMessageType('generic');

  /// The user is asked to agree to a subscription price increase.
  static const priceIncreaseConsent = AdaptyStoreMessageType('price_increase_consent');

  /// A problem with the user's billing information, such as a declined renewal payment.
  static const billingIssue = AdaptyStoreMessageType('billing_issue');

  /// A win-back offer for a subscription that has expired.
  static const winBackOffer = AdaptyStoreMessageType('win_back_offer');

  @override
  bool operator ==(Object other) => other is AdaptyStoreMessageType && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AdaptyStoreMessageType($value)';
}

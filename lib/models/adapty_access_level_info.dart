import '../helpers/extensions.dart';

class AdaptyAccessLevelInfo {
  /// Unique identifier of the access level configured by you in Adapty Dashboard.
  final String id;

  /// `true` if this access level is active. Generally, you can check this property to determine wether a user has an access to premium features.
  final bool isActive;

  /// An identifier of a product in a store that unlocked this access level.
  final String vendorProductId;

  /// A store of the purchase that unlocked this access level.
  ///
  /// Possible values:
  /// - `app_store`
  /// - `play_store`
  /// - `adapty`
  final String store;

  /// Time when this access level was activated.
  final DateTime activatedAt;

  /// Time when the access level was renewed. It can be `null` if the purchase was first in chain or it is non-renewing subscription / non-consumable (e.g. lifetime)
  final DateTime? renewedAt;

  /// Time when the access level will expire (could be in the past and could be `null` for lifetime access).
  final DateTime? expiresAt;

  /// `true` if this access level is active for a lifetime (no expiration date).
  final bool isLifetime;

  /// A type of an active introductory offer. If the value is not `null`, it means that the offer was applied during the current subscription period.
  ///
  /// Possible values:
  /// - `free_trial`
  /// - `pay_as_you_go`
  /// - `pay_up_front`
  final String? activeIntroductoryOfferType;

  ///  A type of an active promotional offer. If the value is not `null`, it means that the offer was applied during the current subscription period.
  ///
  /// Possible values:
  /// - `free_trial`
  /// - `pay_as_you_go`
  /// - `pay_up_front`
  final String? activePromotionalOfferType;

  /// An id of active promotional offer.
  final String? activePromotionalOfferId;

  /// `true` if this auto-renewable subscription is set to renew.
  final bool willRenew;

  /// `true` if this auto-renewable subscription is in the grace period.
  final bool isInGracePeriod;

  /// Time when the auto-renewable subscription was cancelled. Subscription can still be active, it just means that auto-renewal turned off.
  /// Will be set to `null` if the user reactivates the subscription.
  final DateTime? unsubscribedAt;

  /// Time when billing issue was detected. Subscription can still be active. Would be set to `null` if a charge is made.
  final DateTime? billingIssueDetectedAt;

  /// Time when this access level has started (could be in the future).
  final DateTime? startsAt;

  /// A reason why a subscription was cancelled.
  ///
  /// Possible values:
  /// - `voluntarily_cancelled`
  /// - `billing_error`
  /// - `price_increase`
  /// - `product_was_not_available`
  /// - `refund`
  /// - `upgraded`
  /// - `unknown`
  final String? cancellationReason;

  /// Whether the purchase was refunded.
  final bool? isRefund;

  AdaptyAccessLevelInfo.fromJson(Map<String, dynamic> json)
      : id = json[_Keys.id],
        isActive = json[_Keys.isActive],
        vendorProductId = json[_Keys.vendorProductId],
        store = json[_Keys.store],
        activatedAt = json.dateTimeOrNull(_Keys.activatedAt)!,
        renewedAt = json.dateTimeOrNull(_Keys.renewedAt),
        expiresAt = json.dateTimeOrNull(_Keys.expiresAt),
        isLifetime = json[_Keys.isLifetime],
        activeIntroductoryOfferType = json[_Keys.activeIntroductoryOfferType],
        activePromotionalOfferType = json[_Keys.activePromotionalOfferType],
        activePromotionalOfferId = json[_Keys.activePromotionalOfferId],
        willRenew = json[_Keys.willRenew],
        isInGracePeriod = json[_Keys.isInGracePeriod],
        unsubscribedAt = json.dateTimeOrNull(_Keys.unsubscribedAt),
        billingIssueDetectedAt = json.dateTimeOrNull(_Keys.billingIssueDetectedAt),
        startsAt = json.dateTimeOrNull(_Keys.startsAt),
        cancellationReason = json[_Keys.cancellationReason],
        isRefund = json[_Keys.isRefund];

  @override
  String toString() => '${_Keys.id}: $id, '
      '${_Keys.isActive}: $isActive, '
      '${_Keys.vendorProductId}: $vendorProductId, '
      '${_Keys.store}: $store, '
      '${_Keys.activatedAt}: $activatedAt, '
      '${_Keys.renewedAt}: $renewedAt, '
      '${_Keys.expiresAt}: $expiresAt, '
      '${_Keys.isLifetime}: $isLifetime, '
      '${_Keys.activeIntroductoryOfferType}: $activeIntroductoryOfferType, '
      '${_Keys.activePromotionalOfferType}: $activePromotionalOfferType, '
      '${_Keys.activePromotionalOfferId}: $activePromotionalOfferId, '
      '${_Keys.willRenew}: $willRenew, '
      '${_Keys.isInGracePeriod}: $isInGracePeriod, '
      '${_Keys.unsubscribedAt}: $unsubscribedAt, '
      '${_Keys.billingIssueDetectedAt}: $billingIssueDetectedAt, '
      '${_Keys.startsAt}: $startsAt, '
      '${_Keys.cancellationReason}: $cancellationReason, '
      '${_Keys.isRefund}: $isRefund';
}

class _Keys {
  static final id = 'id';
  static final isActive = 'is_active';
  static final vendorProductId = 'vendor_product_id';
  static final store = 'store';
  static final activatedAt = 'activated_at';
  static final renewedAt = 'renewed_at';
  static final expiresAt = 'expires_at';
  static final isLifetime = 'is_lifetime';
  static final activeIntroductoryOfferType = 'active_introductory_offer_type';
  static final activePromotionalOfferType = 'active_promotional_offer_type';
  static final activePromotionalOfferId = 'active_promotional_offer_id';
  static final willRenew = 'will_renew';
  static final isInGracePeriod = 'is_in_grace_period';
  static final unsubscribedAt = 'unsubscribed_at';
  static final billingIssueDetectedAt = 'billing_issue_detected_at';
  static final startsAt = 'startsAt';
  static final cancellationReason = 'cancellationReason';
  static final isRefund = 'isRefund';
}

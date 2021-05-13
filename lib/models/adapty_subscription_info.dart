import '../helpers/extensions.dart';

class AdaptySubscriptionInfo {
  /// Whether the subscription is active.
  final bool isActive;

  /// The identifier of the product in the App Store Connect.
  final String vendorProductId;

  /// The store of the purchase. The possible values are: app_store, play_store , adapty.
  final String store;

  /// The time when the subscription was activated.
  ///
  /// [Nullable]
  final DateTime? activatedAt; // nullable

  /// The time when the subscription was renewed.
  ///
  /// [Nullable]
  final DateTime? renewedAt; // nullable

  /// The time when the subscription will expire (could be in the past and could be null for lifetime access).
  ///
  /// [Nullable]
  final DateTime? expiresAt; // nullable

  /// The time when the subscription has started (could be in the future).
  ///
  /// [Nullable]
  final DateTime? startsAt; // nullable

  /// Whether the subscription is active for a lifetime (no expiration date).
  /// If set to true you shouldn't check expires_at , or you could just check isActive.
  final bool isLifetime;

  /// The type of active introductory offer.
  /// Possible values are: free_trial, pay_as_you_go, pay_up_front.
  /// If the value is not null, it means that the offer was applied during the current subscription period.
  ///
  /// [Nullable]
  final String? activeIntroductoryOfferType; // nullable

  /// The type of active promotional offer.
  /// Possible values are: free_trial, pay_as_you_go, pay_up_front.
  /// If the value is not null, it means that the offer was applied during the current subscription period.
  ///
  /// [Nullable]
  final String? activePromotionalOfferType; // nullable

  /// Whether the auto-renewable subscription is set to renew.
  final bool willRenew;

  /// Whether the auto-renewable subscription is in the grace period.
  final bool isInGracePeriod;

  /// The time when the auto-renewable subscription was cancelled.
  /// Subscription can still be active, it just means that auto-renewal turned off.
  /// Will be set to null if the user reactivates the subscription.
  ///
  /// [Nullable]
  final DateTime? unsubscribedAt; // nullable

  /// The time when billing issue was detected (Apple was not able to charge the card).
  /// Subscription can still be active. Will be set to null if the charge will be made.
  ///
  /// [Nullable]
  final DateTime? billingIssueDetectedAt; // nullable

  /// Whether the product was purchased in the sandbox environment.
  final bool isSandbox;

  /// Transaction id from the App Store.
  ///
  /// [Nullable]
  final String? vendorTransactionId; // nullable

  /// Original transaction id from the App Store.
  /// For auto-renewable subscription, this will be the id of the first transaction in the subscription.
  ///
  /// [Nullable]
  final String? vendorOriginalTransactionId; // nullable

  /// The reason why the subscription was cancelled.
  /// Possible values are: voluntarily_cancelled, billing_error, refund, price_increase, product_was_not_available, unknown.
  ///
  /// [Nullable]
  final String? cancellationReason; // nullable

  /// Whether the purchase was refunded.
  final bool isRefund;

  AdaptySubscriptionInfo.fromJson(Map<String, dynamic> json)
      : isActive = json[_Keys.isActive],
        vendorProductId = json[_Keys.vendorProductId],
        store = json[_Keys.store],
        activatedAt = json.dateTimeOrNull(_Keys.activatedAt),
        renewedAt = json.dateTimeOrNull(_Keys.renewedAt),
        expiresAt = json.dateTimeOrNull(_Keys.expiresAt),
        startsAt = json.dateTimeOrNull(_Keys.startsAt),
        isLifetime = json[_Keys.isLifetime],
        activeIntroductoryOfferType = json[_Keys.activeIntroductoryOfferType],
        activePromotionalOfferType = json[_Keys.activePromotionalOfferType],
        willRenew = json[_Keys.willRenew],
        isInGracePeriod = json[_Keys.isInGracePeriod],
        unsubscribedAt = json.dateTimeOrNull(_Keys.unsubscribedAt),
        billingIssueDetectedAt = json.dateTimeOrNull(_Keys.billingIssueDetectedAt),
        isSandbox = json[_Keys.isSandbox],
        vendorTransactionId = json[_Keys.vendorTransactionId],
        vendorOriginalTransactionId = json[_Keys.vendorOriginalTransactionId],
        cancellationReason = json[_Keys.cancellationReason],
        isRefund = json[_Keys.isRefund];
}

class _Keys {
  static final isActive = 'isActive';
  static final vendorProductId = 'vendorProductId';
  static final store = 'store';
  static final activatedAt = 'activatedAt';
  static final renewedAt = 'renewedAt';
  static final expiresAt = 'expiresAt';
  static final startsAt = 'startsAt';
  static final isLifetime = 'isLifetime';
  static final activeIntroductoryOfferType = 'activeIntroductoryOfferType';
  static final activePromotionalOfferType = 'activePromotionalOfferType';
  static final willRenew = 'willRenew';
  static final isInGracePeriod = 'isInGracePeriod';
  static final unsubscribedAt = 'unsubscribedAt';
  static final billingIssueDetectedAt = 'billingIssueDetectedAt';
  static final isSandbox = 'isSandbox';
  static final vendorTransactionId = 'vendorTransactionId';
  static final vendorOriginalTransactionId = 'vendorOriginalTransactionId';
  static final cancellationReason = 'cancellationReason';
  static final isRefund = 'isRefund';
}

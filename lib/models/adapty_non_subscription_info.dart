import '../helpers/extensions.dart';

class AdaptyNonSubscriptionInfo {
  /// The identifier of the purchase in Adapty.
  /// You can use it to ensure that you've already processed this purchase (for example tracking one time products).
  final String? purchaseId;

  /// The identifier of the product in the App Store Connect.
  final String? vendorProductId;

  /// The store of the purchase.
  /// The possible values are: app_store, play_store , adapty.
  final String? store;

  /// The time when the product was purchased.
  ///
  /// [Nullable]
  final DateTime? purchasedAt; // nullable

  /// Whether the product should only be processed once.
  /// If true, the purchase will be returned by Adapty API one time only.
  final bool? isOneTime;

  /// Whether the product was purchased in the sandbox environment.
  final bool? isSandbox;

  /// Transaction id from the App Store.
  ///
  /// [Nullable]
  final String? vendorTransactionId; // nullable

  /// Original transaction id from the App Store.
  /// For auto-renewable subscription, this will be the id of the first transaction in the subscription.
  ///
  /// [Nullable]
  final String? vendorOriginalTransactionId; // nullable

  /// Whether the purchase was refunded.
  final bool? isRefund;

  AdaptyNonSubscriptionInfo.fromJson(Map<String, dynamic> json)
      : purchaseId = json[_Keys.purchaseId],
        vendorProductId = json[_Keys.vendorProductId],
        store = json[_Keys.store],
        purchasedAt = json.dateTimeOrNull(_Keys.purchasedAt),
        isOneTime = json[_Keys.isOneTime],
        isSandbox = json[_Keys.isSandbox],
        vendorTransactionId = json[_Keys.vendorTransactionId],
        vendorOriginalTransactionId = json[_Keys.vendorOriginalTransactionId],
        isRefund = json[_Keys.isRefund];

  @override
  String toString() => '${_Keys.purchaseId}: $purchaseId, '
      '${_Keys.vendorProductId}: $vendorProductId, '
      '${_Keys.store}: $store, '
      '${_Keys.purchasedAt}: $purchasedAt, '
      '${_Keys.isOneTime}: $isOneTime, '
      '${_Keys.isSandbox}: $isSandbox, '
      '${_Keys.vendorTransactionId}: $vendorTransactionId, '
      '${_Keys.vendorOriginalTransactionId}: $vendorOriginalTransactionId, '
      '${_Keys.isRefund}: $isRefund';
}

class _Keys {
  static final purchaseId = 'purchaseId';
  static final vendorProductId = 'vendorProductId';
  static final store = 'store';
  static final purchasedAt = 'purchasedAt';
  static final isOneTime = 'isOneTime';
  static final isSandbox = 'isSandbox';
  static final vendorTransactionId = 'vendorTransactionId';
  static final vendorOriginalTransactionId = 'vendorOriginalTransactionId';
  static final isRefund = 'isRefund';
}

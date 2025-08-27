part of '../adapty_purchase_result.dart';

extension AdaptyPurchaseResultJSONBuilder on AdaptyPurchaseResult {
  static AdaptyPurchaseResult fromJsonValue(Map<String, dynamic> json) {
    final type = json.string(_PurchaseResultKeys.type);

    switch (type) {
      case _TypeKeys.pending:
        return AdaptyPurchaseResultPending();
      case _TypeKeys.userCancelled:
        return AdaptyPurchaseResultUserCancelled();
      case _TypeKeys.success:
        final profileMap = json.object(_PurchaseResultKeys.profile);
        final jwsTransaction = json.stringIfPresent(_PurchaseResultKeys.jwsTransaction);

        return AdaptyPurchaseResultSuccess._(
          AdaptyProfileJSONBuilder.fromJsonValue(profileMap),
          jwsTransaction,
        );
      default:
        throw ArgumentError.value(type, _PurchaseResultKeys.type, 'Invalid purchase result type');
    }
  }
}

class _PurchaseResultKeys {
  static const type = 'type';
  static const profile = 'profile';
  static const jwsTransaction = 'jws_transaction';
}

class _TypeKeys {
  static const pending = 'pending';
  static const userCancelled = 'user_cancelled';
  static const success = 'success';
}

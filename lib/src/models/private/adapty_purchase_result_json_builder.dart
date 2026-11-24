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
        final appleJwsTransaction = json.stringIfPresent(_PurchaseResultKeys.appleJwsTransaction);
        final googlePurchaseToken = json.stringIfPresent(_PurchaseResultKeys.googlePurchaseToken);

        return AdaptyPurchaseResultSuccess._(
          AdaptyProfileJSONBuilder.fromJsonValue(profileMap),
          appleJwsTransaction,
          googlePurchaseToken,
        );
      default:
        AdaptyLogger.write(
          AdaptyLogLevel.warn,
          'Adapty received a purchase result type this SDK version doesn\'t know, "$type", and reads it as pending.',
        );
        return AdaptyPurchaseResultPending();
    }
  }
}

class _PurchaseResultKeys {
  static const type = 'type';
  static const profile = 'profile';
  static const appleJwsTransaction = 'apple_jws_transaction';
  static const googlePurchaseToken = 'google_purchase_token';
}

class _TypeKeys {
  static const pending = 'pending';
  static const userCancelled = 'user_cancelled';
  static const success = 'success';
}

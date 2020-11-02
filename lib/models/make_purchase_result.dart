import 'package:adapty_flutter/models/adapty_result.dart';

class MakePurchaseResult extends AdaptyResult {
  // Android
  final String purchaseToken;
  final String purchaseType;

  // iOS
  final String receipt;

  MakePurchaseResult(
      {this.purchaseToken,
      this.purchaseType,
      this.receipt,
      errorCode,
      errorMessage})
      : super(errorCode: errorCode, errorMessage: errorMessage);

  MakePurchaseResult.fromJson(Map<String, dynamic> json)
      : purchaseToken = json[_MakePurchaseResultKeys._purchaseToken] == null
            ? null
            : json[_MakePurchaseResultKeys._purchaseToken] as String,
        purchaseType = json[_MakePurchaseResultKeys._purchaseType] == null
            ? null
            : json[_MakePurchaseResultKeys._purchaseToken] as String,
        receipt = json[_MakePurchaseResultKeys._receipt] == null
            ? null
            : json[_MakePurchaseResultKeys._receipt] as String;

  @override
  String toString() =>
      '${_MakePurchaseResultKeys._purchaseToken}: $purchaseToken, '
      '${_MakePurchaseResultKeys._purchaseType}: $purchaseType, '
      '${_MakePurchaseResultKeys._receipt}: $receipt';
}

class _MakePurchaseResultKeys {
  static const _purchaseToken = "purchaseToken";
  static const _purchaseType = "purchaseType";
  static const _receipt = "receipt";
}

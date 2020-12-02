import 'package:adapty_flutter/models/adapty_product.dart';
import 'package:adapty_flutter/models/adapty_purchaser_info.dart';

class MakePurchaseResult {
  final AdaptyPurchaserInfo purchaserInfo; // nullable
  final AdaptyProduct product; // nullable

  /// iOS specific
  final String receipt; // nullable

  /// Android specific
  final String purchaseToken;

  MakePurchaseResult.fromJson(Map<String, dynamic> json)
      : purchaserInfo = json.containsKey(_Keys.purchaserInfo) ? AdaptyPurchaserInfo.fromJson(json[_Keys.purchaserInfo]) : null,
        product = json.containsKey(_Keys.product) ? AdaptyProduct.fromJson(json[_Keys.product]) : null,
        purchaseToken = json[_Keys.purchaseToken],
        receipt = json[_Keys.receipt];

  @override
  String toString() => '${_Keys.purchaseToken}: $purchaseToken, '
      '${_Keys.receipt}: $receipt';
}

class _Keys {
  static const purchaserInfo = "purchaserInfo";
  static const product = "product";
  static const purchaseToken = "purchaseToken";
  static const receipt = "receipt";
}

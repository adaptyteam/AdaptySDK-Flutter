import '../adapty_purchaser_info.dart';

class RestorePurchasesResult {
  final AdaptyPurchaserInfo? purchaserInfo; // nullable

  /// iOS specific
  final String? receipt; // nullable

  // /// Android specific
  final String? googleValidationResult;

  RestorePurchasesResult.fromJson(Map<String, dynamic> json)
      : purchaserInfo = json.containsKey(_Keys.purchaserInfo)
            ? AdaptyPurchaserInfo.fromMap(json[_Keys.purchaserInfo])
            : null,
        receipt = json[_Keys.receipt],
        googleValidationResult = json[_Keys.googleValidationResult];

  @override
  String toString() => '${_Keys.purchaserInfo}: $purchaserInfo, '
      '${_Keys.receipt}: $receipt'
      '${_Keys.googleValidationResult}: $googleValidationResult';
}

class _Keys {
  static const purchaserInfo = "purchaserInfo";
  static const receipt = "receipt";
  static const googleValidationResult = "googleValidationResult";
}

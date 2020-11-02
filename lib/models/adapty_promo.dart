import 'package:adapty_flutter/models/adapty_product.dart';
import 'package:adapty_flutter/models/adapty_result.dart';

class AdaptyPromo extends AdaptyResult {
  final String id;
  final String promoType;
  final int expiresAt;
  final String paywallId;
  final String paywallDeveloperId;
  final List<AdaptyProduct> paywallProducts;

  AdaptyPromo(
      {this.id,
      this.promoType,
      this.expiresAt,
      this.paywallId,
      this.paywallDeveloperId,
      this.paywallProducts,
      errorCode,
      errorMessage})
      : super(errorCode: errorCode, errorMessage: errorMessage);

  AdaptyPromo.fromJson(Map<String, dynamic> json)
      : id = json[_AdaptyPromoKeys._id] as String,
        promoType = json[_AdaptyPromoKeys._promoType] as String,
        expiresAt = json[_AdaptyPromoKeys._expiresAt] as int,
        paywallId = json[_AdaptyPromoKeys._paywallId] as String,
        paywallDeveloperId =
            json[_AdaptyPromoKeys._paywallDeveloperId] as String,
        paywallProducts = (json[_AdaptyPromoKeys._paywallProducts] as List)
            .map((e) => AdaptyProduct.fromJson(e))
            .toList();

  @override
  String toString() => '${_AdaptyPromoKeys._id}: $id, '
      '${_AdaptyPromoKeys._promoType}: $promoType, '
      '${_AdaptyPromoKeys._expiresAt}: $expiresAt, '
      '${_AdaptyPromoKeys._paywallId}: $paywallId, '
      '${_AdaptyPromoKeys._paywallDeveloperId}: $paywallDeveloperId, '
      '${_AdaptyPromoKeys._paywallProducts}: ${paywallProducts.join(' ')}';
}

class _AdaptyPromoKeys {
  static const _id = "id";
  static const _promoType = "promoType";
  static const _expiresAt = "expiresAt";
  static const _paywallId = "paywallId";
  static const _paywallDeveloperId = "paywallDeveloperId";
  static const _paywallProducts = "paywallProducts";
}

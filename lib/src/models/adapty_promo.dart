import '../helpers/extensions.dart';
import 'adapty_paywall.dart';

class AdaptyPromo {
  /// The type of the promo offer.
  final String? promoType;

  /// The identifier of the variation, used to attribute purchases to the promo.
  final String? variationId;

  /// The time when the current promo offer will expire.
  final DateTime? expiresAt;

  /// A [AdaptyPaywall] object.
  final AdaptyPaywall? paywall;

  AdaptyPromo.fromJson(Map<String, dynamic> json)
      : promoType = json[_Keys.promoType],
        expiresAt = json.dateTimeOrNull(_Keys.expiresAt),
        variationId = json[_Keys.variationId],
        paywall = json[_Keys.paywall] != null
            ? AdaptyPaywall.fromMap(json[_Keys.paywall])
            : null;

  @override
  String toString() => '${_Keys.promoType}: $promoType, '
      '${_Keys.variationId}: $variationId, '
      '${_Keys.expiresAt}: $expiresAt, '
      '${_Keys.paywall}: $paywall';
}

class _Keys {
  static const promoType = "promoType";
  static const variationId = "variationId";
  static const expiresAt = "expiresAt";
  static const paywall = "paywall";
}

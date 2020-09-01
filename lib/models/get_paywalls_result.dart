import 'package:adapty_flutter/models/adapty_result.dart';
import 'package:adapty_flutter/models/adapty_product.dart';

class GetPaywallsResult extends AdaptyResult {
  final List<String> paywalls;
  final List<AdaptyProduct> products;

  GetPaywallsResult(this.paywalls, this.products, {errorCode, errorMessage})
      : super(errorCode: errorCode, errorMessage: errorMessage);

  GetPaywallsResult.fromJson(Map<String, dynamic> json)
      : paywalls = List<String>.from(json[_GetPaywallsResultKeys._paywalls]),
        products = (json[_GetPaywallsResultKeys._products] as List)
            .map((e) => AdaptyProduct.fromJson(e))
            .toList();

  @override
  String toString() {
    return '${_GetPaywallsResultKeys._paywalls}: ${paywalls.join(' ')}, '
        '${_GetPaywallsResultKeys._products}: ${products.join(' ')}';
  }
}

class _GetPaywallsResultKeys {
  static const String _paywalls = "paywalls";
  static const String _products = "products";
}

import 'package:adapty_flutter/models/adapty_paywall.dart';
import 'package:adapty_flutter/models/adapty_product.dart';
import 'package:adapty_flutter/results/adapty_result.dart';

class GetPaywallsResult extends AdaptyResult {
  final List<AdaptyPaywall> paywalls;
  final List<AdaptyProduct> products;

  GetPaywallsResult.fromMap(Map<String, dynamic> map)
      : paywalls = map[_Keys.paywalls] != null ? (map[_Keys.paywalls] as List).map((e) => AdaptyPaywall.fromMap(e)).toList() : null,
        products = map[_Keys.products] != null ? (map[_Keys.products] as List).map((e) => AdaptyProduct.fromMap(e)).toList() : null;

  @override
  String toString() => '${_Keys.paywalls}: ${paywalls.join(' ')}, '
      '${_Keys.products}: ${products.join(' ')}';
}

class _Keys {
  static const String paywalls = "paywalls";
  static const String products = "products";
}

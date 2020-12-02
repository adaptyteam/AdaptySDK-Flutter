import 'package:adapty_flutter/models/adapty_paywall.dart';
import 'package:adapty_flutter/models/adapty_product.dart';
import 'package:adapty_flutter/results/adapty_result.dart';
import 'package:adapty_flutter/models/adapty_enums.dart';

class GetPaywallsResult extends AdaptyResult {
  final List<AdaptyPaywall> paywalls;
  final List<AdaptyProduct> products;
  final AdaptyDataState dataState;

  GetPaywallsResult.fromJson(Map<String, dynamic> json)
      : paywalls = (json[_GetPaywallsResultKeys.paywalls] as List).map((e) => AdaptyPaywall.fromJson(e)).toList(),
        products = (json[_GetPaywallsResultKeys.products] as List).map((e) => AdaptyProduct.fromJson(e)).toList(),
        dataState = dataStateFromInt(json[_GetPaywallsResultKeys.dataState] as int);

  @override
  String toString() => '${_GetPaywallsResultKeys.paywalls}: ${paywalls.join(' ')}, '
      '${_GetPaywallsResultKeys.products}: ${products.join(' ')}';
}

class _GetPaywallsResultKeys {
  static const String paywalls = "paywalls";
  static const String products = "products";
  static const String dataState = "dataState";
}

import '../models/adapty_product.dart';

class VisualPaywallPurchaseFailResult {
  final AdaptyProduct? product;
  final String errorString;

  VisualPaywallPurchaseFailResult.fromJson(Map<String, dynamic> json)
      : product = json.containsKey(_Keys.product)
            ? AdaptyProduct.fromMap(json[_Keys.product])
            : null,
        errorString = json[_Keys.errorString];

  @override
  String toString() => '${_Keys.product}: $product, '
      '${_Keys.errorString}: $errorString';
}

class _Keys {
  static const product = "product";
  static const errorString = "errorString";
}

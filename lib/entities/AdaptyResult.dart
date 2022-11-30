//
//  AdaptyResult.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//
import 'package:meta/meta.dart' show immutable;
import 'AdaptyError.dart';
import 'AdaptyProfile.dart';
import 'AdaptyPaywall.dart';
import 'AdaptyPaywallProduct.dart';

part '../entities.json/AdaptyResultJSONBuilder.dart';

@immutable
class AdaptyResult {
  final dynamic _success;

  /// [Nullable]
  final AdaptyError? error;

  const AdaptyResult._error(this.error) : this._success = null;
  const AdaptyResult._success(this._success) : this.error = null;

  @override
  String toString() => error == null ? '(success: $_success)' : '(error: $error)';

  AdaptyProfile extructProfile() => AdaptyProfileJSONBuilder.fromJsonValue(_success);
  AdaptyPaywall extructPaywall() => AdaptyPaywallJSONBuilder.fromJsonValue(_success);
  AdaptyPaywallProduct extructPaywallProduct() => AdaptyPaywallProductJSONBuilder.fromJsonValue(_success);
  List<AdaptyPaywallProduct> extructPaywallProductList() => (_success as List).map((e) => AdaptyPaywallProductJSONBuilder.fromJsonValue(e)).toList(growable: false);
}

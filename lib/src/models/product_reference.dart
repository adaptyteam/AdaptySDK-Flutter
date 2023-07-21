//
//  product_reference.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;

import 'private/json_builder.dart';
import 'adapty_sdk_native.dart';

part 'private/product_reference_json_builder.dart';

@immutable
class ProductReference {
  final String vendorId;
  final String? androidBasePlanId;
  final String? androidOfferId;
  final String? iosDiscountId;

  const ProductReference._(this.vendorId, this.androidBasePlanId, this.androidOfferId, this.iosDiscountId);

  String toString() => '(vendorId: $vendorId, '
      'androidBasePlanId: $androidBasePlanId, '
      'androidOfferId: $androidOfferId, '
      'iosDiscountId: $iosDiscountId)';
}

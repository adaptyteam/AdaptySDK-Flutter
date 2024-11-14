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
  final String _adaptyProductId;

  final String? promotionalOfferId; // iOS Only
  final String? winBackOfferId; // iOS Only
  final String? basePlanId; // Android Only
  final String? offerId; // Android Only

  const ProductReference._(
    this.vendorId,
    this._adaptyProductId,
    this.promotionalOfferId,
    this.winBackOfferId,
    this.basePlanId,
    this.offerId,
  );

  String toString() => '(vendorId: $vendorId, '
      '_adaptyProductId: $_adaptyProductId, '
      'promotionalOfferId: $promotionalOfferId, '
      'winBackOfferId: $winBackOfferId, '
      'basePlanId: $basePlanId, '
      'offerId: $offerId)';
}

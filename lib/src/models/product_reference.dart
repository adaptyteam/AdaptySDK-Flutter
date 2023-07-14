//
//  product_reference.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;

import 'private/json_builder.dart';
import 'adapty_eligibility.dart';
import 'adapty_sdk_native.dart';

part 'private/product_reference_json_builder.dart';

@immutable
class ProductReference {
  final String vendorId;
  final bool promotionalOfferEligibility;
  final String? promotionalOfferId;

  const ProductReference._(
    this.vendorId,
    this.promotionalOfferEligibility,
    this.promotionalOfferId,
  );

  String toString() => '(vendorId: $vendorId, '
      'promotionalOfferEligibility: $promotionalOfferEligibility, '
      'promotionalOfferId: $promotionalOfferId)';
}

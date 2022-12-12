//
//  backend_product.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;

import 'private/json_builder.dart';
import 'adapty_eligibility.dart';
import 'adapty_sdk_native.dart';

part 'private/backend_product_json_builder.dart';

@immutable
class BackendProduct {
  final String vendorId;
  final bool promotionalOfferEligibility;
  final AdaptyEligibility introductoryOfferEligibility;
  final String? promotionalOfferId;
  final int _version;

  const BackendProduct._(
    this.vendorId,
    this.promotionalOfferEligibility,
    this.introductoryOfferEligibility,
    this.promotionalOfferId,
    this._version,
  );

  String toString() => '(vendorId: $vendorId, '
      'promotionalOfferEligibility: $promotionalOfferEligibility, '
      'introductoryOfferEligibility: $introductoryOfferEligibility, '
      'promotionalOfferId: $promotionalOfferId, '
      '_version: $_version)';
}

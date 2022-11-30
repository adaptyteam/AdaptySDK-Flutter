//
//  BackendProduct.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'dart:io';
import 'package:meta/meta.dart' show immutable;

import '../entities.json/JSONBuilder.dart';
import 'AdaptyEligibility.dart';

part '../entities.json/BackendProductJSONBuilder.dart';

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

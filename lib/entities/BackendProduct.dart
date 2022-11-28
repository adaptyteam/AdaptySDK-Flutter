//
//  BackendProduct.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'dart:io';

import 'package:meta/meta.dart';
import 'AdaptyEligibility.dart';

part  '../entities.json/BackendProduct.dart';

@immutable
class BackendProduct {
  final String vendorId;
  final bool promotionalOfferEligibility;
  final AdaptyEligibility introductoryOfferEligibility;
  final String? promotionalOfferId;
  final int _version2;

  const BackendProduct(
    this.vendorId,
    this.promotionalOfferEligibility,
    this.introductoryOfferEligibility,
    this.promotionalOfferId,
    this._version2,
  );
}
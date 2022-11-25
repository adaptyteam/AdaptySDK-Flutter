//
//  BackendProduct.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart';
import '../entities/AdaptyEligibility.dart';

@immutable
class BackendProduct {
  final String vendorId;
  final bool promotionalOfferEligibility;
  final AdaptyEligibility introductoryOfferEligibility;
  final String? promotionalOfferId;
  final int _version;

  const BackendProduct(
    this.vendorId,
    this.promotionalOfferEligibility,
    this.introductoryOfferEligibility,
    this.promotionalOfferId,
    this._version,
  );
}
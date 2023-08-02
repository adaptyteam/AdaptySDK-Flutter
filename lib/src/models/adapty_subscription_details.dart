//
//  adapty_subscription_details.dart
//  Adapty
//
//  Created by Aleksei Valiano on 20.07.2023.
//

import 'package:meta/meta.dart' show immutable;
import 'adapty_renewal_type.dart';
import 'adapty_sdk_native.dart';
import 'private/json_builder.dart';
import 'adapty_eligibility.dart';
import 'adapty_subscription_period.dart';

import 'adapty_subscription_phase.dart';

part 'private/adapty_subscription_details_json_builder.dart';

@immutable
class AdaptySubscriptionDetails {
  /// The identifier of the subscription group to which the subscription belongs. (Will be `nil` for iOS version below 12.0 and macOS version below 10.14).
  final String? subscriptionGroupIdentifier;
  final AdaptyEligibility? androidIntroductoryOfferEligibility;

  final String? androidBasePlanId;
  final String? androidOfferId;
  final List<String> androidOfferTags;
  final List<AdaptySubscriptionPhase> introductoryOffer;
  final AdaptySubscriptionPhase? promotionalOffer;

  final AdaptyRenewalType renewalType;
  final AdaptySubscriptionPeriod subscriptionPeriod;
  final String? localizedSubscriptionPeriod;

  /// User's eligibility for the promotional offers. Check this property before displaying info about promotional offers.
  bool get promotionalOfferEligibility => promotionalOffer != null;

  /// An identifier of a promotional offer, provided by Adapty for this specific user.
  String? get promotionalOfferId => promotionalOffer?.identifier;

  const AdaptySubscriptionDetails._(
    this.subscriptionGroupIdentifier,
    this.androidIntroductoryOfferEligibility,
    this.androidBasePlanId,
    this.androidOfferId,
    this.androidOfferTags,
    this.introductoryOffer,
    this.promotionalOffer,
    this.renewalType,
    this.subscriptionPeriod,
    this.localizedSubscriptionPeriod,
  );

  @override
  String toString() => '(subscriptionGroupIdentifier: $subscriptionGroupIdentifier, '
      'subscriptionPeriod: $subscriptionPeriod, '
      'localizedSubscriptionPeriod: $localizedSubscriptionPeriod, '
      'introductoryOffer: $introductoryOffer, '
      'promotionalOffer: $promotionalOffer, '
      'androidOfferId: $androidOfferId, '
      'androidBasePlanId: $androidBasePlanId, '
      'androidOfferTags: $androidOfferTags, '
      'renewalType: $renewalType, '
      '_androidIntroductoryOfferEligibility: $androidIntroductoryOfferEligibility)';
}

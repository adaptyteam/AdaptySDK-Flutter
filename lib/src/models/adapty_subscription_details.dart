//
//  adapty_subscription_details.dart
//  Adapty
//
//  Created by Aleksei Valiano on 20.07.2023.
//

import 'package:meta/meta.dart' show immutable;
import 'adapty_sdk_native.dart';
import 'private/json_builder.dart';
import 'adapty_eligibility.dart';

import 'adapty_subscription_phase.dart';

part 'private/adapty_subscription_details_json_builder.dart';

@immutable
class AdaptySubscriptionDetails {
  /// The identifier of the subscription group to which the subscription belongs. (Will be `nil` for iOS version below 12.0 and macOS version below 10.14).
  final String? subscriptionGroupIdentifier;
  final AdaptyEligibility? _androidIntroductoryOfferEligibility;
  final String offerId;
  final List<String> offerTags;
  final List<AdaptySubscriptionPhase> subscriptionPhases;

  /// User's eligibility for the promotional offers. Check this property before displaying info about promotional offers.
  bool get promotionalOfferEligibility => promotionalOfferId != null;

  /// An identifier of a promotional offer, provided by Adapty for this specific user.
  String? get promotionalOfferId => offerId;

  const AdaptySubscriptionDetails._(
    this.subscriptionGroupIdentifier,
    this._androidIntroductoryOfferEligibility,
    this.offerId,
    this.offerTags,
    this.subscriptionPhases,
  );

  @override
  String toString() => '(subscriptionGroupIdentifier: $subscriptionGroupIdentifier, '
      'offerId: $offerId, '
      'offerTags: $offerTags, '
      '_androidIntroductoryOfferEligibility: $_androidIntroductoryOfferEligibility, '
      'subscriptionPhases: $subscriptionPhases)';
}

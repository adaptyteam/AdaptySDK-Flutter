//
//  adapty_subscription_details.dart
//  Adapty
//
//  Created by Aleksei Valiano on 20.07.2023.
//

import 'package:meta/meta.dart' show immutable;

import 'adapty_renewal_type.dart';
import 'private/json_builder.dart';
import 'adapty_subscription_period.dart';
import 'adapty_subscription_offer.dart';
import 'adapty_subscription_offer_identifier.dart';
import 'adapty_subscription_pricing_terms.dart';

part 'private/adapty_product_subscription_json_builder.dart';

@immutable
class AdaptyProductSubscription {
  /// The identifier of the subscription group to which the subscription belongs. (Will be `nil` for iOS version below 12.0 and macOS version below 10.14).
  /// iOS Only.
  final String? groupIdentifier;

  /// The subscription period. For a product with a monthly plan it is the whole commitment;
  /// see [pricingTerms].
  final AdaptySubscriptionPeriod period;

  /// The localized subscription period. For a product with a monthly plan it is the whole
  /// commitment; see [pricingTerms].
  final String? localizedPeriod;

  final AdaptySubscriptionOffer? offer;

  /// The type of the subscription renewal
  final AdaptyRenewalType renewalType;

  /// The identifier of the base plan. Android Only.
  final String? basePlanId;

  /// How the subscription is billed: its plan, the payment per billing period and the total.
  ///
  /// On iOS every subscription has pricing terms, billed [AdaptySubscriptionBillingPlan.upFront]
  /// unless the paywall offers another plan (iOS 26.4 or later, apps built with Xcode 26.5 or
  /// later, not in every storefront). With a monthly plan, the product's price, [period] and
  /// [localizedPeriod] cover the whole commitment: show the installment from
  /// [AdaptySubscriptionPricingTerms.billingPrice] and
  /// [AdaptySubscriptionPricingTerms.billingPeriod]. `null` on Android.
  final AdaptySubscriptionPricingTerms? pricingTerms;

  const AdaptyProductSubscription._(
    this.groupIdentifier,
    this.period,
    this.localizedPeriod,
    this.offer,
    this.renewalType,
    this.basePlanId,
    this.pricingTerms,
  );

  @override
  String toString() => '(groupIdentifier: $groupIdentifier, '
      'period: $period, '
      'localizedPeriod: $localizedPeriod, '
      'offer: $offer, '
      'renewalType: $renewalType, '
      'basePlanId: $basePlanId, '
      'pricingTerms: $pricingTerms)';
}

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
import 'adapty_subscription_pricing_terms.dart';

part 'private/adapty_product_subscription_json_builder.dart';

@immutable
class AdaptyProductSubscription {
  /// The identifier of the subscription group to which the subscription belongs. (Will be `nil` for iOS version below 12.0 and macOS version below 10.14).
  /// iOS Only.
  final String? groupIdentifier;

  final AdaptySubscriptionPeriod period;

  final String? localizedPeriod;

  final AdaptySubscriptionOffer? offer;

  /// The type of the subscription renewal
  final AdaptyRenewalType renewalType;

  /// The identifier of the base plan. Android Only.
  final String? basePlanId;

  /// How the subscription is billed: its billing plan, the payment for each billing period
  /// and the total the user commits to.
  ///
  /// On iOS every subscription product has pricing terms. Their billing plan is
  /// [AdaptySubscriptionBillingPlan.upFront] unless the product is offered with another plan,
  /// such as [AdaptySubscriptionBillingPlan.monthly]. Plans other than up front need iOS 26.4
  /// or later and an app built with Xcode 26.5 or later, and are not offered in every
  /// storefront; elsewhere the product is billed up front.
  ///
  /// For a product with a monthly plan, the product's price, [period] and [localizedPeriod]
  /// describe the whole commitment, for example 12 months. Show the installment from
  /// [AdaptySubscriptionPricingTerms.billingPrice] and
  /// [AdaptySubscriptionPricingTerms.billingPeriod] too.
  ///
  /// Purchasing the product buys the plan these terms describe. Paywalls built in the Adapty
  /// Flow Builder do not offer plans other than up front; to sell one, build your own paywall.
  ///
  /// `null` on Android.
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

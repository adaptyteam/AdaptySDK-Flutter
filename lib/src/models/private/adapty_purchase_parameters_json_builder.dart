part of '../adapty_purchase_parameters.dart';

extension AdaptyPurchaseParametersJSONBuilder on AdaptyPurchaseParameters {
  dynamic get jsonValue => {
        if (subscriptionUpdateParams != null) _Keys.subscriptionUpdateParams: subscriptionUpdateParams?.jsonValue,
        if (isOfferPersonalized != null) _Keys.isOfferPersonalized: isOfferPersonalized,
        if (obfuscatedAccountId != null) _Keys.obfuscatedAccountId: obfuscatedAccountId,
        if (obfuscatedProfileId != null) _Keys.obfuscatedProfileId: obfuscatedProfileId,
      };
}

class _Keys {
  static const subscriptionUpdateParams = 'subscription_update_params';
  static const isOfferPersonalized = 'is_offer_personalized';
  static const obfuscatedAccountId = 'obfuscated_account_id';
  static const obfuscatedProfileId = 'obfuscated_profile_id';
}

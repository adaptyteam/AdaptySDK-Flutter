import 'adapty_android_subscription_update_parameters.dart';

part 'private/adapty_purchase_parameters_json_builder.dart';

class AdaptyPurchaseParameters {
  /// Used to upgrade or downgrade a subscription (use for Android).
  AdaptyAndroidSubscriptionUpdateParameters? subscriptionUpdateParams;

  /// Specifies whether the offer is personalized to the buyer (use for Android).
  bool? isOfferPersonalized;

  /// The obfuscated account identifier (use for Android), [read more](https://developer.android.com/google/play/billing/developer-payload#attribute).
  String? obfuscatedAccountId;

  /// The obfuscated profile identifier (use for Android), [read more](https://developer.android.com/google/play/billing/developer-payload#attribute).
  String? obfuscatedProfileId;

  AdaptyPurchaseParameters({
    this.subscriptionUpdateParams = null,
    this.isOfferPersonalized = null,
    this.obfuscatedAccountId = null,
    this.obfuscatedProfileId = null,
  });
}

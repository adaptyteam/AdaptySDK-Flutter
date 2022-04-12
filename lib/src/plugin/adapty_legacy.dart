import '../adapty.dart';
import '../models/adapty_android_subscription_update_params.dart';
import '../models/adapty_enums.dart';
import '../models/adapty_paywall.dart';
import '../models/adapty_product.dart';
import '../models/adapty_profile.dart';
import '../models/adapty_promo.dart';
import '../models/adapty_purchaser_info.dart';
import '../results/get_paywalls_result.dart';
import '../results/make_purchase_result.dart';
import '../results/restore_purchases_result.dart';
import 'adapty_plugin.dart';

@Deprecated('Please, use `Adapty.instance` from `adapty_flutter.dart`')
class AdaptyLegacy {
  static Stream<String> get deferredPurchasesStream =>
      Adapty.instance.deferredPurchasesStream;
  static Stream<GetPaywallsResult> get getPaywallsResultStream =>
      Adapty.instance.getPaywallsResultStream;
  static Stream<AdaptyPurchaserInfo> get purchaserInfoUpdateStream =>
      Adapty.instance.purchaserInfoUpdateStream;
  static Stream<AdaptyPromo> get promosReceiveStream =>
      Adapty.instance.promosReceiveStream;

  static void activate() => Adapty.instance.activate();

  static Future<void> setLogLevel(AdaptyLogLevel value) {
    return Adapty.instance.setLogLevel(value);
  }

  static Future<AdaptyLogLevel> getLogLevel() {
    return Adapty.instance.getLogLevel();
  }

  static Future<bool> identify(String customerUserId) {
    return Adapty.instance.identify(customerUserId);
  }

  static Future<GetPaywallsResult> getPaywalls({
    bool forceUpdate = false,
  }) {
    return Adapty.instance.getPaywalls(forceUpdate: forceUpdate);
  }

  static Future<AdaptyPurchaserInfo> getPurchaserInfo({
    bool forceUpdate = false,
  }) {
    return Adapty.instance.getPurchaserInfo(forceUpdate: forceUpdate);
  }

  static Future<bool> updateProfile(AdaptyProfileParameterBuilder builder) {
    return Adapty.instance.updateProfile(builder);
  }

  static Future<MakePurchaseResult> makePurchase(
    AdaptyProduct product, {
    String? offerId,
    AdaptyAndroidSubscriptionUpdateParams? subscriptionUpdateParams,
  }) {
    return Adapty.instance.makePurchase(
      product,
      offerId: offerId,
      subscriptionUpdateParams: subscriptionUpdateParams,
    );
  }

  static Future<RestorePurchasesResult> restorePurchases() {
    return Adapty.instance.restorePurchases();
  }

  static Future<bool> updateAttribution(Map attribution,
      {required AdaptyAttributionNetwork source, String? networkUserId}) {
    return Adapty.instance.updateAttribution(
      attribution,
      source: source,
      networkUserId: networkUserId,
    );
  }

  static Future<void> logShowPaywall({required AdaptyPaywall paywall}) {
    return Adapty.instance.logShowPaywall(paywall: paywall);
  }

  static Future<AdaptyPromo?> getPromo() {
    return Adapty.instance.getPromo();
  }

  static Future<void> setExternalAnalyticsEnabled(bool enabled) {
    return Adapty.instance.setExternalAnalyticsEnabled(enabled);
  }

  static Future<void> setTransactionVariationId(
      String transactionId, String variationId) {
    return Adapty.instance.setTransactionVariationId(
      transactionId: transactionId,
      variationId: variationId,
    );
  }

  static Future<void> setFallbackPaywalls(String paywalls) {
    return Adapty.instance.setFallbackPaywalls(paywalls);
  }

  static Future<bool> logout() {
    return Adapty.instance.logout();
  }

  // ––––––– VISUAL PAYWALLS METHODS –––––––

  static Future<bool> showVisualPaywall({
    required AdaptyPaywall paywall,
    AdaptyVisualPaywallPurchaseSuccessResult? onPurchaseSuccess,
    AdaptyVisualPaywallPurchaseFailResult? onPurchaseFail,
    AdaptyVisualPaywallCancelResult? onCancel,
    AdaptyVisualPaywallRestoreResult? onRestore,
  }) {
    return Adapty.instance.showVisualPaywall(
      paywall: paywall,
      onPurchaseSuccess: onPurchaseSuccess,
      onPurchaseFail: onPurchaseFail,
      onCancel: onCancel,
      onRestore: onRestore,
    );
  }

  static Future<bool> closeVisualPaywall() {
    return Adapty.instance.closeVisualPaywall();
  }

  // ––––––– IOS ONLY METHODS –––––––

  static Future<void> setApnsToken(String token) {
    return Adapty.instance.setApnsToken(token);
  }

  static Future<void> handlePushNotification(Map userInfo) {
    return Adapty.instance.handlePushNotification(userInfo);
  }

  static Future<MakePurchaseResult?> makeDeferredPurchase(String productId) {
    return makeDeferredPurchase(productId);
  }

  static Future<void> presentCodeRedemptionSheet() {
    return Adapty.instance.presentCodeRedemptionSheet();
  }

  // ––––––– ANDROID ONLY METHODS –––––––

  static Future<bool> newPushToken(String token) {
    return Adapty.instance.newPushToken(token);
  }

  static Future<bool> pushReceived(Map<String, String> message) {
    return Adapty.instance.pushReceived(message);
  }
}

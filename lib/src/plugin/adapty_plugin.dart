import '../models/adapty_android_subscription_update_params.dart';
import '../models/adapty_enums.dart';
import '../models/adapty_paywall.dart';
import '../models/adapty_product.dart';
import '../models/adapty_profile.dart';
import '../models/adapty_promo.dart';
import '../models/adapty_purchaser_info.dart';
import '../models/results/get_paywalls_result.dart';
import '../models/results/make_purchase_result.dart';
import '../models/results/restore_purchases_result.dart';
import '../models/results/visual_paywall_purchase_fail_result.dart';

typedef AdaptyVisualPaywallPurchaseSuccessResult = void Function(
  MakePurchaseResult,
);
typedef AdaptyVisualPaywallPurchaseFailResult = void Function(
  VisualPaywallPurchaseFailResult,
);
typedef AdaptyVisualPaywallCancelResult = void Function();
typedef AdaptyVisualPaywallRestoreResult = void Function(
  RestorePurchasesResult,
);

abstract class AdaptyPlugin {
  Stream<String> get deferredPurchasesStream;
  Stream<GetPaywallsResult> get getPaywallsResultStream;
  Stream<AdaptyPurchaserInfo> get purchaserInfoUpdateStream;
  Stream<AdaptyPromo> get promosReceiveStream;

  void activate();

  Future<void> setLogLevel(AdaptyLogLevel value);

  Future<AdaptyLogLevel> getLogLevel();

  Future<bool> identify(String customerUserId);

  Future<GetPaywallsResult> getPaywalls({bool forceUpdate = false});

  Future<AdaptyPurchaserInfo> getPurchaserInfo({bool forceUpdate = false});

  Future<bool> updateProfile(AdaptyProfileParameterBuilder builder);

  Future<MakePurchaseResult> makePurchase(
    AdaptyProduct product, {
    String? offerId,
    AdaptyAndroidSubscriptionUpdateParams? subscriptionUpdateParams,
  });

  Future<RestorePurchasesResult> restorePurchases();

  Future<bool> updateAttribution(
    Map attribution, {
    required AdaptyAttributionNetwork source,
    String? networkUserId,
  });

  Future<void> logShowPaywall({required AdaptyPaywall paywall});

  Future<AdaptyPromo?> getPromo();

  Future<void> setExternalAnalyticsEnabled(bool enabled);

  Future<void> setTransactionVariationId({
    required String transactionId,
    required String variationId,
  });

  Future<void> setFallbackPaywalls(String paywalls);

  Future<bool> logout();

  // ––––––– VISUAL PAYWALLS METHODS –––––––

  Future<bool> showVisualPaywall({
    required AdaptyPaywall paywall,
    AdaptyVisualPaywallPurchaseSuccessResult? onPurchaseSuccess,
    AdaptyVisualPaywallPurchaseFailResult? onPurchaseFail,
    AdaptyVisualPaywallCancelResult? onCancel,
    AdaptyVisualPaywallRestoreResult? onRestore,
  });

  Future<bool> closeVisualPaywall();

  // ––––––– IOS ONLY METHODS –––––––

  Future<void> setApnsToken(String token);

  Future<void> handlePushNotification(Map userInfo);

  Future<MakePurchaseResult?> makeDeferredPurchase(String productId);

  Future<void> presentCodeRedemptionSheet();

  // ––––––– ANDROID ONLY METHODS –––––––

  Future<bool> newPushToken(String token);

  Future<bool> pushReceived(Map<String, String> message);
}

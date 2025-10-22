import 'adaptyui_observer.dart';

import 'adapty_logger.dart';
import 'models/adapty_error.dart';
import 'models/adapty_paywall_product.dart';
import 'models/adapty_purchase_result.dart';
import 'models/adapty_profile.dart';
import 'models/adaptyui/adaptyui_action.dart';
import 'models/adaptyui/adaptyui_paywall_view.dart';
import 'models/adaptyui/adaptyui_onboarding_view.dart';
import 'models/adaptyui/adaptyui_onboarding_meta.dart';
import 'models/adaptyui/adaptyui_onboarding_state_updated_params.dart';
import 'models/adaptyui/adaptyui_onboardings_analytics_event.dart';

class AdaptyUIDefaultPaywallsEventsObserverImpl implements AdaptyUIPaywallsEventsObserver {
  @override
  void paywallViewDidAppear(AdaptyUIPaywallView view) {}

  @override
  void paywallViewDidDisappear(AdaptyUIPaywallView view) {}

  @override
  void paywallViewDidFailLoadingProducts(
    AdaptyUIPaywallView view,
    AdaptyError error,
  ) {}

  @override
  void paywallViewDidFailPurchase(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct product,
    AdaptyError error,
  ) {}

  @override
  void paywallViewDidFailRendering(
    AdaptyUIPaywallView view,
    AdaptyError error,
  ) =>
      view.dismiss();

  @override
  void paywallViewDidStartRestore(
    AdaptyUIPaywallView view,
  ) {}

  @override
  void paywallViewDidFinishRestore(
    AdaptyUIPaywallView view,
    AdaptyProfile profile,
  ) {}

  @override
  void paywallViewDidFailRestore(
    AdaptyUIPaywallView view,
    AdaptyError error,
  ) {}

  @override
  void paywallViewDidFinishPurchase(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) =>
      view.dismiss();

  @override
  void paywallViewDidFinishWebPaymentNavigation(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) {}

  @override
  void paywallViewDidPerformAction(
    AdaptyUIPaywallView view,
    AdaptyUIAction action,
  ) {
    switch (action) {
      case const CloseAction():
      case const AndroidSystemBackAction():
        view.dismiss();
        break;
      default:
        break;
    }
  }

  @override
  void paywallViewDidSelectProduct(
    AdaptyUIPaywallView view,
    String productId,
  ) {}

  @override
  void paywallViewDidStartPurchase(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct product,
  ) {}
}

class AdaptyUIDefaultOnboardingsEventsObserverImpl implements AdaptyUIOnboardingsEventsObserver {
  @override
  void onboardingViewDidFailWithError(
    AdaptyUIOnboardingView view,
    AdaptyError error,
  ) {}

  @override
  void onboardingViewDidFinishLoading(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
  ) {}

  @override
  void onboardingViewOnAnalyticsEvent(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    AdaptyOnboardingsAnalyticsEvent event,
  ) {}

  @override
  void onboardingViewOnCloseAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {}

  @override
  void onboardingViewOnCustomAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {}

  @override
  void onboardingViewOnPaywallAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {}

  @override
  void onboardingViewOnStateUpdatedAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String elementId,
    AdaptyOnboardingsStateUpdatedParams params,
  ) {}
}

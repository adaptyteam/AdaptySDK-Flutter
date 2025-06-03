import 'adaptyui_observer.dart';

import 'models/adapty_error.dart';
import 'models/adapty_paywall_product.dart';
import 'models/adapty_profile.dart';
import 'models/adapty_purchase_result.dart';
import 'models/adaptyui/adaptyui_action.dart';
import 'models/adaptyui/adaptyui_onboarding_meta.dart';
import 'models/adaptyui/adaptyui_onboarding_state_updated_params.dart';
import 'models/adaptyui/adaptyui_onboarding_view.dart';
import 'models/adaptyui/adaptyui_onboardings_analytics_event.dart';
import 'models/adaptyui/adaptyui_paywall_view.dart';

class AdaptyUIEventsProxy implements AdaptyUIPaywallsEventsObserver, AdaptyUIOnboardingsEventsObserver {
  AdaptyUIPaywallsEventsObserver? paywallsEventsObserver;
  AdaptyUIOnboardingsEventsObserver? onboardingsEventsObserver;

  Map<String, AdaptyUIOnboardingsEventsObserver> _platformViewOnboardingsEventsObservers = {};

  void registerOnboardingEventsListener(AdaptyUIOnboardingsEventsObserver observer, String viewId) {
    _platformViewOnboardingsEventsObservers[viewId] = observer;
  }

  void unregisterOnboardingEventsListener(String viewId) {
    _platformViewOnboardingsEventsObservers.remove(viewId);
  }

  // MARK: - AdaptyUIPaywallsEventsObserver

  @override
  void paywallViewDidAppear(AdaptyUIPaywallView view) {
    paywallsEventsObserver?.paywallViewDidAppear(view);
  }

  @override
  void paywallViewDidDisappear(AdaptyUIPaywallView view) {
    paywallsEventsObserver?.paywallViewDidDisappear(view);
  }

  void paywallViewDidPerformAction(
    AdaptyUIPaywallView view,
    AdaptyUIAction action,
  ) {
    paywallsEventsObserver?.paywallViewDidPerformAction(view, action);
  }

  @override
  void paywallViewDidSelectProduct(
    AdaptyUIPaywallView view,
    String productId,
  ) {
    paywallsEventsObserver?.paywallViewDidSelectProduct(view, productId);
  }

  @override
  void paywallViewDidStartPurchase(AdaptyUIPaywallView view, AdaptyPaywallProduct product) {
    paywallsEventsObserver?.paywallViewDidStartPurchase(view, product);
  }

  @override
  void paywallViewDidFinishPurchase(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult result,
  ) {
    paywallsEventsObserver?.paywallViewDidFinishPurchase(view, product, result);
  }

  @override
  void paywallViewDidFailPurchase(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct product,
    AdaptyError error,
  ) {
    paywallsEventsObserver?.paywallViewDidFailPurchase(view, product, error);
  }

  @override
  void paywallViewDidStartRestore(AdaptyUIPaywallView view) {
    paywallsEventsObserver?.paywallViewDidStartRestore(view);
  }

  @override
  void paywallViewDidFinishRestore(
    AdaptyUIPaywallView view,
    AdaptyProfile profile,
  ) {
    paywallsEventsObserver?.paywallViewDidFinishRestore(view, profile);
  }

  @override
  void paywallViewDidFailRestore(
    AdaptyUIPaywallView view,
    AdaptyError error,
  ) {
    paywallsEventsObserver?.paywallViewDidFailRestore(view, error);
  }

  @override
  void paywallViewDidFailRendering(
    AdaptyUIPaywallView view,
    AdaptyError error,
  ) {
    paywallsEventsObserver?.paywallViewDidFailRendering(view, error);
  }

  @override
  void paywallViewDidFailLoadingProducts(
    AdaptyUIPaywallView view,
    AdaptyError error,
  ) {
    paywallsEventsObserver?.paywallViewDidFailLoadingProducts(view, error);
  }

  @override
  void paywallViewDidFinishWebPaymentNavigation(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) {
    paywallsEventsObserver?.paywallViewDidFinishWebPaymentNavigation(view, product, error);
  }

  // MARK: - AdaptyUIOnboardingsEventsObserver

  @override
  void onboardingViewDidFinishLoading(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
  ) {
    onboardingsEventsObserver?.onboardingViewDidFinishLoading(view, meta);
    _platformViewOnboardingsEventsObservers[view.id]?.onboardingViewDidFinishLoading(view, meta);
  }

  @override
  void onboardingViewDidFailWithError(
    AdaptyUIOnboardingView view,
    AdaptyError error,
  ) {
    onboardingsEventsObserver?.onboardingViewDidFailWithError(view, error);
    _platformViewOnboardingsEventsObservers[view.id]?.onboardingViewDidFailWithError(view, error);
  }

  @override
  void onboardingViewOnCloseAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {
    onboardingsEventsObserver?.onboardingViewOnCloseAction(view, meta, actionId);
    _platformViewOnboardingsEventsObservers[view.id]?.onboardingViewOnCloseAction(view, meta, actionId);
  }

  @override
  void onboardingViewOnPaywallAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {
    onboardingsEventsObserver?.onboardingViewOnPaywallAction(view, meta, actionId);
    _platformViewOnboardingsEventsObservers[view.id]?.onboardingViewOnPaywallAction(view, meta, actionId);
  }

  @override
  void onboardingViewOnCustomAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {
    onboardingsEventsObserver?.onboardingViewOnCustomAction(view, meta, actionId);
    _platformViewOnboardingsEventsObservers[view.id]?.onboardingViewOnCustomAction(view, meta, actionId);
  }

  @override
  void onboardingViewOnStateUpdatedAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String elementId,
    AdaptyOnboardingsStateUpdatedParams params,
  ) {
    onboardingsEventsObserver?.onboardingViewOnStateUpdatedAction(view, meta, elementId, params);
    _platformViewOnboardingsEventsObservers[view.id]?.onboardingViewOnStateUpdatedAction(view, meta, elementId, params);
  }

  @override
  void onboardingViewOnAnalyticsEvent(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    AdaptyOnboardingsAnalyticsEvent event,
  ) {
    onboardingsEventsObserver?.onboardingViewOnAnalyticsEvent(view, meta, event);
    _platformViewOnboardingsEventsObservers[view.id]?.onboardingViewOnAnalyticsEvent(view, meta, event);
  }
}

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

import 'adaptyui_events_defaults.dart';

class AdaptyUIEventsProxy implements AdaptyUIPaywallsEventsObserver, AdaptyUIOnboardingsEventsObserver {
  AdaptyUIPaywallsEventsObserver defaultPaywallsEventsObserver = AdaptyUIDefaultPaywallsEventsObserverImpl();
  AdaptyUIOnboardingsEventsObserver defaultOnboardingsEventsObserver = AdaptyUIDefaultOnboardingsEventsObserverImpl();

  AdaptyUIPaywallsEventsObserver? paywallsEventsObserver;
  AdaptyUIOnboardingsEventsObserver? onboardingsEventsObserver;

  Map<String, AdaptyUIPaywallsEventsObserver> _platformViewPaywallsEventsObservers = {};
  Map<String, AdaptyUIOnboardingsEventsObserver> _platformViewOnboardingsEventsObservers = {};

  void registerPaywallEventsListener(AdaptyUIPaywallsEventsObserver observer, String viewId) {
    _platformViewPaywallsEventsObservers[viewId] = observer;
  }

  void unregisterPaywallEventsListener(String viewId) {
    _platformViewPaywallsEventsObservers.remove(viewId);
  }

  void registerOnboardingEventsListener(AdaptyUIOnboardingsEventsObserver observer, String viewId) {
    _platformViewOnboardingsEventsObservers[viewId] = observer;
  }

  void unregisterOnboardingEventsListener(String viewId) {
    _platformViewOnboardingsEventsObservers.remove(viewId);
  }

  List<AdaptyUIPaywallsEventsObserver> _getPaywallViewEventsObservers(AdaptyUIPaywallView view) {
    final platformViewObserver = _platformViewPaywallsEventsObservers[view.id];

    return [
      if (platformViewObserver != null) platformViewObserver,
      if (paywallsEventsObserver != null) paywallsEventsObserver! else if (platformViewObserver == null) defaultPaywallsEventsObserver,
    ];
  }

  List<AdaptyUIOnboardingsEventsObserver> _getOnboardingViewEventsObservers(AdaptyUIOnboardingView view) {
    final platformViewObserver = _platformViewOnboardingsEventsObservers[view.id];

    return [
      if (platformViewObserver != null) platformViewObserver,
      if (onboardingsEventsObserver != null) onboardingsEventsObserver! else if (platformViewObserver == null) defaultOnboardingsEventsObserver,
    ];
  }

  // MARK: - AdaptyUIPaywallsEventsObserver

  @override
  void paywallViewDidAppear(AdaptyUIPaywallView view) {
    _getPaywallViewEventsObservers(view).forEach(
      (observer) => observer.paywallViewDidAppear(view),
    );
  }

  @override
  void paywallViewDidDisappear(AdaptyUIPaywallView view) {
    _getPaywallViewEventsObservers(view).forEach(
      (observer) => observer.paywallViewDidDisappear(view),
    );
  }

  void paywallViewDidPerformAction(
    AdaptyUIPaywallView view,
    AdaptyUIAction action,
  ) {
    _getPaywallViewEventsObservers(view).forEach(
      (observer) => observer.paywallViewDidPerformAction(view, action),
    );
  }

  @override
  void paywallViewDidSelectProduct(
    AdaptyUIPaywallView view,
    String productId,
  ) {
    _getPaywallViewEventsObservers(view).forEach(
      (observer) => observer.paywallViewDidSelectProduct(view, productId),
    );
  }

  @override
  void paywallViewDidStartPurchase(AdaptyUIPaywallView view, AdaptyPaywallProduct product) {
    _getPaywallViewEventsObservers(view).forEach(
      (observer) => observer.paywallViewDidStartPurchase(view, product),
    );
  }

  @override
  void paywallViewDidFinishPurchase(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult result,
  ) {
    _getPaywallViewEventsObservers(view).forEach(
      (observer) => observer.paywallViewDidFinishPurchase(view, product, result),
    );
  }

  @override
  void paywallViewDidFailPurchase(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct product,
    AdaptyError error,
  ) {
    _getPaywallViewEventsObservers(view).forEach(
      (observer) => observer.paywallViewDidFailPurchase(view, product, error),
    );
  }

  @override
  void paywallViewDidStartRestore(AdaptyUIPaywallView view) {
    _getPaywallViewEventsObservers(view).forEach(
      (observer) => observer.paywallViewDidStartRestore(view),
    );
  }

  @override
  void paywallViewDidFinishRestore(
    AdaptyUIPaywallView view,
    AdaptyProfile profile,
  ) {
    _getPaywallViewEventsObservers(view).forEach(
      (observer) => observer.paywallViewDidFinishRestore(view, profile),
    );
  }

  @override
  void paywallViewDidFailRestore(
    AdaptyUIPaywallView view,
    AdaptyError error,
  ) {
    _getPaywallViewEventsObservers(view).forEach(
      (observer) => observer.paywallViewDidFailRestore(view, error),
    );
  }

  @override
  void paywallViewDidFailRendering(
    AdaptyUIPaywallView view,
    AdaptyError error,
  ) {
    _getPaywallViewEventsObservers(view).forEach(
      (observer) => observer.paywallViewDidFailRendering(view, error),
    );
  }

  @override
  void paywallViewDidFailLoadingProducts(
    AdaptyUIPaywallView view,
    AdaptyError error,
  ) {
    _getPaywallViewEventsObservers(view).forEach(
      (observer) => observer.paywallViewDidFailLoadingProducts(view, error),
    );
  }

  @override
  void paywallViewDidFinishWebPaymentNavigation(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) {
    _getPaywallViewEventsObservers(view).forEach(
      (observer) => observer.paywallViewDidFinishWebPaymentNavigation(view, product, error),
    );
  }

  // MARK: - AdaptyUIOnboardingsEventsObserver

  @override
  void onboardingViewDidFinishLoading(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
  ) {
    _getOnboardingViewEventsObservers(view).forEach(
      (observer) => observer.onboardingViewDidFinishLoading(view, meta),
    );
  }

  @override
  void onboardingViewDidFailWithError(
    AdaptyUIOnboardingView view,
    AdaptyError error,
  ) {
    _getOnboardingViewEventsObservers(view).forEach(
      (observer) => observer.onboardingViewDidFailWithError(view, error),
    );
  }

  @override
  void onboardingViewOnCloseAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {
    _getOnboardingViewEventsObservers(view).forEach(
      (observer) => observer.onboardingViewOnCloseAction(view, meta, actionId),
    );
  }

  @override
  void onboardingViewOnPaywallAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {
    _getOnboardingViewEventsObservers(view).forEach(
      (observer) => observer.onboardingViewOnPaywallAction(view, meta, actionId),
    );
  }

  @override
  void onboardingViewOnCustomAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {
    _getOnboardingViewEventsObservers(view).forEach(
      (observer) => observer.onboardingViewOnCustomAction(view, meta, actionId),
    );
  }

  @override
  void onboardingViewOnStateUpdatedAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String elementId,
    AdaptyOnboardingsStateUpdatedParams params,
  ) {
    _getOnboardingViewEventsObservers(view).forEach(
      (observer) => observer.onboardingViewOnStateUpdatedAction(view, meta, elementId, params),
    );
  }

  @override
  void onboardingViewOnAnalyticsEvent(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    AdaptyOnboardingsAnalyticsEvent event,
  ) {
    _getOnboardingViewEventsObservers(view).forEach(
      (observer) => observer.onboardingViewOnAnalyticsEvent(view, meta, event),
    );
  }
}

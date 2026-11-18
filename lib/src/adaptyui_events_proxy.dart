// ignore_for_file: deprecated_member_use_from_same_package
import 'adapty_logger.dart';
import 'adaptyui_observer.dart';

import 'models/adapty_error.dart';
import 'models/adapty_log_level.dart';
import 'models/adapty_paywall_product.dart';
import 'models/adapty_profile.dart';
import 'models/adapty_purchase_result.dart';
import 'models/adaptyui/adaptyui_action.dart';
import 'models/adaptyui/adaptyui_onboarding_meta.dart';
import 'models/adaptyui/adaptyui_onboarding_state_updated_params.dart';
import 'models/adaptyui/adaptyui_onboarding_view.dart';
import 'models/adaptyui/adaptyui_onboardings_analytics_event.dart';
import 'models/adaptyui/adaptyui_flow_view.dart';

import 'adaptyui_events_defaults.dart';

class AdaptyUIEventsProxy implements AdaptyUIFlowsEventsObserver, AdaptyUIOnboardingsEventsObserver {
  AdaptyUIFlowsEventsObserver defaultFlowsEventsObserver = AdaptyUIDefaultFlowsEventsObserverImpl();
  AdaptyUIOnboardingsEventsObserver defaultOnboardingsEventsObserver = AdaptyUIDefaultOnboardingsEventsObserverImpl();

  AdaptyUIFlowsEventsObserver? flowsEventsObserver;
  AdaptyUIOnboardingsEventsObserver? onboardingsEventsObserver;

  Map<String, AdaptyUIFlowsEventsObserver> _platformViewFlowsEventsObservers = {};
  Map<String, AdaptyUIOnboardingsEventsObserver> _platformViewOnboardingsEventsObservers = {};

  /// Errors of flows shown by `AdaptyUIFlowPlatformView` that arrived while no widget listened
  /// for their view. On iOS the native view reports one below iOS 16, right after it is created,
  /// and when the flow fails to load, which can happen before the widget listens or after it is
  /// gone.
  final Map<String, (AdaptyUIFlowView, AdaptyError)> _pendingPlatformViewFlowErrors = {};
  static const _platformViewIdPrefix = 'flutter_native_';
  static const _maxPendingPlatformViewFlowErrors = 16;

  void registerFlowEventsListener(AdaptyUIFlowsEventsObserver observer, String viewId) {
    _platformViewFlowsEventsObservers[viewId] = observer;
    final pending = _pendingPlatformViewFlowErrors.remove(viewId);
    if (pending != null) {
      final (view, error) = pending;
      try {
        observer.flowViewDidReceiveError(view, error);
      } catch (e) {
        AdaptyLogger.write(AdaptyLogLevel.error, 'Error in flowViewDidReceiveError: $e');
      }
    }
  }

  void unregisterFlowEventsListener(String viewId) {
    _platformViewFlowsEventsObservers.remove(viewId);
    _pendingPlatformViewFlowErrors.remove(viewId);
  }

  void registerOnboardingEventsListener(AdaptyUIOnboardingsEventsObserver observer, String viewId) {
    _platformViewOnboardingsEventsObservers[viewId] = observer;
  }

  void unregisterOnboardingEventsListener(String viewId) {
    _platformViewOnboardingsEventsObservers.remove(viewId);
  }

  List<AdaptyUIFlowsEventsObserver> _getFlowViewEventsObservers(AdaptyUIFlowView view) {
    final platformViewObserver = _platformViewFlowsEventsObservers[view.id];

    return [
      if (platformViewObserver != null) platformViewObserver,
      if (flowsEventsObserver != null) flowsEventsObserver! else if (platformViewObserver == null) defaultFlowsEventsObserver,
    ];
  }

  List<AdaptyUIOnboardingsEventsObserver> _getOnboardingViewEventsObservers(AdaptyUIOnboardingView view) {
    final platformViewObserver = _platformViewOnboardingsEventsObservers[view.id];

    return [
      if (platformViewObserver != null) platformViewObserver,
      if (onboardingsEventsObserver != null) onboardingsEventsObserver! else if (platformViewObserver == null) defaultOnboardingsEventsObserver,
    ];
  }

  // MARK: - AdaptyUIFlowsEventsObserver

  @override
  void flowViewDidAppear(AdaptyUIFlowView view) {
    _getFlowViewEventsObservers(view).forEach(
      (observer) => observer.flowViewDidAppear(view),
    );
  }

  @override
  void flowViewDidDisappear(AdaptyUIFlowView view) {
    _getFlowViewEventsObservers(view).forEach(
      (observer) => observer.flowViewDidDisappear(view),
    );
  }

  void flowViewDidPerformAction(
    AdaptyUIFlowView view,
    AdaptyUIAction action,
  ) {
    _getFlowViewEventsObservers(view).forEach(
      (observer) => observer.flowViewDidPerformAction(view, action),
    );
  }

  @override
  void flowViewDidSelectProduct(
    AdaptyUIFlowView view,
    String productId,
  ) {
    _getFlowViewEventsObservers(view).forEach(
      (observer) => observer.flowViewDidSelectProduct(view, productId),
    );
  }

  @override
  void flowViewDidStartPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product) {
    _getFlowViewEventsObservers(view).forEach(
      (observer) => observer.flowViewDidStartPurchase(view, product),
    );
  }

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult result,
  ) {
    _getFlowViewEventsObservers(view).forEach(
      (observer) => observer.flowViewDidFinishPurchase(view, product, result),
    );
  }

  @override
  void flowViewDidFailPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyError error,
  ) {
    _getFlowViewEventsObservers(view).forEach(
      (observer) => observer.flowViewDidFailPurchase(view, product, error),
    );
  }

  @override
  void flowViewDidStartRestore(AdaptyUIFlowView view) {
    _getFlowViewEventsObservers(view).forEach(
      (observer) => observer.flowViewDidStartRestore(view),
    );
  }

  @override
  void flowViewDidFinishRestore(
    AdaptyUIFlowView view,
    AdaptyProfile profile,
  ) {
    _getFlowViewEventsObservers(view).forEach(
      (observer) => observer.flowViewDidFinishRestore(view, profile),
    );
  }

  @override
  void flowViewDidFailRestore(
    AdaptyUIFlowView view,
    AdaptyError error,
  ) {
    _getFlowViewEventsObservers(view).forEach(
      (observer) => observer.flowViewDidFailRestore(view, error),
    );
  }

  @override
  void flowViewDidReceiveError(
    AdaptyUIFlowView view,
    AdaptyError error,
  ) {
    if (view.id.startsWith(_platformViewIdPrefix) && !_platformViewFlowsEventsObservers.containsKey(view.id)) {
      if (_pendingPlatformViewFlowErrors.length >= _maxPendingPlatformViewFlowErrors) {
        _pendingPlatformViewFlowErrors.remove(_pendingPlatformViewFlowErrors.keys.first);
      }
      _pendingPlatformViewFlowErrors[view.id] = (view, error);
      flowsEventsObserver?.flowViewDidReceiveError(view, error);
      return;
    }
    _getFlowViewEventsObservers(view).forEach(
      (observer) => observer.flowViewDidReceiveError(view, error),
    );
  }

  @override
  void flowViewDidFailLoadingProducts(
    AdaptyUIFlowView view,
    AdaptyError error,
  ) {
    _getFlowViewEventsObservers(view).forEach(
      (observer) => observer.flowViewDidFailLoadingProducts(view, error),
    );
  }

  @override
  void flowViewDidFinishWebPaymentNavigation(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) {
    _getFlowViewEventsObservers(view).forEach(
      (observer) => observer.flowViewDidFinishWebPaymentNavigation(view, product, error),
    );
  }

  @override
  void flowViewDidReceiveAnalyticEvent(
    AdaptyUIFlowView view,
    String name,
    Map<String, dynamic> params,
  ) {
    _getFlowViewEventsObservers(view).forEach(
      (observer) => observer.flowViewDidReceiveAnalyticEvent(view, name, params),
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

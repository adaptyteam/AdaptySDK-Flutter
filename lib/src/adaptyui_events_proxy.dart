// ignore_for_file: deprecated_member_use_from_same_package
import 'adaptyui_observer.dart';
import 'constants/method.dart';
import 'runtime/adapty_diagnostics.dart';
import 'runtime/adapty_internal_error_sink.dart';

import 'models/adapty_error.dart';
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

/// The id prefix of a view shown by `AdaptyUIFlowPlatformView` or `AdaptyUIOnboardingPlatformView`.
const adaptyEmbeddedViewIdPrefix = 'flutter_native_';

class AdaptyUIEventsProxy implements AdaptyUIFlowsEventsObserver, AdaptyUIOnboardingsEventsObserver {
  AdaptyUIEventsProxy(this._diagnostics);

  /// Of the runtime this proxy belongs to: an observer that throws, a widget that throws on a replayed error and a
  /// pending error dropped for a newer one are reported there.
  final AdaptyDiagnostics _diagnostics;

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
  static const _maxPendingPlatformViewFlowErrors = 16;

  void registerFlowEventsListener(AdaptyUIFlowsEventsObserver observer, String viewId) {
    _platformViewFlowsEventsObservers[viewId] = observer;
    final pending = _pendingPlatformViewFlowErrors.remove(viewId);
    if (pending != null) {
      final (view, error) = pending;
      try {
        observer.flowViewDidReceiveError(view, error);
      } catch (e, s) {
        _diagnostics.errorSink.report(AdaptyInternalErrorRecord(
          AdaptyInternalErrorKind.observerThrew,
          e,
          stack: s,
          context: NativeEvent.flowViewDidReceiveError.wireName,
          where: 'flowViewDidReceiveError',
        ));
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

  /// Calls [call] on each of [observers] for [event]. An observer that throws does not stop the delivery: its error is
  /// reported as [AdaptyInternalErrorKind.observerThrew] under the wire name of [event], and the next observer still
  /// gets the event.
  void _notify<O>(NativeEvent event, Iterable<O> observers, void Function(O) call) {
    observers.forEach((observer) {
      try {
        call(observer);
      } catch (e, s) {
        _diagnostics.errorSink.report(AdaptyInternalErrorRecord(
          AdaptyInternalErrorKind.observerThrew,
          e,
          stack: s,
          context: event.wireName,
        ));
      }
    });
  }

  // MARK: - AdaptyUIFlowsEventsObserver

  @override
  void flowViewDidAppear(AdaptyUIFlowView view) {
    _notify(
      NativeEvent.flowViewDidAppear,
      _getFlowViewEventsObservers(view),
      (observer) => observer.flowViewDidAppear(view),
    );
  }

  @override
  void flowViewDidDisappear(AdaptyUIFlowView view) {
    _notify(
      NativeEvent.flowViewDidDisappear,
      _getFlowViewEventsObservers(view),
      (observer) => observer.flowViewDidDisappear(view),
    );
  }

  void flowViewDidPerformAction(
    AdaptyUIFlowView view,
    AdaptyUIAction action,
  ) {
    _notify(
      NativeEvent.flowViewDidPerformAction,
      _getFlowViewEventsObservers(view),
      (observer) => observer.flowViewDidPerformAction(view, action),
    );
  }

  @override
  void flowViewDidSelectProduct(
    AdaptyUIFlowView view,
    String productId,
  ) {
    _notify(
      NativeEvent.flowViewDidSelectProduct,
      _getFlowViewEventsObservers(view),
      (observer) => observer.flowViewDidSelectProduct(view, productId),
    );
  }

  @override
  void flowViewDidStartPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product) {
    _notify(
      NativeEvent.flowViewDidStartPurchase,
      _getFlowViewEventsObservers(view),
      (observer) => observer.flowViewDidStartPurchase(view, product),
    );
  }

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult result,
  ) {
    _notify(
      NativeEvent.flowViewDidFinishPurchase,
      _getFlowViewEventsObservers(view),
      (observer) => observer.flowViewDidFinishPurchase(view, product, result),
    );
  }

  @override
  void flowViewDidFailPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyError error,
  ) {
    _notify(
      NativeEvent.flowViewDidFailPurchase,
      _getFlowViewEventsObservers(view),
      (observer) => observer.flowViewDidFailPurchase(view, product, error),
    );
  }

  @override
  void flowViewDidStartRestore(AdaptyUIFlowView view) {
    _notify(
      NativeEvent.flowViewDidStartRestore,
      _getFlowViewEventsObservers(view),
      (observer) => observer.flowViewDidStartRestore(view),
    );
  }

  @override
  void flowViewDidFinishRestore(
    AdaptyUIFlowView view,
    AdaptyProfile profile,
  ) {
    _notify(
      NativeEvent.flowViewDidFinishRestore,
      _getFlowViewEventsObservers(view),
      (observer) => observer.flowViewDidFinishRestore(view, profile),
    );
  }

  @override
  void flowViewDidFailRestore(
    AdaptyUIFlowView view,
    AdaptyError error,
  ) {
    _notify(
      NativeEvent.flowViewDidFailRestore,
      _getFlowViewEventsObservers(view),
      (observer) => observer.flowViewDidFailRestore(view, error),
    );
  }

  @override
  void flowViewDidReceiveError(
    AdaptyUIFlowView view,
    AdaptyError error,
  ) {
    if (view.id.startsWith(adaptyEmbeddedViewIdPrefix) && !_platformViewFlowsEventsObservers.containsKey(view.id)) {
      if (_pendingPlatformViewFlowErrors.length >= _maxPendingPlatformViewFlowErrors) {
        final droppedViewId = _pendingPlatformViewFlowErrors.keys.first;
        _pendingPlatformViewFlowErrors.remove(droppedViewId);
        _diagnostics.errorSink.report(AdaptyInternalErrorRecord(
          AdaptyInternalErrorKind.pendingErrorDropped,
          droppedViewId,
          context: NativeEvent.flowViewDidReceiveError.wireName,
        ));
      }
      _pendingPlatformViewFlowErrors[view.id] = (view, error);
      _notify(
        NativeEvent.flowViewDidReceiveError,
        [if (flowsEventsObserver != null) flowsEventsObserver!],
        (observer) => observer.flowViewDidReceiveError(view, error),
      );
      return;
    }
    _notify(
      NativeEvent.flowViewDidReceiveError,
      _getFlowViewEventsObservers(view),
      (observer) => observer.flowViewDidReceiveError(view, error),
    );
  }

  @override
  void flowViewDidFailLoadingProducts(
    AdaptyUIFlowView view,
    AdaptyError error,
  ) {
    _notify(
      NativeEvent.flowViewDidFailLoadingProducts,
      _getFlowViewEventsObservers(view),
      (observer) => observer.flowViewDidFailLoadingProducts(view, error),
    );
  }

  @override
  void flowViewDidFinishWebPaymentNavigation(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) {
    _notify(
      NativeEvent.flowViewDidFinishWebPaymentNavigation,
      _getFlowViewEventsObservers(view),
      (observer) => observer.flowViewDidFinishWebPaymentNavigation(view, product, error),
    );
  }

  @override
  void flowViewDidReceiveAnalyticEvent(
    AdaptyUIFlowView view,
    String name,
    Map<String, dynamic> params,
  ) {
    _notify(
      NativeEvent.flowViewDidReceiveAnalyticEvent,
      _getFlowViewEventsObservers(view),
      (observer) => observer.flowViewDidReceiveAnalyticEvent(view, name, params),
    );
  }

  // MARK: - AdaptyUIOnboardingsEventsObserver

  @override
  void onboardingViewDidFinishLoading(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
  ) {
    _notify(
      NativeEvent.onboardingDidFinishLoading,
      _getOnboardingViewEventsObservers(view),
      (observer) => observer.onboardingViewDidFinishLoading(view, meta),
    );
  }

  @override
  void onboardingViewDidFailWithError(
    AdaptyUIOnboardingView view,
    AdaptyError error,
  ) {
    _notify(
      NativeEvent.onboardingDidFailWithError,
      _getOnboardingViewEventsObservers(view),
      (observer) => observer.onboardingViewDidFailWithError(view, error),
    );
  }

  @override
  void onboardingViewOnCloseAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {
    _notify(
      NativeEvent.onboardingOnCloseActionEvent,
      _getOnboardingViewEventsObservers(view),
      (observer) => observer.onboardingViewOnCloseAction(view, meta, actionId),
    );
  }

  @override
  void onboardingViewOnPaywallAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {
    _notify(
      NativeEvent.onboardingOnPaywallActionEvent,
      _getOnboardingViewEventsObservers(view),
      (observer) => observer.onboardingViewOnPaywallAction(view, meta, actionId),
    );
  }

  @override
  void onboardingViewOnCustomAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {
    _notify(
      NativeEvent.onboardingOnCustomActionEvent,
      _getOnboardingViewEventsObservers(view),
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
    _notify(
      NativeEvent.onboardingOnStateUpdatedActionEvent,
      _getOnboardingViewEventsObservers(view),
      (observer) => observer.onboardingViewOnStateUpdatedAction(view, meta, elementId, params),
    );
  }

  @override
  void onboardingViewOnAnalyticsEvent(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    AdaptyOnboardingsAnalyticsEvent event,
  ) {
    _notify(
      NativeEvent.onboardingOnAnalyticsActionEvent,
      _getOnboardingViewEventsObservers(view),
      (observer) => observer.onboardingViewOnAnalyticsEvent(view, meta, event),
    );
  }
}

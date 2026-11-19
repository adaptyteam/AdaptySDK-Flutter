// ignore_for_file: deprecated_member_use_from_same_package
import 'dart:async';

import 'adapty.dart';
import 'adaptyui_observer.dart';

import 'models/adapty_error.dart';
import 'models/adapty_paywall_product.dart';
import 'models/adapty_purchase_result.dart';
import 'models/adapty_profile.dart';
import 'models/adaptyui/adaptyui_action.dart';
import 'models/adaptyui/adaptyui_flow_view.dart';
import 'models/adaptyui/adaptyui_onboarding_view.dart';
import 'models/adaptyui/adaptyui_onboarding_meta.dart';
import 'models/adaptyui/adaptyui_onboarding_state_updated_params.dart';
import 'models/adaptyui/adaptyui_onboardings_analytics_event.dart';
import 'runtime/adapty_internal_error_sink.dart';
import 'runtime/adapty_runtime.dart';

class AdaptyUIDefaultFlowsEventsObserverImpl implements AdaptyUIFlowsEventsObserver {
  @override
  void flowViewDidAppear(AdaptyUIFlowView view) {}

  @override
  void flowViewDidDisappear(AdaptyUIFlowView view) {}

  @override
  void flowViewDidFailLoadingProducts(
    AdaptyUIFlowView view,
    AdaptyError error,
  ) {}

  @override
  void flowViewDidFailPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyError error,
  ) {}

  @override
  void flowViewDidReceiveError(
    AdaptyUIFlowView view,
    AdaptyError error,
  ) =>
      _dismiss(view);

  @override
  void flowViewDidStartRestore(
    AdaptyUIFlowView view,
  ) {}

  @override
  void flowViewDidFinishRestore(
    AdaptyUIFlowView view,
    AdaptyProfile profile,
  ) {}

  @override
  void flowViewDidFailRestore(
    AdaptyUIFlowView view,
    AdaptyError error,
  ) {}

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) {}

  @override
  void flowViewDidFinishWebPaymentNavigation(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) {}

  @override
  void flowViewDidPerformAction(
    AdaptyUIFlowView view,
    AdaptyUIAction action,
  ) {
    switch (action) {
      case const CloseAction():
        // The default close does not wait for the dismiss call; a failure is reported to the error sink.
        unawaited(_dismiss(view));
        break;
      case OpenUrlAction(:final url, :final openIn):
        AdaptyRuntime.current.diagnostics.background.track(
          'default_observer.open_url',
          AdaptyUI().openUrl(url, openIn: openIn),
          onError: AdaptyInternalErrorKind.backgroundCallFailed,
        );
        break;
      default:
        break;
    }
  }

  @override
  void flowViewDidSelectProduct(
    AdaptyUIFlowView view,
    String productId,
  ) {}

  @override
  void flowViewDidStartPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
  ) {}

  @override
  void flowViewDidReceiveAnalyticEvent(
    AdaptyUIFlowView view,
    String name,
    Map<String, dynamic> params,
  ) {}
}

/// Dismisses [view] without waiting and returns the call. A failure goes to the error sink of the current runtime,
/// which is the runtime of the event being handled.
Future<void> _dismiss(AdaptyUIFlowView view) {
  final call = view.dismiss();
  AdaptyRuntime.current.diagnostics.background.track(
    'default_observer.dismiss',
    call,
    onError: AdaptyInternalErrorKind.backgroundCallFailed,
  );
  return call;
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

// ignore_for_file: deprecated_member_use_from_same_package
import 'adapty.dart';
import 'adaptyui_observer.dart';
import 'adaptyui_events_proxy.dart';

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

  // A flow keeps running after most errors, so the default leaves it on screen, as the native SDKs do.
  @override
  void flowViewDidReceiveError(
    AdaptyUIFlowView view,
    AdaptyError error,
  ) {}

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
  void flowViewDidPerformAction(AdaptyUIFlowView view, AdaptyUIAction action) => handleDefaultFlowAction(view, action);

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

/// The default handling of [action] of [view], used both by the default observer and by the default body of
/// [AdaptyUIFlowsEventsObserver.flowViewDidPerformAction]: a close dismisses a view created by
/// [AdaptyUI.createFlowView], a link opens where the action says, and any other action is left alone. Neither call is
/// waited for: a failure goes to the error sink of the current runtime, which is the runtime of the event being
/// handled.
void handleDefaultFlowAction(AdaptyUIFlowView view, AdaptyUIAction action) {
  switch (action) {
    case const CloseAction():
      // An embedded view is closed by removing its widget: dismiss fails for it.
      if (view.id.startsWith(adaptyEmbeddedViewIdPrefix)) break;
      AdaptyRuntime.current.diagnostics.background.track(
        'default_observer.dismiss',
        view.dismiss(),
        onError: AdaptyInternalErrorKind.backgroundCallFailed,
      );
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

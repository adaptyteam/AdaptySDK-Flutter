// ignore_for_file: deprecated_member_use_from_same_package
import 'adapty.dart';
import 'adaptyui_events_proxy.dart';

import 'models/adapty_paywall_product.dart';
import 'models/adapty_profile.dart';
import 'models/adapty_error.dart';
import 'models/adaptyui/adaptyui_action.dart';
import 'models/adapty_purchase_result.dart';

import 'models/adaptyui/adaptyui_onboarding_meta.dart';
import 'models/adaptyui/adaptyui_onboarding_state_updated_params.dart';
import 'models/adaptyui/adaptyui_onboarding_view.dart';
import 'models/adaptyui/adaptyui_onboardings_analytics_event.dart';
import 'models/adaptyui/adaptyui_flow_view.dart';
import 'runtime/adapty_internal_error_sink.dart';
import 'runtime/adapty_runtime.dart';

abstract class AdaptyUIFlowsEventsObserver {
  /// This method is invoked when the flow view was presented. For a flow shown by
  /// [AdaptyUIFlowPlatformView], it is invoked once, when the flow has loaded into the widget,
  /// whether or not the widget is on screen at that moment.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  void flowViewDidAppear(AdaptyUIFlowView view) {}

  /// This method is invoked when the flow view has closed, whether your app closed it or the user
  /// swiped down a page sheet on iOS. For a flow shown by [AdaptyUIFlowPlatformView], it is invoked
  /// only on Android, when the widget is removed, and only on the observer set with
  /// [AdaptyUI.setFlowsEventsObserver]: [AdaptyUIFlowPlatformView.onDidDisappear] is not called
  /// for it.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  void flowViewDidDisappear(AdaptyUIFlowView view) {}

  /// This method is invoked for every action of the flow: [CloseAction], [OpenUrlAction], [AndroidSystemBackAction]
  /// and [CustomAction].
  ///
  /// The default implementation opens the URL of an [OpenUrlAction] and dismisses the view on
  /// [CloseAction]; it does not dismiss a flow shown by [AdaptyUIFlowPlatformView]: remove the widget
  /// to close it. It does not handle [AndroidSystemBackAction].
  ///
  /// On Android a shown flow takes the system back button until you dismiss a view created by
  /// [AdaptyUI.createFlowView] or remove the widget of an [AdaptyUIFlowPlatformView]. A press runs
  /// the back action the flow sets for its current screen or navigator, if any; otherwise it is
  /// delivered as [AndroidSystemBackAction] and does nothing more. The widget keeps the button while
  /// it is mounted, so `Navigator` does not get it: pop the route yourself on
  /// [AndroidSystemBackAction] if back should leave the screen.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  void flowViewDidPerformAction(AdaptyUIFlowView view, AdaptyUIAction action) {
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

  /// If product was selected for purchase (by user or by system), this method will be invoked.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [productId]: the id of the selected product.
  void flowViewDidSelectProduct(AdaptyUIFlowView view, String productId) {}

  /// If user initiates the purchase process, this method will be invoked.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [product]: an [AdaptyPaywallProduct] of the purchase.
  void flowViewDidStartPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product) {}

  /// This method is invoked when a successful purchase is made.
  ///
  /// There is no default implementation; implement this method to decide what
  /// happens after a successful purchase (e.g. continue the flow or call `view.dismiss()`).
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [product]: an [AdaptyPaywallProduct] of the purchase.
  /// - [purchaseResult]: an [AdaptyPurchaseResult] object containing the information about successful purchase or it cancellation.
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  );

  /// This method is invoked when the purchase process fails.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [product]: an [AdaptyPaywallProduct] of the purchase.
  /// - [error]: an [AdaptyError] object representing the error.
  void flowViewDidFailPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product, AdaptyError error) {}

  /// If user initiates the restore process, this method will be invoked.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  void flowViewDidStartRestore(AdaptyUIFlowView view) {}

  /// This method is invoked when a successful restore is made.
  ///
  /// Check if the [AdaptyProfile] object contains the desired access level, and if so, the controller can be dismissed.
  /// ```
  /// view.dismiss()
  /// ```
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [profile]: an [AdaptyProfile] object containing up to date information about the user.
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile);

  /// This method is invoked when the restore process fails.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [error]: an [AdaptyError] object representing the error.
  void flowViewDidFailRestore(AdaptyUIFlowView view, AdaptyError error) {}

  /// This method will be invoked in case of errors during the screen rendering process.
  ///
  /// On iOS it is also invoked when an [AdaptyUIFlowPlatformView] can't show its flow, possibly
  /// after the widget is removed; [AdaptyUIFlowView.dismiss] fails for that view.
  ///
  /// Without an observer, the SDK dismisses a view created by [AdaptyUI.createFlowView] when it
  /// reports an error; once you set one, or register a listener for the view with
  /// [AdaptyUI.registerFlowEventsListener], nothing is dismissed for you.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [error]: an [AdaptyError] object representing the error.
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error);

  /// This method is invoked in case of errors during the products loading process.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [error]: an [AdaptyError] object representing the error.
  void flowViewDidFailLoadingProducts(AdaptyUIFlowView view, AdaptyError error) {}

  /// This method is invoked when the web payment navigation is finished.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [product]: an [AdaptyPaywallProduct] object containing the information about the product.
  /// - [error]: an [AdaptyError] object representing the error.
  void flowViewDidFinishWebPaymentNavigation(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) {}

  /// This method is invoked when the flow view emits an analytic event.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [name]: the name of the analytic event.
  /// - [params]: a map containing the parameters of the analytic event. Read numeric values as
  ///   `num`: a whole number can arrive as `int`.
  void flowViewDidReceiveAnalyticEvent(AdaptyUIFlowView view, String name, Map<String, dynamic> params) {}
}

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
abstract class AdaptyUIOnboardingsEventsObserver {
  void onboardingViewDidFinishLoading(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
  ) {}

  void onboardingViewDidFailWithError(
    AdaptyUIOnboardingView view,
    AdaptyError error,
  ) {}

  void onboardingViewOnCloseAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {}

  void onboardingViewOnPaywallAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {}

  void onboardingViewOnCustomAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {}

  void onboardingViewOnStateUpdatedAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String elementId,
    AdaptyOnboardingsStateUpdatedParams params,
  ) {}

  void onboardingViewOnAnalyticsEvent(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    AdaptyOnboardingsAnalyticsEvent event,
  ) {}
}

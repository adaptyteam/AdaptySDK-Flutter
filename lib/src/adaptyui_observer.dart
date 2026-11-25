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

abstract class AdaptyUIFlowsEventsObserver {
  /// This method is invoked when the flow view was presented. On iOS, it is invoked again for a
  /// flow created by [AdaptyUI.createFlowView] when, for example, the in-app browser opened over
  /// it closes. For a flow shown by [AdaptyUIFlowPlatformView], it is invoked once, when the flow
  /// has loaded into the widget, whether or not the widget is on screen at that moment.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  void flowViewDidAppear(AdaptyUIFlowView view) {}

  /// This method is invoked when the flow view has closed, whether your app closed it or the user
  /// swiped down a page sheet on iOS. On iOS, it is also invoked while a flow created by
  /// [AdaptyUI.createFlowView] stays open, for example when the in-app browser opens over it, and
  /// [flowViewDidAppear] follows when the browser closes: don't release the view on this call
  /// alone. For a flow shown by [AdaptyUIFlowPlatformView], it is invoked
  /// only on Android, when the widget is removed, and only on the observer set with
  /// [AdaptyUI.setFlowsEventsObserver]: [AdaptyUIFlowPlatformView.onDidDisappear] is not called
  /// for it.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  void flowViewDidDisappear(AdaptyUIFlowView view) {}

  /// If the user presses the close button, this method will be invoked.
  ///
  /// The default implementation dismisses the view on [CloseAction] and opens the URL of an
  /// [OpenUrlAction]. For a flow shown by [AdaptyUIFlowPlatformView], it does not dismiss the view:
  /// remove the widget to close the flow.
  /// [AndroidSystemBackAction] is delivered but not handled by default: to close a flow created by
  /// [AdaptyUI.createFlowView] on the Android system Back button, dismiss it yourself. Whether the
  /// Back button reaches a flow shown by [AdaptyUIFlowPlatformView] depends on the native view: see
  /// that widget.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  void flowViewDidPerformAction(AdaptyUIFlowView view, AdaptyUIAction action) {
    switch (action) {
      case const CloseAction():
        // An embedded view is closed by removing its widget: dismiss fails for it.
        if (view.id.startsWith(adaptyEmbeddedViewIdPrefix)) break;
        trackDefaultHandlingCall('default_observer.dismiss', view.dismiss());
        break;
      case OpenUrlAction(:final url, :final openIn):
        trackDefaultHandlingCall('default_observer.open_url', AdaptyUI().openUrl(url, openIn: openIn));
        break;
      default:
        break;
    }
  }

  /// If product was selected for purchase (by user or by system), this method will be invoked.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [product]: an [AdaptyPaywallProduct] which was selected.
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

  /// The flow reports an error here, and most errors don't stop it: the flow stays on screen and
  /// keeps running. For example:
  /// - an exception in its script, [AdaptyErrorCode.jsException];
  /// - an open-URL action whose link text is missing (on iOS, also one that isn't a URL),
  ///   [AdaptyErrorCode.invalidActionURL];
  /// - on iOS, a URL the in-app browser can't open, [AdaptyErrorCode.unsupportedURLScheme];
  /// - an image element whose asset isn't a usable image, [AdaptyErrorCode.wrongAssetType] (on
  ///   Android, only one whose asset is a color, a gradient or a video);
  /// - on iOS, an element of an unexpected type, [AdaptyErrorCode.wrongComponentType].
  ///
  /// Decide per error whether to close the flow. For a flow created by [AdaptyUI.createFlowView],
  /// [AdaptyUIFlowView.dismiss] closes and releases it, and the user's progress in it is lost; a
  /// flow shown by [AdaptyUIFlowPlatformView] is closed by removing the widget. Without an observer
  /// set with [AdaptyUI.setFlowsEventsObserver], the SDK leaves the flow on screen.
  ///
  /// For a flow created by [AdaptyUI.createFlowView] whose script fails before its first screen,
  /// the flow stays empty. On Android, the error arrives here as [AdaptyErrorCode.jsException], the
  /// same code as a script error while the flow runs, and the system Back button doesn't close the
  /// flow unless [AndroidSystemBackAction] is handled. On iOS, the error doesn't arrive here: the
  /// native SDK only logs it.
  ///
  /// It is also invoked, on both platforms, when an [AdaptyUIFlowPlatformView] can't show its flow
  /// (see [AdaptyUIFlowPlatformView.onDidReceiveError] for the codes), possibly after the widget is
  /// removed; [AdaptyUIFlowView.dismiss] fails for that view.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIFlowView] within which the event occurred.
  /// - [error]: an [AdaptyError] object representing the error.
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error);

  /// This method is invoked in case of errors during the products loading process.
  ///
  /// On Android, it can be invoked up to 4 times for one view: after a failure, the SDK retries
  /// the load up to 3 times, 2 seconds apart, so products can still load after this call. On iOS,
  /// it is invoked once, with no retry.
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

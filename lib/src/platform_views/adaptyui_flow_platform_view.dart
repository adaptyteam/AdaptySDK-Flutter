import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert' show json;

import '../adapty.dart';
import '../adaptyui_events_proxy.dart' show AdaptyEmbeddedFlowActions, adaptyEmbeddedViewIdPrefix;
import '../adaptyui_observer.dart';
import '../constants/argument.dart';
import '../runtime/adapty_platform_info.dart';
import '../runtime/adapty_runtime.dart';
import '../models/private/json_builder.dart';
import '../models/adapty_error.dart';
import '../models/adapty_flow.dart';
import '../models/adapty_paywall_product.dart';
import '../models/adapty_product_identifier.dart';
import '../models/adapty_profile.dart';
import '../models/adapty_purchase_parameters.dart';
import '../models/adapty_purchase_result.dart';
import '../models/adaptyui/adaptyui_action.dart';
import '../models/adaptyui/adaptyui_flow_view.dart';
import '../models/custom_assets/adaptyui_custom_assets.dart';

/// Shows a flow inside your widget tree.
///
/// Flows require iOS 16 or later. On iOS below 16, the widget stays empty and, each time it is
/// created, calls [onDidReceiveError] once with an [AdaptyError] with
/// [AdaptyErrorCode.platformNotSupported]; no other callback is called. Show your own content
/// instead of the widget then, or don't show the widget on those devices at all. The observer
/// set with [AdaptyUI.setFlowsEventsObserver] receives the same error in
/// [AdaptyUIFlowsEventsObserver.flowViewDidReceiveError].
///
/// On iOS 16 and later, when the flow fails to load into the widget, for example while AdaptyUI
/// is not activated or for a [customLayoutId] the flow doesn't have, the widget stays empty and
/// calls [onDidReceiveError] once with an [AdaptyError] with the same code that
/// [AdaptyUI.createFlowView] fails with for that flow; no other callback is called. The flows
/// events observer receives the same error. On Android the widget stays empty and no callback
/// is called, not even [onDidAppear]; the failure is only reported to the native log.
///
/// Custom elements are drawn as described in [AdaptyUI.createFlowView].
class AdaptyUIFlowPlatformView extends StatefulWidget {
  final AdaptyFlow flow;

  /// The identifier of the localization to render the flow with, e.g. `en`,
  /// `es`, `fr`.
  ///
  /// If `null`, the view is rendered in `en`, falling back to the flow's
  /// default localization when the flow has no `en`. Asking for a localization
  /// the flow does not have falls back to the flow default as well, without an
  /// error. Strings missing from the chosen localization are filled in from the
  /// default one.
  final String? locale;

  /// The custom ID of a grid configured for this flow in the Adapty Flow
  /// Builder, to render instead of the grid selected automatically for the
  /// current device.
  ///
  /// Pass `null` to keep the automatic selection. The ID is matched exactly as
  /// given. An unknown ID leaves the widget empty. On iOS 16 and later the widget calls
  /// [onDidReceiveError] with [AdaptyErrorCode.wrongParam], the same code that
  /// [AdaptyUI.createFlowView] fails with for that ID; on Android no callback is called, and the
  /// failure is only reported to the native log.
  ///
  /// Like every other creation parameter of this widget, it is read once when
  /// the native view is created. Changing it on a mounted widget has no effect
  /// — rebuild the widget under a different [Key] to render another grid.
  final String? customLayoutId;

  /// Android only. If `true`, the flow view applies the safe-area insets as
  /// paddings. Has no effect on iOS. Defaults to `false` for the embedded view,
  /// which is usually hosted inside a widget tree that already manages
  /// safe-area insets (e.g. a `SafeArea`), so native paddings would double up.
  final bool androidEnableSafeArea;

  final Map<String, String>? customTags;
  final Map<String, DateTime>? customTimers;
  final Map<String, AdaptyCustomAsset>? customAssets;
  final Map<AdaptyProductIdentifier, AdaptyPurchaseParameters>? productPurchaseParams;

  /// Called once, when the flow has loaded into the widget, whether or not the widget is on
  /// screen at that moment.
  final void Function(AdaptyUIFlowView)? onDidAppear;

  /// Not called when the widget is removed, so do not rely on it. On iOS a flow shown by this
  /// widget does not report a disappear. On Android the event arrives after the widget has been
  /// disposed, so only the observer set with [AdaptyUI.setFlowsEventsObserver] receives it, as
  /// [AdaptyUIFlowsEventsObserver.flowViewDidDisappear].
  final void Function(AdaptyUIFlowView)? onDidDisappear;

  /// Called for every action of the flow. When it is set, the SDK's default handling is not used
  /// for this flow: the observer set with [AdaptyUI.setFlowsEventsObserver], if any, gets the
  /// actions as well and, if it keeps the default `flowViewDidPerformAction`, opens the URL of an
  /// [OpenUrlAction]; without such an observer nothing opens it — open it yourself, for example
  /// with `AdaptyUI().openUrl(url, openIn: openIn)`. When it is not set, the actions go to that
  /// observer, or, with none, to the default handling, which opens the URL of an [OpenUrlAction].
  /// Either way the flow is closed by removing the widget: [CloseAction] does not remove it.
  final void Function(AdaptyUIFlowView, AdaptyUIAction)? onDidPerformAction;
  final void Function(AdaptyUIFlowView, String)? onDidSelectProduct;
  final void Function(AdaptyUIFlowView, AdaptyPaywallProduct)? onDidStartPurchase;
  final void Function(AdaptyUIFlowView, AdaptyPaywallProduct, AdaptyPurchaseResult)? onDidFinishPurchase;
  final void Function(AdaptyUIFlowView, AdaptyPaywallProduct, AdaptyError)? onDidFailPurchase;
  final void Function(AdaptyUIFlowView)? onDidStartRestore;
  final void Function(AdaptyUIFlowView, AdaptyProfile)? onDidFinishRestore;
  final void Function(AdaptyUIFlowView, AdaptyError)? onDidFailRestore;

  /// Called when the flow reports an error, with the [AdaptyUIFlowView] of the flow.
  ///
  /// Below iOS 16, where flows don't render, it is called once, right after the widget is
  /// created, with [AdaptyErrorCode.platformNotSupported]. The error comes again each time the
  /// widget is created on that device, so show your own content instead of retrying. The methods
  /// of the [AdaptyUIFlowView] passed with it, such as [AdaptyUIFlowView.dismiss], fail with the
  /// same code.
  ///
  /// On iOS 16 and later it is also called once when the flow fails to load into the widget,
  /// with the same code that [AdaptyUI.createFlowView] fails with for that flow, such as
  /// [AdaptyErrorCode.adaptyUINotActivated] or [AdaptyErrorCode.wrongParam] for an unknown
  /// [customLayoutId]. The widget then stays empty, and the methods of the [AdaptyUIFlowView]
  /// passed with it fail with [AdaptyErrorCode.wrongParam]. Building the widget again under a
  /// different [Key] loads the flow again, so retry only a temporary failure, such as
  /// [AdaptyErrorCode.networkFailed], or [AdaptyErrorCode.adaptyUINotActivated] when the widget
  /// was built before [Adapty.activate] completed.
  final void Function(AdaptyUIFlowView, AdaptyError)? onDidReceiveError;
  final void Function(AdaptyUIFlowView, AdaptyError)? onDidFailLoadingProducts;
  final void Function(AdaptyUIFlowView, AdaptyPaywallProduct?, AdaptyError?)? onDidFinishWebPaymentNavigation;
  /// Called when the flow emits an analytic event, with the event's name and parameters. Read
  /// numeric parameters as `num`: a whole number can arrive as `int`.
  final void Function(AdaptyUIFlowView, String, Map<String, dynamic>)? onDidReceiveAnalyticEvent;

  const AdaptyUIFlowPlatformView({
    super.key,
    required this.flow,
    this.locale,
    this.customLayoutId,
    this.androidEnableSafeArea = false,
    this.customTags,
    this.customTimers,
    this.customAssets,
    this.productPurchaseParams,
    this.onDidAppear,
    this.onDidDisappear,
    this.onDidPerformAction,
    this.onDidSelectProduct,
    this.onDidStartPurchase,
    this.onDidFinishPurchase,
    this.onDidFailPurchase,
    this.onDidStartRestore,
    this.onDidFinishRestore,
    this.onDidFailRestore,
    this.onDidReceiveError,
    this.onDidFailLoadingProducts,
    this.onDidFinishWebPaymentNavigation,
    this.onDidReceiveAnalyticEvent,
  });

  @override
  State<AdaptyUIFlowPlatformView> createState() => _AdaptyUIFlowPlatformViewState();
}

/// Builds the creation params passed to the native flow platform view.
///
/// Kept next to the widget so the embedded view and [AdaptyUI.createFlowView]
/// serialize the same arguments; exposed for tests only.
@visibleForTesting
Map<String, dynamic> buildFlowPlatformViewCreationParams({
  required AdaptyFlow flow,
  String? locale,
  String? customLayoutId,
  required bool androidEnableSafeArea,
  Map<String, String>? customTags,
  Map<String, DateTime>? customTimers,
  Map<String, AdaptyCustomAsset>? customAssets,
  Map<AdaptyProductIdentifier, AdaptyPurchaseParameters>? productPurchaseParams,
}) {
  return {
    Argument.flow: flow.jsonValue,
    if (locale != null) Argument.locale: locale,
    if (customLayoutId != null) Argument.customLayoutId: customLayoutId,
    Argument.enableSafeAreaPaddings: androidEnableSafeArea,
    if (customTags != null) Argument.customTags: customTags,
    if (customTimers != null)
      Argument.customTimers: customTimers.map((key, value) => MapEntry(
            key,
            value.toAdaptyValidString(),
          )),
    if (customAssets != null)
      Argument.customAssets: customAssets.entries
          .map((entry) => {
                Argument.id: entry.key,
                ...entry.value.jsonValue,
              })
          .toList(),
    if (productPurchaseParams != null)
      Argument.productPurchaseParameters: AdaptyProductIdentifier.convertProductPurchaseParamsToJson(
        productPurchaseParams,
      ),
  };
}

class _AdaptyUIFlowPlatformViewState extends State<AdaptyUIFlowPlatformView>
    implements AdaptyUIFlowsEventsObserver, AdaptyEmbeddedFlowActions {
  String? _viewId;

  /// The runtime the observer was registered in; it is removed from the same one.
  AdaptyRuntime? _runtime;

  void _onPlatformViewCreated(int id) {
    final viewId = '$adaptyEmbeddedViewIdPrefix$id';
    final runtime = AdaptyRuntime.current;
    _viewId = viewId;
    _runtime = runtime;
    runtime.ui.eventsProxy.registerFlowEventsListener(this, viewId);
  }

  @override
  void dispose() {
    final viewId = _viewId;
    final runtime = _runtime;
    if (viewId != null && runtime != null) {
      runtime.ui.eventsProxy.unregisterFlowEventsListener(viewId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final creationParams = buildFlowPlatformViewCreationParams(
      flow: widget.flow,
      locale: widget.locale,
      customLayoutId: widget.customLayoutId,
      androidEnableSafeArea: widget.androidEnableSafeArea,
      customTags: widget.customTags,
      customTimers: widget.customTimers,
      customAssets: widget.customAssets,
      productPurchaseParams: widget.productPurchaseParams,
    );

    final viewKind = AdaptyRuntime.current.environment.platform.viewKind;
    if (viewKind == AdaptyPlatformViewKind.uiKit) {
      return UiKitView(
        viewType: 'adaptyui_flow_platform_view',
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: json.encode(creationParams),
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (viewKind == AdaptyPlatformViewKind.android) {
      return AndroidView(
        viewType: 'adaptyui_flow_platform_view',
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: json.encode(creationParams),
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  @override
  void flowViewDidAppear(AdaptyUIFlowView view) => widget.onDidAppear?.call(view);

  @override
  void flowViewDidDisappear(AdaptyUIFlowView view) => widget.onDidDisappear?.call(view);

  /// Read when each action arrives, so it follows the widget the state was last built with.
  @override
  bool get handlesActions => widget.onDidPerformAction != null;

  @override
  void flowViewDidPerformAction(AdaptyUIFlowView view, AdaptyUIAction action) => widget.onDidPerformAction?.call(view, action);

  @override
  void flowViewDidSelectProduct(AdaptyUIFlowView view, String productId) => widget.onDidSelectProduct?.call(view, productId);

  @override
  void flowViewDidStartPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product) => widget.onDidStartPurchase?.call(view, product);

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) =>
      widget.onDidFinishPurchase?.call(view, product, purchaseResult);

  @override
  void flowViewDidFailPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product, AdaptyError error) => widget.onDidFailPurchase?.call(view, product, error);

  @override
  void flowViewDidStartRestore(AdaptyUIFlowView view) => widget.onDidStartRestore?.call(view);

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) => widget.onDidFinishRestore?.call(view, profile);

  @override
  void flowViewDidFailRestore(AdaptyUIFlowView view, AdaptyError error) => widget.onDidFailRestore?.call(view, error);

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) => widget.onDidReceiveError?.call(view, error);

  @override
  void flowViewDidFailLoadingProducts(AdaptyUIFlowView view, AdaptyError error) => widget.onDidFailLoadingProducts?.call(view, error);

  @override
  void flowViewDidFinishWebPaymentNavigation(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) =>
      widget.onDidFinishWebPaymentNavigation?.call(view, product, error);

  @override
  void flowViewDidReceiveAnalyticEvent(AdaptyUIFlowView view, String name, Map<String, dynamic> params) =>
      widget.onDidReceiveAnalyticEvent?.call(view, name, params);
}

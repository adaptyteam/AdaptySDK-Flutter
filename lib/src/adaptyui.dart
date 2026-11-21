// ignore_for_file: deprecated_member_use_from_same_package
part of 'adapty.dart';

class AdaptyUI {
  static final AdaptyUI _instance = AdaptyUI._internal();

  factory AdaptyUI() => _instance;

  AdaptyUI._internal();

  /// Sets the handler for the OS permission prompts and App Store / Google Play review requests of
  /// flows. Set it before you present flows, for example right after `Adapty().activate()`.
  ///
  /// A flow waits for the answer to a permission request, with no timeout: always complete your
  /// `Future`. Each request with an id (the native SDK always sends one) gets exactly one answer:
  /// what [AdaptyUISystemRequestsHandler.handlePermission] returns, or `denied` when it throws or
  /// its `Future` fails, when the SDK can't read the request, or when no handler is set at the
  /// moment of the request (one set later does not answer it). Review requests show the native
  /// prompt ([requestAppReview]) without a handler; with one, they go to
  /// [AdaptyUISystemRequestsHandler.handleAppReviewRequest], which does nothing unless you override it.
  void setSystemRequestsHandler(AdaptyUISystemRequestsHandler handler) {
    AdaptyLogger.write(AdaptyLogLevel.verbose, 'AdaptyUI.setSystemRequestsHandler()');
    AdaptyRuntime.current.ui.systemRequestsHandler = handler;
  }

  /// Sets the resolver that makes purchases and restores for flows in Observer mode.
  ///
  /// Required in Observer mode: the flow waits for `onFinishPurchase` / `onFinishRestore`, which the
  /// SDK never calls for you, so without a resolver, or if it throws, the purchase or restore never
  /// finishes; the SDK logs a warning (no resolver) or an error (it threw). Only a synchronous throw
  /// is caught: an error of an `async` method, even before its first `await`, goes to your app's
  /// zone, and the SDK logs nothing.
  void setObserverModeResolver(AdaptyUIObserverModeResolver resolver) {
    AdaptyLogger.write(AdaptyLogLevel.verbose, 'AdaptyUI.setObserverModeResolver()');
    AdaptyRuntime.current.ui.observerModeResolver = resolver;
  }

  void registerFlowEventsListener(AdaptyUIFlowsEventsObserver observer, String viewId) {
    AdaptyRuntime.current.ui.eventsProxy.registerFlowEventsListener(observer, viewId);
  }

  void unregisterFlowEventsListener(String viewId) {
    AdaptyRuntime.current.ui.eventsProxy.unregisterFlowEventsListener(viewId);
  }

  @Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
  void registerOnboardingEventsListener(AdaptyUIOnboardingsEventsObserver observer, String viewId) {
    AdaptyRuntime.current.ui.eventsProxy.registerOnboardingEventsListener(observer, viewId);
  }

  @Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
  void unregisterOnboardingEventsListener(String viewId) {
    AdaptyRuntime.current.ui.eventsProxy.unregisterOnboardingEventsListener(viewId);
  }

  /// Use this method to set the AdaptyUI flows events observer.
  ///
  /// Pass `null` to detach the previously set observer (e.g. on cleanup),
  /// so the SDK no longer holds a reference to it.
  void setFlowsEventsObserver(AdaptyUIFlowsEventsObserver? observer) {
    AdaptyLogger.write(AdaptyLogLevel.verbose, 'AdaptyUI.setFlowsEventsObserver()');
    AdaptyRuntime.current.ui.eventsProxy.flowsEventsObserver = observer;
  }

  /// Use this method to set the AdaptyUI onboardings events observer.
  ///
  /// Pass `null` to detach the previously set observer (e.g. on cleanup),
  /// so the SDK no longer holds a reference to it.
  @Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
  void setOnboardingsEventsObserver(AdaptyUIOnboardingsEventsObserver? observer) {
    AdaptyLogger.write(AdaptyLogLevel.verbose, 'AdaptyUI.setOnboardingsEventsObserver()');
    AdaptyRuntime.current.ui.eventsProxy.onboardingsEventsObserver = observer;
  }

  /// Right after receiving ``AdaptyFlow``, you can create the corresponding ``AdaptyUIFlowView`` to present it afterwards.
  ///
  /// Flows require iOS 16 or later; below that the call fails with
  /// [AdaptyErrorCode.platformNotSupported].
  ///
  /// Custom elements are drawn by the resolver your app registers in native code with
  /// `AdaptyUI.setCustomElementsResolver`, not by Flutter widgets. On Android, add
  /// `io.adapty:android-ui` to your app module without a version, which this package sets, and
  /// without the Adapty BOM.
  ///
  /// **Parameters**
  /// - [flow]: an [AdaptyFlow] object, for which you are trying to get a controller.
  /// - [locale]: the identifier of the localization to render the flow with, e.g. `en`, `es`, `fr`.
  /// If you don't pass it, the view is rendered in `en`, falling back to the flow's default
  /// localization when the flow has no `en`. Asking for a localization the flow does not have
  /// falls back to the flow default as well, without an error. Strings missing from the chosen
  /// localization are filled in from the default one.
  /// - [customLayoutId]: the custom ID of a grid configured for this flow in the Adapty Flow Builder,
  /// to render instead of the grid selected automatically for the current device. Pass `null` to keep the
  /// automatic selection. The ID is matched exactly as given; an unknown ID fails with an [AdaptyError].
  /// - [preloadProducts]: if `true`, this call completes only after the flow's products have
  /// loaded or failed to load, so prices show as soon as the view is presented. A failure does
  /// not fail the call; the view loads them again when it appears. With `false` the call does not
  /// wait for them.
  /// - [loadTimeout]: the longest the SDK waits for the view configuration of the flow to load, sent in seconds.
  /// - [androidEnableSafeArea]: Android only. If `true`, the flow view applies the safe-area insets as paddings. Has no effect on iOS. Defaults to `true`.
  /// - [customTags]: the text for each custom tag of the flow, by tag name.
  /// - [customTimers]: the end of each custom timer of the flow, by timer id, sent in UTC to the millisecond.
  /// - [customAssets]: the asset for each custom asset of the flow, by asset id. An asset that can't be
  /// encoded fails the call with an [AdaptyError] with [AdaptyErrorCode.wrongParam] before anything is sent.
  /// - [productPurchaseParams]: A map that contains purchase parameters for specific products.
  /// The key is an [AdaptyProductIdentifier] and the value is [AdaptyPurchaseParameters] containing purchase-specific configuration.
  ///
  /// **Returns**
  /// - an [AdaptyUIFlowView] object, representing the requested flow screen.
  Future<AdaptyUIFlowView> createFlowView({
    required AdaptyFlow flow,
    String? locale,
    String? customLayoutId,
    Duration? loadTimeout,
    bool preloadProducts = false,
    bool androidEnableSafeArea = true,
    Map<String, String>? customTags,
    Map<String, DateTime>? customTimers,
    Map<String, AdaptyCustomAsset>? customAssets,
    Map<AdaptyProductIdentifier, AdaptyPurchaseParameters>? productPurchaseParams,
  }) async {
    // Encoded one by one, so an asset that cannot be sent fails with an AdaptyError naming it.
    final encodedCustomAssets = customAssets?.entries.map((entry) {
      try {
        return {
          Argument.id: entry.key,
          ...entry.value.jsonValue,
        };
      } catch (error) {
        throw AdaptyError(
          'Failed to encode custom asset "${entry.key}"',
          AdaptyErrorCode.wrongParam,
          error.toString(),
        );
      }
    }).toList();

    return Adapty()._invokeMethod<AdaptyUIFlowView>(
      NativeMethod.createFlowView,
      (data) {
        final viewMap = data as Map<String, dynamic>;
        return AdaptyUIFlowViewJSONBuilder.fromJsonValue(viewMap);
      },
      {
        Argument.flow: flow.jsonValue,
        if (locale != null) Argument.locale: locale,
        if (customLayoutId != null) Argument.customLayoutId: customLayoutId,
        Argument.preloadProducts: preloadProducts,
        Argument.enableSafeAreaPaddings: androidEnableSafeArea,
        if (loadTimeout != null) Argument.loadTimeout: loadTimeout.inMilliseconds.toDouble() / 1000.0,
        if (customTags != null) Argument.customTags: customTags,
        if (customTimers != null)
          Argument.customTimers: customTimers.map((key, value) => MapEntry(
                key,
                value.toAdaptyValidString(),
              )),
        if (encodedCustomAssets != null) Argument.customAssets: encodedCustomAssets,
        if (productPurchaseParams != null)
          Argument.productPurchaseParameters: AdaptyProductIdentifier.convertProductPurchaseParamsToJson(
            productPurchaseParams,
          ),
      },
    );
  }

  @Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
  Future<AdaptyUIOnboardingView> createOnboardingView({
    required AdaptyOnboarding onboarding,
    AdaptyWebPresentation externalUrlsPresentation = AdaptyWebPresentation.inAppBrowser,
  }) async {
    return Adapty()._invokeMethod<AdaptyUIOnboardingView>(
      NativeMethod.createOnboardingView,
      (data) {
        final viewMap = data as Map<String, dynamic>;
        return AdaptyUIOnboardingViewJSONBuilder.fromJsonValue(viewMap);
      },
      {
        Argument.onboarding: onboarding.jsonValue,
        Argument.externalUrlsPresentation: externalUrlsPresentation.jsonValue,
      },
    );
  }

  /// Presents [view]. On iOS, [iosPresentationStyle] picks full screen, the default, or a page
  /// sheet the user can swipe down; Android ignores it.
  ///
  /// Works only with a view created by [createFlowView]. Fails with [AdaptyErrorCode.wrongParam]
  /// for a view shown by [AdaptyUIFlowPlatformView], for a released view, or while a flow view is
  /// already presented.
  ///
  /// **Parameters**
  /// - [view]: the [AdaptyUIFlowView] to present.
  Future<void> presentFlowView(
    AdaptyUIFlowView view, {
    AdaptyUIIOSPresentationStyle iosPresentationStyle = AdaptyUIIOSPresentationStyle.fullScreen,
  }) async {
    return Adapty()._invokeMethod<void>(
      NativeMethod.presentFlowView,
      (data) => null,
      {
        Argument.id: view.id,
        Argument.iosPresentationStyle: iosPresentationStyle.jsonValue,
      },
    );
  }

  /// Call this function if you wish to present the view.
  ///
  /// **Parameters**
  /// - [view]: the [AdaptyUIOnboardingView] to present.
  @Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
  Future<void> presentOnboardingView(
    AdaptyUIOnboardingView view, {
    AdaptyUIIOSPresentationStyle iosPresentationStyle = AdaptyUIIOSPresentationStyle.fullScreen,
  }) async {
    return Adapty()._invokeMethod<void>(
      NativeMethod.presentOnboardingView,
      (data) => null,
      {
        Argument.id: view.id,
        Argument.iosPresentationStyle: iosPresentationStyle.jsonValue,
      },
    );
  }

  /// Dismisses [view]. Works only with a view created by [createFlowView]: for a view shown by
  /// [AdaptyUIFlowPlatformView], or a released one, it fails with [AdaptyErrorCode.wrongParam].
  ///
  /// **Parameters**
  /// - [view]: the [AdaptyUIFlowView] to dismiss.
  /// - [destroy]: with `true`, the default, the view is released: create a new one to show the
  /// flow again. With `false` it stays alive, and [presentFlowView] resumes it where the user left
  /// it, until you release it with [destroyFlowView] or dismiss it with `destroy: true`.
  Future<void> dismissFlowView(
    AdaptyUIFlowView view, {
    bool destroy = true,
  }) async {
    return Adapty()._invokeMethod<void>(
      NativeMethod.dismissFlowView,
      (data) => null,
      {Argument.id: view.id, Argument.destroy: destroy},
    );
  }

  /// Releases [view] when you won't present it again: one never presented, one kept alive by
  /// [dismissFlowView] with `destroy: false`, or, on iOS, a page sheet the user swiped down, which
  /// stays alive until released. A view dismissed with `destroy: true` is already released. A
  /// presented view is closed, on iOS without the animation, and the call doesn't wait for it: to
  /// close it, use [dismissFlowView] instead.
  ///
  /// Works only with a view created by [createFlowView]: for a view shown by
  /// [AdaptyUIFlowPlatformView], or a released one, it fails with [AdaptyErrorCode.wrongParam].
  ///
  /// **Parameters**
  /// - [view]: the [AdaptyUIFlowView] to release.
  Future<void> destroyFlowView(AdaptyUIFlowView view) async {
    return Adapty()._invokeMethod<void>(
      NativeMethod.destroyFlowView,
      (data) => null,
      {Argument.id: view.id},
    );
  }

  /// Sends [payload] to the script of the flow shown in [view] as the `applicationMsg` SDK event.
  ///
  /// Completes once the message is passed to the flow, not once the script has handled it. Await
  /// each call when the order matters. Fails with [AdaptyErrorCode.wrongParam] if `json.encode`
  /// can't encode [payload], or once [dismissFlowView] or [destroyFlowView] has released [view].
  /// Send to a view from [createFlowView] once [AdaptyUIFlowsEventsObserver.flowViewDidAppear] is
  /// called: on Android it silently drops a message sent before its script starts, even right
  /// after [presentFlowView] returns. On iOS, such a view loses what its script sends back before
  /// it is first presented.
  Future<void> sendAppMessage(AdaptyUIFlowView view, Map<String, dynamic> payload) async {
    // Encoded up front, so a value that cannot be sent fails with an AdaptyError naming the payload.
    try {
      json.encode(payload);
    } catch (error) {
      throw AdaptyError(
        'Failed to encode the app message payload',
        AdaptyErrorCode.wrongParam,
        error.toString(),
      );
    }

    return Adapty()._invokeMethod<void>(
      NativeMethod.sendAppMessage,
      (data) => null,
      {
        Argument.id: view.id,
        Argument.messageId: AdaptyRuntime.current.environment.newMessageId(),
        Argument.payload: payload,
      },
    );
  }

  @Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
  Future<void> dismissOnboardingView(AdaptyUIOnboardingView view) async {
    return Adapty()._invokeMethod<void>(
      NativeMethod.dismissOnboardingView,
      (data) => null,
      {Argument.id: view.id, Argument.destroy: true},
    );
  }

  /// Call this function if you wish to present the dialog.
  ///
  /// Works with the id of a view created by [createFlowView]. For a flow shown by [AdaptyUIFlowPlatformView] it fails
  /// with an [AdaptyError] on iOS.
  ///
  /// **Parameters**
  /// - [title]: The title of the dialog.
  /// - [content]: Descriptive text that provides additional details about the reason for the dialog.
  /// - [primaryActionTitle]: The action title to display as part of the dialog. If you provide two actions, be sure the `defaultAction` cancels the operation and leaves things unchanged.
  /// - [secondaryActionTitle]: The secondary action title to display as part of the dialog.
  Future<AdaptyUIDialogActionType> showDialog(
    String viewId, {
    required String title,
    required String content,
    required String primaryActionTitle,
    String? secondaryActionTitle,
  }) async {
    final dialog = AdaptyUIDialog(
      title: title,
      content: content,
      primaryActionTitle: primaryActionTitle,
      secondaryActionTitle: secondaryActionTitle,
    );

    return await Adapty()._invokeMethod<AdaptyUIDialogActionType>(
      NativeMethod.showDialog,
      (data) => AdaptyUIDialogActionTypeJSONBuilder.fromJsonValue(data as String),
      {
        Argument.id: viewId,
        Argument.configuration: dialog.jsonValue,
      },
    );
  }

  /// Opens a URL natively (external or in-app browser). Backs the default
  /// handling of the flow `open_url` action; can also be called directly.
  Future<void> openUrl(
    String url, {
    AdaptyWebPresentation openIn = AdaptyWebPresentation.externalBrowser,
  }) async {
    return Adapty()._invokeMethod<void>(
      NativeMethod.openUrl,
      (data) => null,
      {
        Argument.url: url,
        Argument.openIn: openIn.jsonValue,
      },
    );
  }

  /// Requests the native in-app review prompt (StoreKit on iOS). Best-effort:
  /// the OS decides whether to actually show it. Backs the default handling of
  /// the flow app-review request; can also be called directly.
  Future<void> requestAppReview() async {
    return Adapty()._invokeMethod<void>(
      NativeMethod.requestAppReview,
      (data) => null,
      const {},
    );
  }
}

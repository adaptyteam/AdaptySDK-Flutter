// ignore_for_file: deprecated_member_use_from_same_package
part of 'adapty.dart';

class AdaptyUI {
  static final AdaptyUI _instance = AdaptyUI._internal();

  factory AdaptyUI() => _instance;

  AdaptyUI._internal();

  AdaptyUIEventsProxy _eventsProxy = AdaptyUIEventsProxy();

  // ignore: unused_field
  AdaptyUISystemRequestsHandler? _systemRequestsHandler;
  // ignore: unused_field
  AdaptyUIObserverModeResolver? _observerModeResolver;

  /// Use this method to set the AdaptyUI system requests handler.
  void setSystemRequestsHandler(AdaptyUISystemRequestsHandler handler) {
    AdaptyLogger.write(AdaptyLogLevel.verbose, 'AdaptyUI.setSystemRequestsHandler()');
    _systemRequestsHandler = handler;
  }

  /// Use this method to set the AdaptyUI observer mode resolver.
  void setObserverModeResolver(AdaptyUIObserverModeResolver resolver) {
    AdaptyLogger.write(AdaptyLogLevel.verbose, 'AdaptyUI.setObserverModeResolver()');
    _observerModeResolver = resolver;
  }

  void registerFlowEventsListener(AdaptyUIFlowsEventsObserver observer, String viewId) {
    _eventsProxy.registerFlowEventsListener(observer, viewId);
  }

  void unregisterFlowEventsListener(String viewId) {
    _eventsProxy.unregisterFlowEventsListener(viewId);
  }

  @Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
  void registerOnboardingEventsListener(AdaptyUIOnboardingsEventsObserver observer, String viewId) {
    _eventsProxy.registerOnboardingEventsListener(observer, viewId);
  }

  @Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
  void unregisterOnboardingEventsListener(String viewId) {
    _eventsProxy.unregisterOnboardingEventsListener(viewId);
  }

  /// Use this method to set the AdaptyUI flows events observer.
  ///
  /// Pass `null` to detach the previously set observer (e.g. on cleanup),
  /// so the SDK no longer holds a reference to it.
  void setFlowsEventsObserver(AdaptyUIFlowsEventsObserver? observer) {
    AdaptyLogger.write(AdaptyLogLevel.verbose, 'AdaptyUI.setFlowsEventsObserver()');
    _eventsProxy.flowsEventsObserver = observer;
  }

  /// Use this method to set the AdaptyUI onboardings events observer.
  ///
  /// Pass `null` to detach the previously set observer (e.g. on cleanup),
  /// so the SDK no longer holds a reference to it.
  @Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
  void setOnboardingsEventsObserver(AdaptyUIOnboardingsEventsObserver? observer) {
    AdaptyLogger.write(AdaptyLogLevel.verbose, 'AdaptyUI.setOnboardingsEventsObserver()');
    _eventsProxy.onboardingsEventsObserver = observer;
  }

  /// Right after receiving ``AdaptyFlow``, you can create the corresponding ``AdaptyUIFlowView`` to present it afterwards.
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
  /// not fail the call; the view retries on its own. With `false` the call does not wait for them.
  /// - [androidEnableSafeArea]: Android only. If `true`, the flow view applies the safe-area insets as paddings. Has no effect on iOS. Defaults to `true`.
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
      Method.createFlowView,
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
      Method.createOnboardingView,
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

  /// Call this function if you wish to present the view.
  ///
  /// On iOS, [iosPresentationStyle] picks a full-screen presentation, the default, or a page
  /// sheet the user can swipe down; Android ignores it.
  ///
  /// Works only with a view created by [createFlowView], including the instances of it that
  /// your observers and handlers receive. For a view shown by [AdaptyUIFlowPlatformView], the
  /// call fails with an [AdaptyError] with [AdaptyErrorCode.wrongParam].
  ///
  /// The call also fails with [AdaptyErrorCode.wrongParam] when the view is already released or a
  /// flow view is already presented.
  ///
  /// **Parameters**
  /// - [view]: the [AdaptyUIFlowView] to present.
  Future<void> presentFlowView(
    AdaptyUIFlowView view, {
    AdaptyUIIOSPresentationStyle iosPresentationStyle = AdaptyUIIOSPresentationStyle.fullScreen,
  }) async {
    return Adapty()._invokeMethod<void>(
      Method.presentFlowView,
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
      Method.presentOnboardingView,
      (data) => null,
      {
        Argument.id: view.id,
        Argument.iosPresentationStyle: iosPresentationStyle.jsonValue,
      },
    );
  }

  /// Call this function if you wish to dismiss the view.
  ///
  /// Works only with a view created by [createFlowView], including the instances of it that
  /// your observers and handlers receive. For a view shown by [AdaptyUIFlowPlatformView], the
  /// call fails with an [AdaptyError] with [AdaptyErrorCode.wrongParam].
  ///
  /// The call also fails with [AdaptyErrorCode.wrongParam] when the view is already released, for
  /// example by an earlier [dismissFlowView] that has completed.
  ///
  /// **Parameters**
  /// - [view]: the [AdaptyUIFlowView] to dismiss.
  /// - [destroy]: whether to release the view along with dismissing it. With `true`, the
  /// default, the view is released and [presentFlowView] on it fails afterwards — call
  /// [createFlowView] again to show the flow once more. Pass `false` to keep the view
  /// alive, so it can be presented again and resumes where the user left it, with the
  /// screen they were on and the state the flow had built up. A view kept alive this way
  /// is held until it is released with [destroyFlowView], or until it is presented again
  /// and dismissed with `destroy: true`.
  Future<void> dismissFlowView(
    AdaptyUIFlowView view, {
    bool destroy = true,
  }) async {
    return Adapty()._invokeMethod<void>(
      Method.dismissFlowView,
      (data) => null,
      {Argument.id: view.id, Argument.destroy: destroy},
    );
  }

  /// Call this function if you wish to release a view you won't present (again): one never
  /// presented, one kept alive by [dismissFlowView] with `destroy: false`, or, on iOS, one the
  /// user swiped down as a page sheet.
  ///
  /// After [dismissFlowView] with `destroy: true`, the default, the view is already
  /// released and there is no need to call this function. Once the view is released,
  /// [presentFlowView] on it fails — call [createFlowView] again to show the flow once
  /// more. Calling this function on a view that is already released fails with an
  /// [AdaptyError] with [AdaptyErrorCode.wrongParam].
  ///
  /// If the view is still presented, it is closed and released: on iOS without the closing
  /// animation, on Android with it, and the call does not wait for the view to close. To close
  /// a presented view, use [dismissFlowView] with `destroy: true` instead: it animates on both
  /// platforms and completes once the view is closed.
  ///
  /// On iOS, a view presented with [AdaptyUIIOSPresentationStyle.pageSheet] can be swiped down
  /// by the user. It then closes without [dismissFlowView] and stays alive: present it again,
  /// or release it with this function when you won't.
  ///
  /// Works only with a view created by [createFlowView], including the instances of it that
  /// your observers and handlers receive. For a view shown by [AdaptyUIFlowPlatformView], the
  /// call fails with an [AdaptyError] with [AdaptyErrorCode.wrongParam].
  ///
  /// **Parameters**
  /// - [view]: the [AdaptyUIFlowView] to release.
  Future<void> destroyFlowView(AdaptyUIFlowView view) async {
    return Adapty()._invokeMethod<void>(
      Method.destroyFlowView,
      (data) => null,
      {Argument.id: view.id},
    );
  }

  @Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
  Future<void> dismissOnboardingView(AdaptyUIOnboardingView view) async {
    return Adapty()._invokeMethod<void>(
      Method.dismissOnboardingView,
      (data) => null,
      {Argument.id: view.id, Argument.destroy: true},
    );
  }

  /// Call this function if you wish to present the dialog.
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
      Method.showDialog,
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
      Method.openUrl,
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
      Method.requestAppReview,
      (data) => null,
      const {},
    );
  }
}

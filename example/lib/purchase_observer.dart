import 'dart:async' show Future;
import 'dart:io' show Platform;
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import 'package:url_launcher/url_launcher.dart';

class PurchasesObserver
    implements
        AdaptyUIFlowsEventsObserver,
        AdaptyUIOnboardingsEventsObserver,
        AdaptyUISystemRequestsHandler,
        AdaptyUIObserverModeResolver {
  void Function(AdaptyError)? onAdaptyErrorOccurred;
  void Function(Object)? onUnknownErrorOccurred;
  void Function(AdaptyInstallationStatus)? onInstallationStatusUpdated;

  final adapty = Adapty();
  AdaptyInstallationStatus installationStatus =
      AdaptyInstallationStatusNotDetermined();

  static final PurchasesObserver _instance = PurchasesObserver._internal();

  factory PurchasesObserver() {
    return _instance;
  }

  PurchasesObserver._internal();

  Future<void> initialize() async {
    try {
      Adapty().setLogLevel(AdaptyLogLevel.debug);

      var isActivated = false;

      if (kDebugMode) {
        isActivated = await Adapty().isActivated();
      } else {
        isActivated = false;
      }

      if (!isActivated) {
        await Adapty().activate(
          configuration: AdaptyConfiguration(
              apiKey: 'public_live_iNuUlSsN.83zcTTR8D5Y8FI9cGUI6')
            ..withLogLevel(AdaptyLogLevel.debug)
            ..withObserverMode(
                false) // set to true to exercise AdaptyUIObserverModeResolver below
            // ..withCustomerUserId(
            //   "test_1234567890",
            //   iosAppAccountToken: '1234567890',
            //   androidObfuscatedAccountId: '1234567890',
            // )
            ..withIpAddressCollectionDisabled(false)
            ..withAppleIdfaCollectionDisabled(false)
            ..withGoogleAdvertisingIdCollectionDisabled(false)
            ..withGoogleEnablePendingPrepaidPlans(false)
            ..withAppleClearDataOnBackup(false)
            ..withActivateUI(true),
        );

        _setFallbackPaywalls();
      } else {
        Adapty().setupAfterHotRestart();
      }

      AdaptyUI().setFlowsEventsObserver(this);
      AdaptyUI().setOnboardingsEventsObserver(this);
      AdaptyUI().setSystemRequestsHandler(this);
      AdaptyUI().setObserverModeResolver(this);

      Adapty().onUpdateInstallationDetailsSuccessStream.listen((details) {
        print('#Example# onUpdateInstallationDetailsSuccessStream $details');
        installationStatus = AdaptyInstallationStatusDetermined(details);
        onInstallationStatusUpdated
            ?.call(AdaptyInstallationStatusDetermined(details));
      });

      Adapty().onUpdateInstallationDetailsFailStream.listen((error) {
        print('#Example# onUpdateInstallationDetailsFailStream $error');
      });

      await callGetFlowForDefaultAudience('example_ab_test');
    } catch (e) {
      print('#Example# activate error $e');
    }
  }

  Future<T?> _withErrorHandling<T>(
    Future<T> Function() body, {
    bool suppressError = false,
  }) async {
    try {
      return await body();
    } on AdaptyError catch (adaptyError) {
      if (!suppressError) {
        onAdaptyErrorOccurred?.call(adaptyError);
      }
    } catch (e) {
      if (!suppressError) {
        onUnknownErrorOccurred?.call(e);
      }
    }

    return null;
  }

  Future<AdaptyInstallationStatus?> callGetCurrentInstallationStatus() async {
    return _withErrorHandling(() async {
      final status = await adapty.getCurrentInstallationStatus();
      installationStatus = status;
      onInstallationStatusUpdated?.call(status);
      return status;
    });
  }

  Future<void> _setFallbackPaywalls() async {
    final assetId = Platform.isIOS
        ? 'assets/fallback_ios.json'
        : 'assets/fallback_android.json';
    return _withErrorHandling(() async {
      await adapty.setFallback(assetId);
    });
  }

  Future<AdaptyProfile?> callGetProfile() async {
    return _withErrorHandling(() async {
      return await adapty.getProfile();
    });
  }

  Future<void> callIdentifyUser(
    String customerUserId, {
    String? iosAppAccountToken,
    String? androidObfuscatedAccountId,
  }) async {
    try {
      await adapty.identify(
        customerUserId,
        iosAppAccountToken: iosAppAccountToken,
        androidObfuscatedAccountId: androidObfuscatedAccountId,
      );
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccurred?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccurred?.call(e);
    }
  }

  Future<void> callUpdateProfile(AdaptyProfileParameters params) async {
    return _withErrorHandling(() async {
      await adapty.updateProfile(params);
    });
  }

  Future<void> callSetIntegrationIdentifier(String key, String value) async {
    return _withErrorHandling(() async {
      await adapty.setIntegrationIdentifier(key: key, value: value);
    });
  }

  Future<AdaptyFlow?> callGetFlowForDefaultAudience(
    String placementId,
  ) async {
    return _withErrorHandling(() async {
      return await adapty.getFlowForDefaultAudience(
        placementId: placementId,
      );
    });
  }

  Future<AdaptyFlow?> callGetFlow(
    String flowId,
    String? locale,
    AdaptyFlowFetchPolicy fetchPolicy,
  ) async {
    return _withErrorHandling(() async {
      return await adapty.getFlow(
        placementId: flowId,
        locale: locale,
        fetchPolicy: fetchPolicy,
        loadTimeout: const Duration(seconds: 5),
      );
    });
  }

  Future<List<AdaptyPaywallProduct>?> callGetPaywallProducts(
      AdaptyFlow flow) async {
    return _withErrorHandling(() async {
      return await adapty.getPaywallProducts(flow: flow);
    });
  }

  Future<AdaptyPurchaseResult?> callMakePurchase(
    AdaptyPaywallProduct product,
    AdaptyPurchaseParameters? parameters,
  ) async {
    return _withErrorHandling(() async {
      return await adapty.makePurchase(
        product: product,
        parameters: parameters,
      );
    });
  }

  Future<AdaptyProfile?> callRestorePurchases() async {
    return _withErrorHandling(() async {
      return await adapty.restorePurchases();
    });
  }

  Future<void> callUpdateAttribution(
    Map<dynamic, dynamic> attribution,
    String source,
  ) async {
    return _withErrorHandling(() async {
      await adapty.updateAttribution(
        attribution,
        source: source,
      );
    });
  }

  Future<void> callLogShowFlow(AdaptyFlow flow) async {
    return _withErrorHandling(() async {
      return await adapty.logShowFlow(flow: flow);
    });
  }

  Future<void> callReportTransaction({
    required String transactionId,
    String? variationId,
  }) async {
    return _withErrorHandling(() async {
      return await adapty.reportTransaction(
          transactionId: transactionId, variationId: variationId);
    });
  }

  Future<void> callLogout() async {
    return _withErrorHandling(() async {
      return await adapty.logout();
    });
  }

  Future<void> callPresentCodeRedemptionSheet() async {
    return _withErrorHandling(() async {
      return await adapty.presentCodeRedemptionSheet();
    });
  }

  Future<void> callUpdateCollectingRefundDataConsent(bool consent) async {
    return _withErrorHandling(() async {
      return await adapty.updateCollectingRefundDataConsent(consent);
    });
  }

  Future<void> callUpdateRefundPreference(
      AdaptyRefundPreference refundPreference) async {
    return _withErrorHandling(() async {
      return await adapty.updateRefundPreference(refundPreference);
    });
  }

  Future<String?> callCreateWebPaywallUrl(AdaptyPaywallProduct product) async {
    return _withErrorHandling(() async {
      return await adapty.createWebPaywallUrl(product: product);
    }, suppressError: true);
  }

  Future<void> callOpenWebPaywall({
    AdaptyFlow? flow,
    AdaptyPaywallProduct? product,
  }) async {
    return _withErrorHandling(() async {
      return await adapty.openWebPaywall(
        flow: flow,
        product: product,
        openIn: AdaptyWebPresentation.inAppBrowser,
      );
    });
  }

  // AdaptyUIFlowsEventsObserver

  @override
  void flowViewDidAppear(AdaptyUIFlowView view) {
    print('#Example# flowViewDidAppear of $view');
  }

  @override
  void flowViewDidDisappear(AdaptyUIFlowView view) {
    print('#Example# flowViewDidDisappear of $view');
  }

  @override
  void flowViewDidPerformAction(
      AdaptyUIFlowView view, AdaptyUIAction action) async {
    print('#Example# flowViewDidPerformAction ${action.runtimeType} of $view');

    switch (action) {
      case const CloseAction():
      case const AndroidSystemBackAction():
        view.dismiss();
        break;
      case OpenUrlAction(url: final url, openIn: final openIn):
        final Uri uri = Uri.parse(url);

        final selectedAction = await _showDialogSafely(
          view,
          title: 'Open URL?',
          content:
              'Open in ${openIn == AdaptyWebPresentation.inAppBrowser ? 'in-app' : 'external'} browser?\n$url',
          primaryActionTitle: 'Cancel',
          secondaryActionTitle: 'OK',
        );

        switch (selectedAction) {
          case AdaptyUIDialogActionType.primary:
            print('#Example# flowViewDidPerformAction primaryAction');
            break;
          case AdaptyUIDialogActionType.secondary:
            print('#Example# flowViewDidPerformAction secondaryAction');
            final mode = switch (openIn) {
              AdaptyWebPresentation.inAppBrowser => LaunchMode.inAppBrowserView,
              AdaptyWebPresentation.externalBrowser =>
                LaunchMode.externalApplication,
            };
            launchUrl(uri, mode: mode);
            break;
          case null:
            break;
        }
        break;
      default:
        break;
    }
  }

  @override
  void flowViewDidFailLoadingProducts(
      AdaptyUIFlowView view, AdaptyError error) {
    print('#Example# flowViewDidFailLoadingProducts of $view, error = $error');
  }

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) {
    view.dismiss();
  }

  @override
  void flowViewDidFinishPurchase(AdaptyUIFlowView view,
      AdaptyPaywallProduct product, AdaptyPurchaseResult purchaseResult) {
    print('#Example# flowViewDidFinishPurchase of $view');

    switch (purchaseResult) {
      case AdaptyPurchaseResultSuccess(profile: final profile):
        if (profile.accessLevels['premium']?.isActive ?? false) {
          view.dismiss();
        }
        break;
      case AdaptyPurchaseResultPending():
        break;
      case AdaptyPurchaseResultUserCancelled():
        break;
    }
  }

  @override
  void flowViewDidFailPurchase(
      AdaptyUIFlowView view, AdaptyPaywallProduct product, AdaptyError error) {
    print(
        '#Example# flowViewDidFailPurchase ${product.vendorProductId} of $view, error = $error');
  }

  @override
  void flowViewDidStartRestore(AdaptyUIFlowView view) {
    print('#Example# flowViewDidStartRestore of $view');
  }

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {
    print('#Example# flowViewDidFinishRestore of $view');

    _handleFinishRestore(view, profile);
  }

  Future<void> _handleFinishRestore(
      AdaptyUIFlowView view, AdaptyProfile profile) async {
    await _showDialogSafely(
      view,
      title: 'Success!',
      content: 'Purchases were successfully restored.',
      primaryActionTitle: 'OK',
    );

    if (profile.accessLevels['premium']?.isActive ?? false) {
      await view.dismiss();
    }
  }

  @override
  void flowViewDidFailRestore(AdaptyUIFlowView view, AdaptyError error) {
    print('#Example# flowViewDidFailRestore of $view, error = $error');

    _showDialogSafely(
      view,
      title: 'Error!',
      content: error.toString(),
      primaryActionTitle: 'OK',
    );
  }

  @override
  void flowViewDidSelectProduct(AdaptyUIFlowView view, String productId) {
    print('#Example# flowViewDidSelectProduct $productId of $view');
  }

  @override
  void flowViewDidStartPurchase(
      AdaptyUIFlowView view, AdaptyPaywallProduct product) {
    print(
        '#Example# flowViewDidStartPurchase ${product.vendorProductId} of $view');
  }

  @override
  void flowViewDidFinishWebPaymentNavigation(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) {
    print(
        '#Example# flowViewDidFinishWebPaymentNavigation of $view, product = $product, error = $error');
  }

  @override
  void flowViewDidReceiveAnalyticEvent(
      AdaptyUIFlowView view, String name, Map<String, dynamic> params) {
    print(
        '#Example# flowViewDidReceiveAnalyticEvent of $view, name = $name, params = $params');
    _showToast('Flow: didReceiveAnalyticEvent', 'name: $name, view: $view');
  }

  void _showToast(String title, String description) {
    toastification.show(
      type: ToastificationType.info,
      style: ToastificationStyle.minimal,
      title: Text(title),
      description: Text(description),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  /// `showDialog` is only supported for presented flow views. Platform-view flows
  /// (rendered via `AdaptyUIFlowPlatformView`) are not in the native controller
  /// registry, so the call throws `AdaptyUIError.viewNotFound`. Swallow it so this
  /// global flows observer stays render-mode agnostic.
  Future<AdaptyUIDialogActionType?> _showDialogSafely(
    AdaptyUIFlowView view, {
    required String title,
    required String content,
    required String primaryActionTitle,
    String? secondaryActionTitle,
  }) async {
    try {
      return await view.showDialog(
        title: title,
        content: content,
        primaryActionTitle: primaryActionTitle,
        secondaryActionTitle: secondaryActionTitle,
      );
    } catch (e) {
      print('#Example# showDialog skipped ($e)');
      return null;
    }
  }

  // AdaptyUISystemRequestsHandler (permission & app-review requests from flow JS actions)

  @override
  Future<AdaptyUIPermissionResult> handlePermission(
    AdaptyUIFlowView view,
    AdaptyUIPermission permission,
    Map<String, String>? customArgs,
  ) async {
    print(
        '#Example# handlePermission ${permission.value} of $view, customArgs = $customArgs');
    _showToast('SystemRequest: handlePermission',
        'permission: ${permission.value}, view: $view');
    // A real app would invoke the corresponding OS permission API here and map the
    // outcome. The example just acknowledges the round-trip as granted.
    return const AdaptyUIPermissionResult.granted('example stub');
  }

  @override
  Future<void> handleAppReviewRequest(AdaptyUIFlowView view) async {
    print('#Example# handleAppReviewRequest of $view');
    _showToast('SystemRequest: handleAppReviewRequest', 'view: $view');
  }

  // AdaptyUIObserverModeResolver (only fires when Observer Mode is enabled)

  @override
  void observerModeDidInitiatePurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    void Function() onStartPurchase,
    void Function() onFinishPurchase,
  ) {
    print(
        '#Example# observerModeDidInitiatePurchase ${product.vendorProductId} of $view');
    _showToast('ObserverMode: didInitiatePurchase',
        'product: ${product.vendorProductId}, view: $view');
    // In Observer Mode the host performs the purchase. Bracket it with start/finish
    // so the SDK can drive its UI. Simulate the host taking a few seconds to run the
    // real purchase so the SDK's in-between loading state and the request_id round-trip
    // are exercised across a delay.
    onStartPurchase();
    Future.delayed(const Duration(seconds: 3), onFinishPurchase);
  }

  @override
  void observerModeDidInitiateRestore(
    AdaptyUIFlowView view,
    void Function() onStartRestore,
    void Function() onFinishRestore,
  ) {
    print('#Example# observerModeDidInitiateRestore of $view');
    _showToast('ObserverMode: didInitiateRestore', 'view: $view');
    // Simulate the host taking a few seconds to run the real restore.
    onStartRestore();
    Future.delayed(const Duration(seconds: 3), onFinishRestore);
  }

  @override
  void onboardingViewDidFinishLoading(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
  ) {
    print('#Example# onboardingViewDidFinishLoading of $view, meta = $meta');
  }

  @override
  void onboardingViewDidFailWithError(
    AdaptyUIOnboardingView view,
    AdaptyError error,
  ) {
    print('#Example# onboardingViewDidFailWithError of $view, error = $error');
  }

  @override
  void onboardingViewOnCloseAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {
    print(
        '#Example# onboardingViewOnCloseAction of $view, meta = $meta, actionId = $actionId');

    if (view.isNativeRendering) {
      view.dismiss();
    }
  }

  @override
  void onboardingViewOnPaywallAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {
    print(
        '#Example# onboardingViewOnPaywallAction of $view, meta = $meta, actionId = $actionId');

    _presentPaywall(actionId);
  }

  Future<void> _presentPaywall(String placementId) async {
    try {
      final flow = await Adapty().getFlow(placementId: placementId);
      final flowView = await AdaptyUI().createFlowView(flow: flow);
      await flowView.present();
    } catch (e) {
      print('#Example# _presentPaywall error $e');
    }
  }

  @override
  void onboardingViewOnCustomAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {
    print(
        '#Example# onboardingViewOnCustomAction of $view, meta = $meta, actionId = $actionId');
  }

  @override
  void onboardingViewOnStateUpdatedAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String elementId,
    AdaptyOnboardingsStateUpdatedParams params,
  ) {
    print(
        '#Example# onboardingViewOnStateUpdatedAction of $view, meta = $meta, elementId = $elementId');

    switch (params) {
      case AdaptyOnboardingsSelectParams(
          id: final id,
          value: final value,
          label: final label
        ):
        print(
            '#Example# onboardingViewOnStateUpdatedAction select $id $value $label');
        break;
      case AdaptyOnboardingsMultiSelectParams(params: final params):
        final paramsString = params
            .map((e) => '(id: ${e.id}, value: ${e.value}, label: ${e.label})')
            .join(', ');
        print(
            '#Example# onboardingViewOnStateUpdatedAction multiSelect: [$paramsString]');
        break;
      case AdaptyOnboardingsInputParams(input: final input):
        switch (input) {
          case AdaptyOnboardingsTextInput(value: final value):
            print('#Example# onboardingViewOnStateUpdatedAction text $value');
            break;
          case AdaptyOnboardingsEmailInput(value: final value):
            print('#Example# onboardingViewOnStateUpdatedAction email $value');
            break;
          case AdaptyOnboardingsNumberInput(value: final value):
            print('#Example# onboardingViewOnStateUpdatedAction number $value');
            break;
        }
        break;
      case AdaptyOnboardingsDatePickerParams(
          day: final day,
          month: final month,
          year: final year
        ):
        print(
            '#Example# onboardingViewOnStateUpdatedAction datePicker $day $month $year');
        break;
    }
  }

  @override
  void onboardingViewOnAnalyticsEvent(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    AdaptyOnboardingsAnalyticsEvent event,
  ) {
    switch (event) {
      case AdaptyOnboardingsAnalyticsEventOnboardingStarted():
        print(
            '#Example# onboardingViewOnAnalyticsEvent onboardingStarted, meta = $meta');
        break;
      case AdaptyOnboardingsAnalyticsEventScreenPresented():
        print(
            '#Example# onboardingViewOnAnalyticsEvent screenPresented, meta = $meta');
        break;
      case AdaptyOnboardingsAnalyticsEventScreenCompleted(
          elementId: final elementId,
          reply: final reply
        ):
        print(
            '#Example# onboardingViewOnAnalyticsEvent screenCompleted, meta = $meta, elementId = $elementId, reply = $reply');
        break;
      case AdaptyOnboardingsAnalyticsEventSecondScreenPresented():
        print(
            '#Example# onboardingViewOnAnalyticsEvent secondScreenPresented, meta = $meta');
        break;
      case AdaptyOnboardingsAnalyticsEventRegistrationScreenPresented():
        print(
            '#Example# onboardingViewOnAnalyticsEvent registrationScreenPresented, meta = $meta');
        break;
      case AdaptyOnboardingsAnalyticsEventProductsScreenPresented():
        print(
            '#Example# onboardingViewOnAnalyticsEvent productsScreenPresented, meta = $meta');
        break;
      case AdaptyOnboardingsAnalyticsEventUserEmailCollected():
        print(
            '#Example# onboardingViewOnAnalyticsEvent userEmailCollected, meta = $meta');
        break;
      case AdaptyOnboardingsAnalyticsEventOnboardingCompleted():
        print(
            '#Example# onboardingViewOnAnalyticsEvent onboardingCompleted, meta = $meta');
        break;
      case AdaptyOnboardingsAnalyticsEventUnknown(name: final name):
        print('#Example# onboardingViewOnAnalyticsEvent unknown $name');
    }
  }
}

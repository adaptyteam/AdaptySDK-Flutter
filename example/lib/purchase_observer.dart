import 'dart:async' show Future;
import 'dart:io' show Platform;
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class PurchasesObserver implements AdaptyUIPaywallsEventsObserver, AdaptyUIOnboardingsEventsObserver {
  void Function(AdaptyError)? onAdaptyErrorOccurred;
  void Function(Object)? onUnknownErrorOccurred;
  void Function(AdaptyInstallationStatus)? onInstallationStatusUpdated;

  final adapty = Adapty();
  AdaptyInstallationStatus installationStatus = AdaptyInstallationStatusNotDetermined();

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
          configuration: AdaptyConfiguration(apiKey: 'public_live_GB5pFlIf.MUfgda5fbexiioCWJqvN')
            ..withBackendBaseUrl('https://app-dev.k8s.adapty.io/api/v1')
            ..withLogLevel(AdaptyLogLevel.debug)
            ..withObserverMode(false)
            ..withCustomerUserId(null)
            ..withIpAddressCollectionDisabled(false)
            ..withAppleIdfaCollectionDisabled(false)
            ..withGoogleAdvertisingIdCollectionDisabled(false)
            ..withActivateUI(true),
        );

        _setFallbackPaywalls();
      } else {
        Adapty().setupAfterHotRestart();
      }

      AdaptyUI().setPaywallsEventsObserver(this);
      AdaptyUI().setOnboardingsEventsObserver(this);

      Adapty().onUpdateInstallationDetailsSuccessStream.listen((details) {
        print('#Example# onUpdateInstallationDetailsSuccessStream $details');
        installationStatus = AdaptyInstallationStatusDetermined(details);
        onInstallationStatusUpdated?.call(AdaptyInstallationStatusDetermined(details));
      });

      Adapty().onUpdateInstallationDetailsFailStream.listen((error) {
        print('#Example# onUpdateInstallationDetailsFailStream $error');
      });

      await callGetPaywallForDefaultAudience('example_ab_test');
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
    final assetId = Platform.isIOS ? 'assets/fallback_ios.json' : 'assets/fallback_android.json';
    return _withErrorHandling(() async {
      await adapty.setFallback(assetId);
    });
  }

  Future<AdaptyProfile?> callGetProfile() async {
    return _withErrorHandling(() async {
      return await adapty.getProfile();
    });
  }

  Future<void> callIdentifyUser(String customerUserId) async {
    try {
      await adapty.identify(customerUserId);
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

  Future<AdaptyPaywall?> callGetPaywallForDefaultAudience(
    String placementId,
  ) async {
    return _withErrorHandling(() async {
      return await adapty.getPaywallForDefaultAudience(
        placementId: placementId,
      );
    });
  }

  Future<AdaptyPaywall?> callGetPaywall(
    String paywallId,
    String? locale,
    AdaptyPaywallFetchPolicy fetchPolicy,
  ) async {
    return _withErrorHandling(() async {
      return await adapty.getPaywall(
        placementId: paywallId,
        locale: locale,
        fetchPolicy: fetchPolicy,
        loadTimeout: const Duration(seconds: 5),
      );
    });
  }

  Future<List<AdaptyPaywallProduct>?> callGetPaywallProducts(AdaptyPaywall paywall) async {
    return _withErrorHandling(() async {
      return await adapty.getPaywallProducts(paywall: paywall);
    });
  }

  Future<AdaptyPurchaseResult?> callMakePurchase(AdaptyPaywallProduct product) async {
    return _withErrorHandling(() async {
      return await adapty.makePurchase(product: product);
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

  Future<void> callLogShowPaywall(AdaptyPaywall paywall) async {
    return _withErrorHandling(() async {
      return await adapty.logShowPaywall(paywall: paywall);
    });
  }

  Future<void> callLogShowOnboarding(
    String? name,
    String? screenName,
    int screenOrder,
  ) async {
    return _withErrorHandling(() async {
      return await adapty.logShowOnboarding(
        name: name,
        screenName: screenName,
        screenOrder: screenOrder,
      );
    });
  }

  Future<void> callReportTransaction({
    required String transactionId,
    String? variationId,
  }) async {
    return _withErrorHandling(() async {
      return await adapty.reportTransaction(transactionId: transactionId, variationId: variationId);
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

  Future<void> callUpdateRefundPreference(AdaptyRefundPreference refundPreference) async {
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
    AdaptyPaywall? paywall,
    AdaptyPaywallProduct? product,
  }) async {
    return _withErrorHandling(() async {
      return await adapty.openWebPaywall(paywall: paywall, product: product);
    });
  }

  // AdaptyUIObserver

  @override
  void paywallViewDidAppear(AdaptyUIPaywallView view) {
    print('#Example# paywallViewDidAppear of $view');
  }

  @override
  void paywallViewDidDisappear(AdaptyUIPaywallView view) {
    print('#Example# paywallViewDidDisappear of $view');
  }

  @override
  void paywallViewDidPerformAction(AdaptyUIPaywallView view, AdaptyUIAction action) async {
    print('#Example# paywallViewDidPerformAction ${action.runtimeType} of $view');

    switch (action) {
      case const CloseAction():
      case const AndroidSystemBackAction():
        view.dismiss();
        break;
      case OpenUrlAction(url: final url):
        final Uri uri = Uri.parse(url);

        final selectedAction = await view.showDialog(
          title: 'Open URL?',
          content: url,
          primaryActionTitle: 'Cancel',
          secondaryActionTitle: 'OK',
        );

        switch (selectedAction) {
          case AdaptyUIDialogActionType.primary:
            print('#Example# paywallViewDidPerformAction primaryAction');
            break;
          case AdaptyUIDialogActionType.secondary:
            print('#Example# paywallViewDidPerformAction secondaryAction');
            launchUrl(uri, mode: LaunchMode.inAppBrowserView);
            break;
        }
        break;
      default:
        break;
    }
  }

  @override
  void paywallViewDidFailLoadingProducts(AdaptyUIPaywallView view, AdaptyError error) {
    print('#Example# paywallViewDidFailLoadingProducts of $view, error = $error');
  }

  @override
  void paywallViewDidFailRendering(AdaptyUIPaywallView view, AdaptyError error) {
    print('#Example# paywallViewDidFailRendering of $view, error = $error');
  }

  @override
  void paywallViewDidFinishPurchase(AdaptyUIPaywallView view, AdaptyPaywallProduct product, AdaptyPurchaseResult purchaseResult) {
    print('#Example# paywallViewDidFinishPurchase of $view');

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
  void paywallViewDidFailPurchase(AdaptyUIPaywallView view, AdaptyPaywallProduct product, AdaptyError error) {
    print('#Example# paywallViewDidFailPurchase ${product.vendorProductId} of $view, error = $error');
  }

  @override
  void paywallViewDidStartRestore(AdaptyUIPaywallView view) {
    print('#Example# paywallViewDidStartRestore of $view');
  }

  @override
  void paywallViewDidFinishRestore(AdaptyUIPaywallView view, AdaptyProfile profile) {
    print('#Example# paywallViewDidFinishRestore of $view');

    _handleFinishRestore(view, profile);
  }

  Future<void> _handleFinishRestore(AdaptyUIPaywallView view, AdaptyProfile profile) async {
    await view.showDialog(
      title: 'Success!',
      content: 'Purchases were successfully restored.',
      primaryActionTitle: 'OK',
    );

    if (profile.accessLevels['premium']?.isActive ?? false) {
      await view.dismiss();
    }
  }

  @override
  void paywallViewDidFailRestore(AdaptyUIPaywallView view, AdaptyError error) {
    print('#Example# paywallViewDidFailRestore of $view, error = $error');

    view.showDialog(
      title: 'Error!',
      content: error.toString(),
      primaryActionTitle: 'OK',
    );
  }

  @override
  void paywallViewDidSelectProduct(AdaptyUIPaywallView view, String productId) {
    print('#Example# paywallViewDidSelectProduct $productId of $view');
  }

  @override
  void paywallViewDidStartPurchase(AdaptyUIPaywallView view, AdaptyPaywallProduct product) {
    print('#Example# paywallViewDidStartPurchase ${product.vendorProductId} of $view');
  }

  @override
  void paywallViewDidFinishWebPaymentNavigation(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) {
    print('#Example# paywallViewDidFinishWebPaymentNavigation of $view, product = $product, error = $error');
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
    print('#Example# onboardingViewOnCloseAction of $view, meta = $meta, actionId = $actionId');

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
    print('#Example# onboardingViewOnPaywallAction of $view, meta = $meta, actionId = $actionId');

    _presentPaywall(actionId);
  }

  Future<void> _presentPaywall(String placementId) async {
    try {
      final paywall = await Adapty().getPaywall(placementId: placementId);
      final paywallView = await AdaptyUI().createPaywallView(paywall: paywall);
      await paywallView.present();
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
    print('#Example# onboardingViewOnCustomAction of $view, meta = $meta, actionId = $actionId');
  }

  @override
  void onboardingViewOnStateUpdatedAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String elementId,
    AdaptyOnboardingsStateUpdatedParams params,
  ) {
    print('#Example# onboardingViewOnStateUpdatedAction of $view, meta = $meta, elementId = $elementId');

    switch (params) {
      case AdaptyOnboardingsSelectParams(id: final id, value: final value, label: final label):
        print('#Example# onboardingViewOnStateUpdatedAction select $id $value $label');
        break;
      case AdaptyOnboardingsMultiSelectParams(params: final params):
        final paramsString = params.map((e) => '(id: ${e.id}, value: ${e.value}, label: ${e.label})').join(', ');
        print('#Example# onboardingViewOnStateUpdatedAction multiSelect: [$paramsString]');
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
      case AdaptyOnboardingsDatePickerParams(day: final day, month: final month, year: final year):
        print('#Example# onboardingViewOnStateUpdatedAction datePicker $day $month $year');
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
        print('#Example# onboardingViewOnAnalyticsEvent onboardingStarted, meta = $meta');
        break;
      case AdaptyOnboardingsAnalyticsEventScreenPresented():
        print('#Example# onboardingViewOnAnalyticsEvent screenPresented, meta = $meta');
        break;
      case AdaptyOnboardingsAnalyticsEventScreenCompleted(elementId: final elementId, reply: final reply):
        print('#Example# onboardingViewOnAnalyticsEvent screenCompleted, meta = $meta, elementId = $elementId, reply = $reply');
        break;
      case AdaptyOnboardingsAnalyticsEventSecondScreenPresented():
        print('#Example# onboardingViewOnAnalyticsEvent secondScreenPresented, meta = $meta');
        break;
      case AdaptyOnboardingsAnalyticsEventRegistrationScreenPresented():
        print('#Example# onboardingViewOnAnalyticsEvent registrationScreenPresented, meta = $meta');
        break;
      case AdaptyOnboardingsAnalyticsEventProductsScreenPresented():
        print('#Example# onboardingViewOnAnalyticsEvent productsScreenPresented, meta = $meta');
        break;
      case AdaptyOnboardingsAnalyticsEventUserEmailCollected():
        print('#Example# onboardingViewOnAnalyticsEvent userEmailCollected, meta = $meta');
        break;
      case AdaptyOnboardingsAnalyticsEventOnboardingCompleted():
        print('#Example# onboardingViewOnAnalyticsEvent onboardingCompleted, meta = $meta');
        break;
      case AdaptyOnboardingsAnalyticsEventUnknown(name: final name):
        print('#Example# onboardingViewOnAnalyticsEvent unknown $name');
    }
  }
}

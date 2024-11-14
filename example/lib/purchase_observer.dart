import 'dart:async' show Future;
import 'dart:io' show Platform;
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

class PurchasesObserver implements AdaptyUIObserver {
  void Function(AdaptyError)? onAdaptyErrorOccurred;
  void Function(Object)? onUnknownErrorOccurred;

  final adapty = Adapty();

  static final PurchasesObserver _instance = PurchasesObserver._internal();

  factory PurchasesObserver() {
    return _instance;
  }

  PurchasesObserver._internal();

  Future<void> initialize() async {
    try {
      adapty.setLogLevel(AdaptyLogLevel.debug);
      _setFallbackPaywalls();

      await adapty.activate(
        configuration: AdaptyConfiguration(apiKey: 'public_live_iNuUlSsN.83zcTTR8D5Y8FI9cGUI6')
          ..withLogLevel(AdaptyLogLevel.debug)
          ..withObserverMode(false)
          ..withCustomerUserId(null)
          ..withIpAddressCollectionDisabled(false)
          ..withIdfaCollectionDisabled(false),
      );

      await AdaptyUI().activate(
        configuration: AdaptyUIConfiguration(),
        observer: this,
      );
    } catch (e) {
      print('#Example# activate error $e');
    }
  }

  Future<T?> _withErrorHandling<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccurred?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccurred?.call(e);
    }

    return null;
  }

  Future<void> _setFallbackPaywalls() async {
    final assetId = Platform.isIOS ? 'assets/fallback_ios.json' : 'assets/fallback_android.json';
    return _withErrorHandling(() async {
      await adapty.setFallbackPaywalls(assetId);
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
    AdaptyAttributionSource source,
    String networkUserId,
  ) async {
    return _withErrorHandling(() async {
      await adapty.updateAttribution(
        attribution,
        source: source,
        networkUserId: networkUserId,
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

  Future<void> callSetVariationId(String transactionId, String variationId) async {
    return _withErrorHandling(() async {
      return await adapty.setVariationId(transactionId, variationId);
    });
  }

  Future<void> callLogout() async {
    return _withErrorHandling(() async {
      return await adapty.logout();
    });
  }

  Future<void> callPresentCodeRedemptionSheet() async {
    // TODO: check
    return _withErrorHandling(() async {
      return await adapty.presentCodeRedemptionSheet();
    });
  }

  // AdaptyUIObserver

  @override
  void paywallViewDidPerformAction(AdaptyUIView view, AdaptyUIAction action) {
    print('#Example# paywallViewDidPerformAction ${action.type} of $view');

    switch (action.type) {
      case AdaptyUIActionType.close:
        view.dismiss();
        break;
      case AdaptyUIActionType.openUrl:
        final dialog = AdaptyUIDialog(
          title: 'Open URL?',
          content: action.value,
          defaultAction: AdaptyUIDialogAction(
            title: 'Cancel',
            onPressed: () {
              print('#Example# paywallViewDidPerformAction defaultAction');
            },
          ),
          secondaryAction: AdaptyUIDialogAction(
            title: 'OK',
            onPressed: () {
              // Open URL here
              print('#Example# paywallViewDidPerformAction secondaryAction');
            },
          ),
        );

        view.showDialog(dialog);
        break;
      default:
        break;
    }
  }

  @override
  void paywallViewDidCancelPurchase(AdaptyUIView view, AdaptyPaywallProduct product) {
    print('#Example# paywallViewDidCancelPurchase of $view');
  }

  @override
  void paywallViewDidFailLoadingProducts(AdaptyUIView view, AdaptyError error) {
    print('#Example# paywallViewDidFailLoadingProducts of $view, error = $error');
  }

  @override
  void paywallViewDidFailRendering(AdaptyUIView view, AdaptyError error) {
    print('#Example# paywallViewDidFailRendering of $view, error = $error');
  }

  @override
  void paywallViewDidFinishPurchase(AdaptyUIView view, AdaptyPaywallProduct product, AdaptyProfile profile) {
    print('#Example# paywallViewDidFinishPurchase of $view');

    if (profile.accessLevels['premium']?.isActive ?? false) {
      view.dismiss();
    }
  }

  @override
  void paywallViewDidFailPurchase(AdaptyUIView view, AdaptyPaywallProduct product, AdaptyError error) {
    print('#Example# paywallViewDidFailPurchase ${product.vendorProductId} of $view, error = $error');
  }

  @override
  void paywallViewDidStartRestore(AdaptyUIView view) {
    print('#Example# paywallViewDidStartRestore of $view');
  }

  @override
  void paywallViewDidFinishRestore(AdaptyUIView view, AdaptyProfile profile) {
    print('#Example# paywallViewDidFinishRestore of $view');

    _handleFinishRestore(view, profile);
  }

  Future<void> _handleFinishRestore(AdaptyUIView view, AdaptyProfile profile) async {
    final dialog = AdaptyUIDialog(
      title: 'Purchases Restored',
      content: null,
      defaultAction: AdaptyUIDialogAction(title: 'OK', onPressed: () {}),
    );

    await view.showDialog(dialog);

    if (profile.accessLevels['premium']?.isActive ?? false) {
      await view.dismiss();
    }
  }

  @override
  void paywallViewDidFailRestore(AdaptyUIView view, AdaptyError error) {
    print('#Example# paywallViewDidFailRestore of $view, error = $error');

    final dialog = AdaptyUIDialog(
      title: 'Error!',
      content: error.toString(),
      defaultAction: AdaptyUIDialogAction(title: 'OK', onPressed: () {}),
    );

    view.showDialog(dialog);
  }

  @override
  void paywallViewDidSelectProduct(AdaptyUIView view, String productId) {
    print('#Example# paywallViewDidSelectProduct $productId of $view');
  }

  @override
  void paywallViewDidStartPurchase(AdaptyUIView view, AdaptyPaywallProduct product) {
    print('#Example# paywallViewDidStartPurchase ${product.vendorProductId} of $view');
  }
}

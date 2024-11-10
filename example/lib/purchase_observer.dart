import 'dart:async' show Future;
import 'dart:io' show Platform;
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

class PurchasesObserver {
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
      await adapty.activate(
        AdaptyConfiguration(apiKey: 'public_live_iNuUlSsN.83zcTTR8D5Y8FI9cGUI6')
          ..withLogLevel(AdaptyLogLevel.verbose)
          ..withObserverMode(false)
          ..withCustomerUserId(null)
          ..withIpAddressCollectionDisabled(false)
          ..withIdfaCollectionDisabled(false),
      );
      await _setFallbackPaywalls();
    } catch (e) {
      print('#Example# activate error $e');
    }
  }

  Future<void> _setFallbackPaywalls() async {
    final filePath = Platform.isIOS ? 'assets/fallback_ios.json' : 'assets/fallback_android.json';
    final jsonString = await rootBundle.loadString(filePath);

    try {
      await adapty.setFallbackPaywalls(jsonString);
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccurred?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccurred?.call(e);
    }
  }

  Future<AdaptyProfile?> callGetProfile() async {
    try {
      final result = await adapty.getProfile();
      return result;
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccurred?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccurred?.call(e);
    }

    return null;
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
    try {
      await adapty.updateProfile(params);
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccurred?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccurred?.call(e);
    }
  }

  Future<AdaptyPaywall?> callGetPaywall(
    String paywallId,
    String? locale,
    AdaptyPaywallFetchPolicy fetchPolicy,
  ) async {
    try {
      final result = await adapty.getPaywall(
        placementId: paywallId,
        locale: locale,
        fetchPolicy: fetchPolicy,
        loadTimeout: const Duration(seconds: 5),
      );
      return result;
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccurred?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccurred?.call(e);
    }

    return null;
  }

  Future<List<AdaptyPaywallProduct>?> callGetPaywallProducts(AdaptyPaywall paywall) async {
    try {
      final result = await adapty.getPaywallProducts(paywall: paywall);
      return result;
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccurred?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccurred?.call(e);
    }

    return null;
  }

  Future<Map<String, AdaptyEligibility>?> callGetProductsIntroductoryOfferEligibility(List<AdaptyPaywallProduct> products) async {
    try {
      final result = await adapty.getProductsIntroductoryOfferEligibility(products: products);
      return result;
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccurred?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccurred?.call(e);
    }

    return null;
  }

  Future<AdaptyProfile?> callMakePurchase(AdaptyPaywallProduct product) async {
    try {
      final result = await adapty.makePurchase(product: product);
      return result;
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccurred?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccurred?.call(e);
    }

    return null;
  }

  Future<AdaptyProfile?> callRestorePurchases() async {
    try {
      final result = await adapty.restorePurchases();
      return result;
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccurred?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccurred?.call(e);
    }

    return null;
  }

  Future<void> callUpdateAttribution(Map<dynamic, dynamic> attribution, AdaptyAttributionSource source, String networkUserId) async {
    try {
      await adapty.updateAttribution(attribution, source: source, networkUserId: networkUserId);
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccurred?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccurred?.call(e);
    }
  }

  Future<void> callLogShowPaywall(AdaptyPaywall paywall) async {
    try {
      await adapty.logShowPaywall(paywall: paywall);
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccurred?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccurred?.call(e);
    }
  }

  Future<void> callLogShowOnboarding(String? name, String? screenName, int screenOrder) async {
    try {
      await adapty.logShowOnboarding(name: name, screenName: screenName, screenOrder: screenOrder);
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccurred?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccurred?.call(e);
    }
  }

  Future<void> callLogout() async {
    try {
      await adapty.logout();
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccurred?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccurred?.call(e);
    }
  }
}

import 'dart:async' show Future;
import 'dart:io' show Platform;
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

class PurchasesObserver {
  void Function(AdaptyError)? onAdaptyErrorOccured;
  void Function(Object)? onUnknownErrorOccured;

  final adapty = Adapty();

  static final PurchasesObserver _instance = PurchasesObserver._internal();

  factory PurchasesObserver() {
    return _instance;
  }

  PurchasesObserver._internal();

  Future<void> initialize() async {
    try {
      adapty.setLogLevel(AdaptyLogLevel.verbose);
      adapty.activate();
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
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccured?.call(e);
    }
  }

  Future<AdaptyProfile?> callGetProfile() async {
    try {
      final result = await adapty.getProfile();
      return result;
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccured?.call(e);
    }

    return null;
  }

  Future<void> callIdentifyUser(String customerUserId) async {
    try {
      await adapty.identify(customerUserId);
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccured?.call(e);
    }
  }

  Future<void> callUpdateProfile(AdaptyProfileParameters params) async {
    try {
      await adapty.updateProfile(params);
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccured?.call(e);
    }
  }

  Future<AdaptyPaywall?> callGetPaywall(String paywallId, String? locale) async {
    try {
      final result = await adapty.getPaywall(id: paywallId, locale: locale);
      return result;
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccured?.call(e);
    }

    return null;
  }

  Future<List<AdaptyPaywallProduct>?> callGetPaywallProducts(AdaptyPaywall paywall, AdaptyIOSProductsFetchPolicy fetchPolicy) async {
    try {
      final result = await adapty.getPaywallProducts(paywall: paywall, fetchPolicy: fetchPolicy);
      return result;
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccured?.call(e);
    }

    return null;
  }

  Future<AdaptyProfile?> callMakePurchase(AdaptyPaywallProduct product) async {
    try {
      final result = await adapty.makePurchase(product: product);
      return result;
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccured?.call(e);
    }

    return null;
  }

  Future<AdaptyProfile?> callRestorePurchases() async {
    try {
      final result = await adapty.restorePurchases();
      return result;
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccured?.call(e);
    }

    return null;
  }

  Future<void> callUpdateAttribution(Map<dynamic, dynamic> attribution, AdaptyAttributionSource source, String networkUserId) async {
    try {
      await adapty.updateAttribution(attribution, source: source, networkUserId: networkUserId);
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccured?.call(e);
    }
  }

  Future<void> callLogShowPaywall(AdaptyPaywall paywall) async {
    try {
      await adapty.logShowPaywall(paywall: paywall);
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccured?.call(e);
    }
  }

  Future<void> callLogShowOnboarding(String? name, String? screenName, int screenOrder) async {
    try {
      await adapty.logShowOnboarding(name: name, screenName: screenName, screenOrder: screenOrder);
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccured?.call(e);
    }
  }

  Future<void> callLogout() async {
    try {
      await adapty.logout();
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      onUnknownErrorOccured?.call(e);
    }
  }
}

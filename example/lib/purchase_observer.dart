import 'dart:async' show Future;
import 'dart:io' show Platform;
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:adapty_flutter_example/Helpers/logger.dart';

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
    Logger.logExampleMessage('--> Adapty.setFallbackPaywalls()');

    final filePath = Platform.isIOS ? 'assets/fallback_ios.json' : 'assets/fallback_android.json';
    final jsonString = await rootBundle.loadString(filePath);

    try {
      await adapty.setFallbackPaywalls(jsonString);
      Logger.logExampleMessage('<-- Adapty.setFallbackPaywalls()');
    } on AdaptyError catch (adaptyError) {
      Logger.logExampleMessage('<-- Adapty.setFallbackPaywalls() Adapty Error: $adaptyError');
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      Logger.logExampleMessage('<-- Adapty.setFallbackPaywalls() Error: $e');
      onUnknownErrorOccured?.call(e);
    }
  }

  Future<AdaptyProfile?> callGetProfile() async {
    Logger.logExampleMessage('--> Adapty.getProfile()');

    try {
      final result = await adapty.getProfile();
      Logger.logExampleMessage('<-- Adapty.getProfile()');
      return result;
    } on AdaptyError catch (adaptyError) {
      Logger.logExampleMessage('<-- Adapty.getProfile() Adapty Error: $adaptyError');
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      Logger.logExampleMessage('<-- Adapty.getProfile() Error: $e');
      onUnknownErrorOccured?.call(e);
    }

    return null;
  }

  Future<void> callIdentifyUser(String customerUserId) async {
    Logger.logExampleMessage('--> Adapty.identify()');

    try {
      await adapty.identify(customerUserId);
      Logger.logExampleMessage('<-- Adapty.identify()');
    } on AdaptyError catch (adaptyError) {
      Logger.logExampleMessage('<-- Adapty.identify() Adapty Error: $adaptyError');
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      Logger.logExampleMessage('<-- Adapty.identify() Error: $e');
      onUnknownErrorOccured?.call(e);
    }
  }

  Future<void> callUpdateProfile(AdaptyProfileParameters params) async {
    Logger.logExampleMessage('--> Adapty.updateProfile()');

    try {
      await adapty.updateProfile(params);
      Logger.logExampleMessage('<-- Adapty.updateProfile()');
    } on AdaptyError catch (adaptyError) {
      Logger.logExampleMessage('<-- Adapty.updateProfile() Adapty Error: $adaptyError');
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      Logger.logExampleMessage('<-- Adapty.updateProfile() Error: $e');
      onUnknownErrorOccured?.call(e);
    }
  }

  Future<AdaptyPaywall?> callGetPaywall(String paywallId) async {
    Logger.logExampleMessage('--> Adapty.getPaywall()');

    try {
      final result = await adapty.getPaywall(id: paywallId);
      Logger.logExampleMessage('<-- Adapty.getPaywall()');
      return result;
    } on AdaptyError catch (adaptyError) {
      Logger.logExampleMessage('<-- Adapty.getPaywall() Adapty Error: $adaptyError');
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      Logger.logExampleMessage('<-- Adapty.getPaywall() Error: $e');
      onUnknownErrorOccured?.call(e);
    }

    return null;
  }

  Future<List<AdaptyPaywallProduct>?> callGetPaywallProducts(AdaptyPaywall paywall, AdaptyIOSProductsFetchPolicy fetchPolicy) async {
    Logger.logExampleMessage('--> Adapty.getPaywallProducts()');

    try {
      final result = await adapty.getPaywallProducts(paywall: paywall, fetchPolicy: fetchPolicy);
      Logger.logExampleMessage('<-- Adapty.getPaywallProducts()');
      return result;
    } on AdaptyError catch (adaptyError) {
      Logger.logExampleMessage('<-- Adapty.getPaywallProducts() Adapty Error: $adaptyError');
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      Logger.logExampleMessage('<-- Adapty.getPaywallProducts() Error: $e');
      onUnknownErrorOccured?.call(e);
    }

    return null;
  }

  Future<AdaptyProfile?> callMakePurchase(AdaptyPaywallProduct product) async {
    Logger.logExampleMessage('--> Adapty.makePurchase()');

    try {
      final result = await adapty.makePurchase(product: product);
      Logger.logExampleMessage('<-- Adapty.makePurchase()');
      return result;
    } on AdaptyError catch (adaptyError) {
      Logger.logExampleMessage('<-- Adapty.makePurchase() Adapty Error: $adaptyError');
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      Logger.logExampleMessage('<-- Adapty.makePurchase() Error: $e');
      onUnknownErrorOccured?.call(e);
    }

    return null;
  }

  Future<AdaptyProfile?> callRestorePurchases() async {
    Logger.logExampleMessage('--> Adapty.restorePurchases()');

    try {
      final result = await adapty.restorePurchases();
      Logger.logExampleMessage('<-- Adapty.restorePurchases()');
      return result;
    } on AdaptyError catch (adaptyError) {
      Logger.logExampleMessage('<-- Adapty.restorePurchases() Adapty Error: $adaptyError');
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      Logger.logExampleMessage('<-- Adapty.restorePurchases() Error: $e');
      onUnknownErrorOccured?.call(e);
    }

    return null;
  }

  Future<void> callUpdateAttribution(Map<dynamic, dynamic> attribution, AdaptyAttributionSource source, String networkUserId) async {
    Logger.logExampleMessage('--> Adapty.updateAttribution()');

    try {
      await adapty.updateAttribution(attribution, source: source, networkUserId: networkUserId);
      Logger.logExampleMessage('<-- Adapty.updateAttribution()');
    } on AdaptyError catch (adaptyError) {
      Logger.logExampleMessage('<-- Adapty.updateAttribution() Adapty Error: $adaptyError');
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      Logger.logExampleMessage('<-- Adapty.updateAttribution() Error: $e');
      onUnknownErrorOccured?.call(e);
    }
  }

  Future<void> callLogShowPaywall(AdaptyPaywall paywall) async {
    Logger.logExampleMessage('--> Adapty.logShowPaywall()');

    try {
      await adapty.logShowPaywall(paywall: paywall);
      Logger.logExampleMessage('<-- Adapty.logShowPaywall()');
    } on AdaptyError catch (adaptyError) {
      Logger.logExampleMessage('<-- Adapty.logShowPaywall() Adapty Error: $adaptyError');
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      Logger.logExampleMessage('<-- Adapty.logShowPaywall() Error: $e');
      onUnknownErrorOccured?.call(e);
    }
  }

  Future<void> callLogShowOnboarding(String? name, String? screenName, int screenOrder) async {
    Logger.logExampleMessage('--> Adapty.logShowOnboarding()');

    try {
      await adapty.logShowOnboarding(name: name, screenName: screenName, screenOrder: screenOrder);
      Logger.logExampleMessage('<-- Adapty.logShowOnboarding()');
    } on AdaptyError catch (adaptyError) {
      Logger.logExampleMessage('<-- Adapty.logShowOnboarding() Adapty Error: $adaptyError');
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      Logger.logExampleMessage('<-- Adapty.logShowOnboarding() Error: $e');
      onUnknownErrorOccured?.call(e);
    }
  }

  Future<void> callLogout() async {
    Logger.logExampleMessage('--> Adapty.logout()');

    try {
      await adapty.logout();
      Logger.logExampleMessage('<-- Adapty.logout()');
    } on AdaptyError catch (adaptyError) {
      Logger.logExampleMessage('<-- Adapty.logout() Adapty Error: $adaptyError');
      onAdaptyErrorOccured?.call(adaptyError);
    } catch (e) {
      Logger.logExampleMessage('<-- Adapty.logout() Error: $e');
      onUnknownErrorOccured?.call(e);
    }
  }
}

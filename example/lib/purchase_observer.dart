import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter_example/Helpers/logger.dart';

class PurchasesObserver {
  void Function(AdaptyError)? onAdaptyErrorOccured;
  void Function(Object)? onUnknownErrorOccured;

  static final PurchasesObserver _instance = PurchasesObserver._internal();

  factory PurchasesObserver() {
    return _instance;
  }

  PurchasesObserver._internal();

  Future<AdaptyProfile?> callGetProfile() async {
    Logger.logExampleMessage('Calling Adapty.getProfile()');

    try {
      return await Adapty.getProfile();
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccured?.call(adaptyError);
      Logger.logExampleMessage('Adapty.getProfile()  Adapty Error: $adaptyError');
    } catch (e) {
      onUnknownErrorOccured?.call(e);
      Logger.logExampleMessage('Adapty.getProfile() Error: $e');
    }

    return null;
  }

  Future<void> callIdentifyUser(String customerUserId) async {
    Logger.logExampleMessage('Calling Adapty.identify()');

    try {
      await Adapty.identify(customerUserId);
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccured?.call(adaptyError);
      Logger.logExampleMessage('Adapty.identify()  Adapty Error: $adaptyError');
    } catch (e) {
      onUnknownErrorOccured?.call(e);
      Logger.logExampleMessage('Adapty.identify() Error: $e');
    }
  }

  Future<void> callUpdateProfile(AdaptyProfileParameters params) async {
    Logger.logExampleMessage('Calling Adapty.updateProfile()');

    try {
      await Adapty.updateProfile(params);
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccured?.call(adaptyError);
      Logger.logExampleMessage('Adapty.updateProfile()  Adapty Error: $adaptyError');
    } catch (e) {
      onUnknownErrorOccured?.call(e);
      Logger.logExampleMessage('Adapty.updateProfile() Error: $e');
    }
  }

  Future<AdaptyPaywall?> callGetPaywall(String paywallId) async {
    Logger.logExampleMessage('Calling Adapty.getPaywall()');

    try {
      return await Adapty.getPaywall(id: paywallId);
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccured?.call(adaptyError);
      Logger.logExampleMessage('Adapty.getPaywall()  Adapty Error: $adaptyError');
    } catch (e) {
      onUnknownErrorOccured?.call(e);
      Logger.logExampleMessage('Adapty.getPaywall() Error: $e');
    }

    return null;
  }

  Future<List<AdaptyPaywallProduct>?> callGetPaywallProducts(AdaptyPaywall paywall) async {
    Logger.logExampleMessage('Calling Adapty.getPaywallProducts()');

    try {
      return await Adapty.getPaywallProducts(paywall: paywall);
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccured?.call(adaptyError);
      Logger.logExampleMessage('Adapty.getPaywallProducts()  Adapty Error: $adaptyError');
    } catch (e) {
      onUnknownErrorOccured?.call(e);
      Logger.logExampleMessage('Adapty.getPaywallProducts() Error: $e');
    }

    return null;
  }

  Future<AdaptyProfile?> callMakePurchase(AdaptyPaywallProduct product) async {
    Logger.logExampleMessage('Calling Adapty.makePurchase()');

    try {
      return await Adapty.makePurchase(product: product);
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccured?.call(adaptyError);
      Logger.logExampleMessage('Adapty.makePurchase()  Adapty Error: $adaptyError');
    } catch (e) {
      onUnknownErrorOccured?.call(e);
      Logger.logExampleMessage('Adapty.makePurchase() Error: $e');
    }

    return null;
  }

  Future<AdaptyProfile?> callRestorePurchases() async {
    Logger.logExampleMessage('Calling Adapty.restorePurchases()');

    try {
      return await Adapty.restorePurchases();
    } on AdaptyError catch (adaptyError) {
      onAdaptyErrorOccured?.call(adaptyError);
      Logger.logExampleMessage('Adapty.restorePurchases()  Adapty Error: $adaptyError');
    } catch (e) {
      onUnknownErrorOccured?.call(e);
      Logger.logExampleMessage('Adapty.restorePurchases() Error: $e');
    }

    return null;
  }
}

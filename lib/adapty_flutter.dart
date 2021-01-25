import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:adapty_flutter/models/adapty_error.dart';
import 'package:adapty_flutter/models/adapty_paywall.dart';
import 'package:adapty_flutter/models/adapty_profile.dart';
import 'package:adapty_flutter/models/adapty_purchaser_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'constants/arguments_names.dart';
import 'constants/method_names.dart';
import 'models/adapty_enums.dart';
import 'models/adapty_product.dart';
import 'models/adapty_promo.dart';
import 'results/adapty_result.dart';
import 'results/get_paywalls_result.dart';
import 'results/make_purchase_result.dart';
import 'results/restore_purchases_result.dart';

class Adapty {
  static const String _channelName = 'flutter.adapty.com/adapty';
  static const MethodChannel _channel = const MethodChannel(_channelName);

  static StreamController<String> _deferredPurchasesController;
  static StreamController<GetPaywallsResult> _getPaywallsResultController;
  static StreamController<AdaptyPurchaserInfo> _purchaserInfoUpdateController;
  static StreamController<AdaptyPromo> _promosReceiveController;

  static Stream<String> get deferredPurchasesStream => _deferredPurchasesController.stream;
  static Stream<GetPaywallsResult> get getPaywallsResultStream => _getPaywallsResultController.stream;
  static Stream<AdaptyPurchaserInfo> get purchaserInfoUpdateStream => _purchaserInfoUpdateController.stream;
  static Stream<AdaptyPromo> get promosReceiveStream => _promosReceiveController.stream;

  static Future<void> setLogLevel(AdaptyLogLevel value) {
    return _invokeMethodHandlingErrors(Method.setLogLevel, {Argument.value: value.index});
  }

  static Future<AdaptyLogLevel> getLogLevel() async {
    if (Platform.isAndroid) return AdaptyLogLevel.none;

    final index = await _invokeMethodHandlingErrors(Method.getLogLevel);
    return AdaptyLogLevel.values[index];
  }

  static Future<bool> activate(String apiKey, {bool observerMode, String customerUserId}) async {
    final result = await _invokeMethodHandlingErrors<bool>(Method.activate, {
      Argument.apiKey: apiKey,
      if (observerMode != null) Argument.observerMode: observerMode,
      if (customerUserId != null) Argument.customerUserId: customerUserId,
    });
    if (result) _initStreams();
    return result;
  }

  static Future<bool> identify(String customerUserId) {
    return _invokeMethodHandlingErrors<bool>(Method.identify, {
      Argument.customerUserId: customerUserId,
    });
  }

  static Future<GetPaywallsResult> getPaywalls({bool forceUpdate = false}) async {
    final result = await _invokeMethodHandlingErrors<String>(Method.getPaywalls, {
      Argument.forceUpdate: forceUpdate,
    });
    return GetPaywallsResult.fromMap(json.decode(result));
  }

  static Future<AdaptyPurchaserInfo> getPurchaserInfo({bool forceUpdate = false}) async {
    final result = await _invokeMethodHandlingErrors<String>(Method.getPurchaserInfo, {
      Argument.forceUpdate: forceUpdate,
    });
    return AdaptyPurchaserInfo.fromMap(json.decode(result));
  }

  static Future<bool> updateProfile(AdaptyProfileParameterBuilder builder) {
    return _invokeMethodHandlingErrors<bool>(Method.updateProfile, {
      Argument.params: builder.map,
    });
  }

  static Future<MakePurchaseResult> makePurchase(AdaptyProduct product) async {
    final result = await _invokeMethodHandlingErrors<String>(Method.makePurchase, {
      Argument.productId: product.vendorProductId,
      if (product.variationId != null) Argument.variationId: product.variationId,
    });
    return MakePurchaseResult.fromJson(json.decode(result));
  }

  static Future<RestorePurchasesResult> restorePurchases() async {
    final result = await _invokeMethodHandlingErrors<String>(Method.restorePurchases);
    return RestorePurchasesResult.fromJson(json.decode(result));
  }

  static Future<bool> updateAttribution(Map attribution, {@required AdaptyAttributionNetwork source, String networkUserId}) {
    return _invokeMethodHandlingErrors<bool>(Method.updateAttribution, {
      Argument.attribution: attribution,
      Argument.source: source.stringValue(),
      if (networkUserId != null) Argument.networkUserId: networkUserId,
    });
  }

  static Future<void> logShowPaywall({@required AdaptyPaywall paywall}) {
    return _invokeMethodHandlingErrors<void>(Method.logShowPaywall, {
      Argument.variationId: paywall.variationId,
    });
  }

  static Future<bool> logout() {
    return _invokeMethodHandlingErrors<bool>(Method.logout);
  }

  // ––––––– IOS ONLY METHODS –––––––

  static Future<void> setApnsToken(String token) {
    if (!Platform.isIOS) return null;
    return _invokeMethodHandlingErrors<void>(Method.setApnsToken, {Argument.value: token});
  }

  static Future<void> handlePushNotification(Map userInfo) {
    if (!Platform.isIOS) return null;
    return _invokeMethodHandlingErrors<void>(Method.handlePushNotification, {Argument.userInfo: userInfo});
  }

  static Future<void> setFallbackPaywalls(String paywalls) {
    if (!Platform.isIOS) return null;
    return _invokeMethodHandlingErrors<void>(Method.setFallbackPaywalls, {Argument.paywalls: paywalls});
  }

  static Future<AdaptyResult> validateReceipt(String receipt) async {
    if (!Platform.isIOS) return null;

    try {
      await _invokeMethodHandlingErrors(Method.validateReceipt, {
        Argument.receipt: receipt,
      });
      return AdaptyResult();
    } on PlatformException catch (e) {
      log("Adapty validate receipt error: ${e.message}");
      return AdaptyResult(errorCode: e.code, errorMessage: e.message);
    }
  }

  static Future<AdaptyPromo> getPromo() async {
    if (!Platform.isIOS) return null;

    final String result = await _invokeMethodHandlingErrors(Method.getPromo);
    if (result != null) {
      return AdaptyPromo.fromJson(jsonDecode(result));
    }
    return null;
  }

  static Future<MakePurchaseResult> makeDeferredPurchase(String productId) async {
    if (!Platform.isIOS) return null;

    final String result = await _invokeMethodHandlingErrors(Method.makeDeferredPurchase, {
      Argument.productId: productId,
    });
    return MakePurchaseResult.fromJson(json.decode(result));
  }

  // ––––––– ANDROID ONLY METHODS –––––––

  static Future<bool> newPushToken(String token) async {
    if (!Platform.isAndroid) return null;

    final bool result = await _invokeMethodHandlingErrors(Method.newPushToken, {Argument.pushToken: token});
    return result;
  }

  static Future<bool> pushReceived(Map<String, String> message) async {
    if (!Platform.isAndroid) return null;

    final bool result = await _invokeMethodHandlingErrors(Method.pushReceived, {Argument.pushMessage: message});
    return result;
  }

  // ––––––– INTERNAL –––––––

  static Future<T> _invokeMethodHandlingErrors<T>(String method, [dynamic arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw e.details != null ? AdaptyError.fromMap(json.decode(e.details)) : e;
    }
  }

  static void _initStreams() {
    _deferredPurchasesController = StreamController.broadcast();
    _getPaywallsResultController = StreamController.broadcast();
    _purchaserInfoUpdateController = StreamController.broadcast();
    _promosReceiveController = StreamController.broadcast();

    _channel.setMethodCallHandler((call) {
      switch (call.method) {
        case Method.deferredPurchaseProduct:
          var productIdentifier = call.arguments as String;
          _deferredPurchasesController.add(productIdentifier);
          return;
        case Method.getPaywallsResult:
          var result = call.arguments as String;
          _getPaywallsResultController.add(GetPaywallsResult.fromMap(json.decode(result)));
          return;
        case Method.purchaserInfoUpdate:
          var result = call.arguments as String;
          _purchaserInfoUpdateController.add(AdaptyPurchaserInfo.fromMap(json.decode(result)));
          return;
        case Method.promoReceived:
          var result = call.arguments as String;
          _promosReceiveController.add(AdaptyPromo.fromJson(json.decode(result)));
          return;
        default:
          return;
      }
    });
  }
}

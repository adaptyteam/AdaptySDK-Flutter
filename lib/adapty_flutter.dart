import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:adapty_flutter/constants/adapty_constants.dart';
import 'package:adapty_flutter/models/adapty_result.dart';
import 'package:adapty_flutter/models/get_active_purchases_result.dart';
import 'package:adapty_flutter/models/get_paywalls_result.dart';
import 'package:adapty_flutter/models/make_purchase_result.dart';
import 'package:adapty_flutter/models/updated_purchaser_info.dart';
import 'package:flutter/services.dart';

class AdaptyFlutter {
  static const MethodChannel _channel =
      const MethodChannel(AdaptyConstants.channelName);

  static StreamController<String> _deferredPurchasesController;

  static Stream<String> get deferredPurchasesStream =>
      _deferredPurchasesController.stream;

  static StreamController<GetPaywallsResult> _getPaywallsResultController;

  static Stream<GetPaywallsResult> get getPaywallsResultStream =>
      _getPaywallsResultController.stream;

  static StreamController<GetActivePurchasesResult>
      _getActivePurchasesResultController;

  static Stream<GetActivePurchasesResult> get getActivePurchasesResultStream =>
      _getActivePurchasesResultController.stream;

  static StreamController<UpdatedPurchaserInfo> _purchaserInfoUpdateController;

  static Stream<UpdatedPurchaserInfo> get purchaserInfoUpdateStream =>
      _purchaserInfoUpdateController.stream;

  static Future<bool> activate(String appKey, {String customerUserId}) async {
    final bool result = await _channel.invokeMethod(AdaptyConstants.activate, {
      AdaptyConstants.appKey: appKey,
      AdaptyConstants.customerUserId: customerUserId
    });
    if (result) _initStreams();
    return result;
  }

  static Future<bool> identify(String customerUserId) async {
    try {
      final bool result = await _channel.invokeMethod(AdaptyConstants.identify,
          {AdaptyConstants.customerUserId: customerUserId});
      return result;
    } on PlatformException catch (e) {
      log("Adapty identify error: ${e.message}");
      return false;
    }
  }

  static Future<GetPaywallsResult> getPaywalls() async {
    try {
      final String result =
          await _channel.invokeMethod(AdaptyConstants.getPaywalls);
      return GetPaywallsResult.fromJson(json.decode(result));
    } on PlatformException catch (e) {
      log("Adapty get paywalls error: ${e.message}");
      return GetPaywallsResult([], [],
          errorCode: e.code, errorMessage: e.message);
    }
  }

  static Future<MakePurchaseResult> makePurchase(String productId) async {
    try {
      final String result = await _channel.invokeMethod(
          AdaptyConstants.makePurchase, {AdaptyConstants.productId: productId});
      return MakePurchaseResult.fromJson(json.decode(result));
    } on PlatformException catch (e) {
      log("Adapty make purchase error: ${e.message}");
      return MakePurchaseResult(errorCode: e.code, errorMessage: e.message);
    }
  }

  // Android
  static Future<AdaptyResult> validatePurchase(
      String purchaseType, String productId, String purchaseToken) async {
    try {
      await _channel.invokeMethod(AdaptyConstants.validatePurchase, {
        AdaptyConstants.purchaseType: purchaseType,
        AdaptyConstants.productId: productId,
        AdaptyConstants.purchaseToken: purchaseToken
      });
      return AdaptyResult();
    } on PlatformException catch (e) {
      log("Adapty validate purchase error: ${e.message}");
      return AdaptyResult(errorCode: e.code, errorMessage: e.message);
    }
  }

  // iOS
  static Future<AdaptyResult> validateReceipt(String receipt) async {
    try {
      await _channel.invokeMethod(
          AdaptyConstants.validateReceipt, {AdaptyConstants.receipt: receipt});
      return AdaptyResult();
    } on PlatformException catch (e) {
      log("Adapty validate receipt error: ${e.message}");
      return AdaptyResult(errorCode: e.code, errorMessage: e.message);
    }
  }

  static Future<AdaptyResult> restorePurchases() async {
    try {
      await _channel.invokeMethod(AdaptyConstants.restorePurchases);
      return AdaptyResult();
    } on PlatformException catch (e) {
      log("Adapty restore purchases error: ${e.message}");
      return AdaptyResult(errorCode: e.code, errorMessage: e.message);
    }
  }

  static Future<bool> getPurchaserInfo() async {
    try {
      final bool result =
          await _channel.invokeMethod(AdaptyConstants.getPurchaserInfo);
      return result;
    } on PlatformException catch (e) {
      log("Adapty get purchaser info error: ${e.message}");
      return false;
    }
  }

  static Future<GetActivePurchasesResult> getActivePurchases(
      String paidAccessLevel) async {
    try {
      final String result = await _channel.invokeMethod(
          AdaptyConstants.getActivePurchases,
          {AdaptyConstants.paidAccessLevel: paidAccessLevel});
      return GetActivePurchasesResult.fromJson(json.decode(result));
    } on PlatformException catch (e) {
      log("Adapty get active purchases error: ${e.message}");
      return GetActivePurchasesResult(false, [],
          errorCode: e.code, errorMessage: e.message);
    }
  }

  static Future<bool> updateAttribution(Map attribution, String source,
      {String userId}) async {
    final bool result =
        await _channel.invokeMethod(AdaptyConstants.updateAttribution, {
      AdaptyConstants.attribution: attribution,
      AdaptyConstants.source: source,
      AdaptyConstants.userId: userId
    });
    return result;
  }

  static Future<MakePurchaseResult> makeDeferredPurchase(
      String productId) async {
    try {
      final String result = await _channel.invokeMethod(
          AdaptyConstants.makeDeferredPurchase,
          {AdaptyConstants.productId: productId});
      return MakePurchaseResult.fromJson(json.decode(result));
    } on PlatformException catch (e) {
      log("Adapty make deferred purchase error: ${e.message}");
      return MakePurchaseResult(errorCode: e.code, errorMessage: e.message);
    }
  }

  static Future<bool> logout() async {
    try {
      final bool result = await _channel.invokeMethod(AdaptyConstants.logout);
      return result;
    } on PlatformException catch (e) {
      log("Adapty logout error: ${e.message}");
      return false;
    }
  }

  static void _initStreams() {
    _deferredPurchasesController = StreamController.broadcast();
    _getPaywallsResultController = StreamController.broadcast();
    _getActivePurchasesResultController = StreamController.broadcast();
    _purchaserInfoUpdateController = StreamController.broadcast();

    _channel.setMethodCallHandler((call) {
      switch (call.method) {
        case AdaptyConstants.deferredPurchaseProduct:
          var productIdentifier = call.arguments as String;
          _deferredPurchasesController.add(productIdentifier);
          return;
        case AdaptyConstants.getPaywallsResult:
          var result = call.arguments as String;
          _getPaywallsResultController
              .add(GetPaywallsResult.fromJson(json.decode(result)));
          return;
        case AdaptyConstants.getActivePurchasesResult:
          var result = call.arguments as String;
          _getActivePurchasesResultController
              .add(GetActivePurchasesResult.fromJson(json.decode(result)));
          return;
        case AdaptyConstants.purchaserInfoUpdate:
          var result = call.arguments as String;
          _purchaserInfoUpdateController
              .add(UpdatedPurchaserInfo.fromJson(json.decode(result)));
          return;
        default:
          return;
      }
    });
  }
}

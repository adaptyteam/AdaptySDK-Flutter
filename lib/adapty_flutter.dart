import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:adapty_flutter/models/adapty_result.dart';
import 'package:adapty_flutter/models/get_active_purchases_result.dart';
import 'package:adapty_flutter/models/get_paywalls_result.dart';
import 'package:adapty_flutter/models/make_purchase_result.dart';
import 'package:flutter/services.dart';

class AdaptyFlutter {
  static const MethodChannel _channel =
  const MethodChannel('flutter.adapty.com/adapty');

  static StreamController<String> _deferredPurchasesController;

  static Stream<String> get deferredPurchasesStream =>
      _deferredPurchasesController.stream;

  static Future<bool> activate(String appKey, {String customerUserId}) async {
    final bool result = await _channel.invokeMethod(
        'activate', {'app_key': appKey, 'customer_user_id': customerUserId});
    return result;
  }

  static Future<GetPaywallsResult> getPaywalls() async {
    try {
      final String result = await _channel.invokeMethod('get_paywalls');
      return GetPaywallsResult.fromJson(json.decode(result));
    } on PlatformException catch (e) {
      log("Adapty get paywalls error: ${e.message}");
      return GetPaywallsResult([], [],
          errorCode: e.code, errorMessage: e.message);
    }
  }

  static Future<MakePurchaseResult> makePurchase(String productId) async {
    try {
      final String result = await _channel
          .invokeMethod('make_purchase', {'product_id': productId});
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
      await _channel.invokeMethod('validate_purchase', {
        'purchase_type': purchaseType,
        'product_id': productId,
        'purchase_token': purchaseToken
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
      await _channel.invokeMethod('validate_receipt', {'receipt': receipt});
      return AdaptyResult();
    } on PlatformException catch (e) {
      log("Adapty validate receipt error: ${e.message}");
      return AdaptyResult(errorCode: e.code, errorMessage: e.message);
    }
  }

  static Future<AdaptyResult> restorePurchases() async {
    try {
      await _channel.invokeMethod('restore_purchases');
      return AdaptyResult();
    } on PlatformException catch (e) {
      log("Adapty restore purchases error: ${e.message}");
      return AdaptyResult(errorCode: e.code, errorMessage: e.message);
    }
  }

  static Future<bool> getPurchaserInfo() async {
    try {
      final bool result = await _channel.invokeMethod('get_purchaser_info');
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
          'get_active_purchases', {'paid_access_level': paidAccessLevel});
      return GetActivePurchasesResult.fromJson(json.decode(result));
    } on PlatformException catch (e) {
      log("Adapty get active purchases error: ${e.message}");
      return GetActivePurchasesResult(false, [],
          errorCode: e.code, errorMessage: e.message);
    }
  }

  static Future<bool> updateAttribution(Map attribution, String source,
      {String userId}) async {
    final bool result = await _channel.invokeMethod('update_attribution',
        {'attribution': attribution, 'source': source, 'user_id': userId});
    return result;
  }

  static void initDeferredPurchases() {
    _deferredPurchasesController = StreamController.broadcast();
    _channel.setMethodCallHandler((call) {
      switch (call.method) {
        case 'deferred_purchase_product':
          var productIdentifier = call.arguments as String;
          _deferredPurchasesController.add(productIdentifier);
          return;
        default:
          return;
      }
    });
  }

  static Future<MakePurchaseResult> makeDeferredPurchase(String productId) async {
    try {
      final String result = await _channel
          .invokeMethod('make_deferred_purchase', {'product_id': productId});
      return MakePurchaseResult.fromJson(json.decode(result));
    } on PlatformException catch (e) {
      log("Adapty make deferred purchase error: ${e.message}");
      return MakePurchaseResult(errorCode: e.code, errorMessage: e.message);
    }
  }
}

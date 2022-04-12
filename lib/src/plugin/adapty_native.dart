import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../constants/arguments_names.dart';
import '../constants/method_names.dart';
import '../models/adapty_android_subscription_update_params.dart';
import '../models/adapty_enums.dart';
import '../models/adapty_error.dart';
import '../models/adapty_paywall.dart';
import '../models/adapty_product.dart';
import '../models/adapty_profile.dart';
import '../models/adapty_promo.dart';
import '../models/adapty_purchaser_info.dart';
import '../results/get_paywalls_result.dart';
import '../results/make_purchase_result.dart';
import '../results/restore_purchases_result.dart';
import '../results/visual_paywall_purchase_fail_result.dart';
import 'adapty_plugin.dart';

class AdaptyNative implements AdaptyPlugin {
  static const String _channelName = 'flutter.adapty.com/adapty';
  static const MethodChannel _channel = MethodChannel(_channelName);

  AdaptyNative();

  final StreamController<String> _deferredPurchasesController =
      StreamController.broadcast();
  final StreamController<GetPaywallsResult> _getPaywallsResultController =
      StreamController.broadcast();
  final StreamController<AdaptyPurchaserInfo> _purchaserInfoUpdateController =
      StreamController.broadcast();
  final StreamController<AdaptyPromo> _promosReceiveController =
      StreamController.broadcast();

  @override
  Stream<String> get deferredPurchasesStream =>
      _deferredPurchasesController.stream;
  @override
  Stream<GetPaywallsResult> get getPaywallsResultStream =>
      _getPaywallsResultController.stream;
  @override
  Stream<AdaptyPurchaserInfo> get purchaserInfoUpdateStream =>
      _purchaserInfoUpdateController.stream;
  @override
  Stream<AdaptyPromo> get promosReceiveStream =>
      _promosReceiveController.stream;

  @override
  void activate() {
    _channel.setMethodCallHandler(_handleIncomingMethodCall);
  }

  @override
  Future<void> setLogLevel(AdaptyLogLevel value) {
    return _invokeMethodHandlingErrors(
      Method.setLogLevel,
      {Argument.value: value.index},
    );
  }

  @override
  Future<AdaptyLogLevel> getLogLevel() async {
    if (Platform.isAndroid) return AdaptyLogLevel.none;

    final index = await _invokeMethodHandlingErrors(Method.getLogLevel);
    return AdaptyLogLevel.values[index];
  }

  @override
  Future<bool> identify(String customerUserId) async {
    final result = await _invokeMethodHandlingErrors<bool>(
      Method.identify,
      {Argument.customerUserId: customerUserId},
    );
    return result ?? false;
  }

  @override
  Future<GetPaywallsResult> getPaywalls({bool forceUpdate = false}) async {
    final result = (await _invokeMethodHandlingErrors<String>(
      Method.getPaywalls,
      {Argument.forceUpdate: forceUpdate},
    )) as String;
    return GetPaywallsResult.fromMap(json.decode(result));
  }

  @override
  Future<AdaptyPurchaserInfo> getPurchaserInfo({
    bool forceUpdate = false,
  }) async {
    final result = (await _invokeMethodHandlingErrors<String>(
      Method.getPurchaserInfo,
      {Argument.forceUpdate: forceUpdate},
    )) as String;
    return AdaptyPurchaserInfo.fromMap(json.decode(result));
  }

  @override
  Future<bool> updateProfile(AdaptyProfileParameterBuilder builder) async {
    final result = await _invokeMethodHandlingErrors<bool>(
      Method.updateProfile,
      {Argument.params: builder.build()},
    );
    return result ?? false;
  }

  @override
  Future<MakePurchaseResult> makePurchase(
    AdaptyProduct product, {
    String? offerId,
    AdaptyAndroidSubscriptionUpdateParams? subscriptionUpdateParams,
  }) async {
    final result = (await _invokeMethodHandlingErrors<String>(
      Method.makePurchase,
      {
        Argument.productId: product.vendorProductId,
        if (offerId != null) Argument.offerId: offerId,
        if (product.variationId != null)
          Argument.variationId: product.variationId,
        if (subscriptionUpdateParams != null)
          Argument.params: subscriptionUpdateParams.toMap()
      },
    )) as String;
    return MakePurchaseResult.fromJson(json.decode(result));
  }

  @override
  Future<RestorePurchasesResult> restorePurchases() async {
    final result =
        (await _invokeMethodHandlingErrors<String>(Method.restorePurchases))
            as String;
    return RestorePurchasesResult.fromJson(json.decode(result));
  }

  @override
  Future<bool> updateAttribution(
    Map attribution, {
    required AdaptyAttributionNetwork source,
    String? networkUserId,
  }) async {
    final result = await _invokeMethodHandlingErrors<bool>(
      Method.updateAttribution,
      {
        Argument.attribution: attribution,
        Argument.source: source.stringValue(),
        if (networkUserId != null) Argument.networkUserId: networkUserId,
      },
    );
    return result ?? false;
  }

  @override
  Future<void> logShowPaywall({required AdaptyPaywall paywall}) async {
    if (Platform.isIOS) {
      await _invokeMethodHandlingErrors<void>(
        Method.logShowPaywall,
        {Argument.variationId: paywall.variationId},
      );
    } else {
      _invokeMethodHandlingErrors<void>(
        Method.logShowPaywall,
        {Argument.variationId: paywall.variationId},
      );
    }
  }

  @override
  Future<AdaptyPromo?> getPromo() async {
    final String? result = await _invokeMethodHandlingErrors(Method.getPromo);
    if (result != null) {
      return AdaptyPromo.fromJson(jsonDecode(result));
    }
    return null;
  }

  @override
  Future<void> setExternalAnalyticsEnabled(bool enabled) {
    return _invokeMethodHandlingErrors<void>(
      Method.setExternalAnalyticsEnabled,
      {Argument.value: enabled},
    );
  }

  @override
  Future<void> setTransactionVariationId({
    required String transactionId,
    required String variationId,
  }) {
    return _invokeMethodHandlingErrors<void>(
      Method.setTransactionVariationId,
      {
        Argument.transactionId: transactionId,
        Argument.variationId: variationId,
      },
    );
  }

  @override
  Future<void> setFallbackPaywalls(String paywalls) {
    return _invokeMethodHandlingErrors<void>(
      Method.setFallbackPaywalls,
      {Argument.paywalls: paywalls},
    );
  }

  @override
  Future<bool> logout() async {
    final result = await _invokeMethodHandlingErrors<bool>(Method.logout);
    return result ?? false;
  }

  // ––––––– VISUAL PAYWALLS METHODS –––––––

  AdaptyVisualPaywallPurchaseSuccessResult? _onVisualPaywallPurchaseSuccess;
  AdaptyVisualPaywallPurchaseFailResult? _onVisualPaywallPurchaseFail;
  AdaptyVisualPaywallCancelResult? _onVisualPaywallCanceled;
  AdaptyVisualPaywallRestoreResult? _onVisualPaywallRestored;

  @override
  Future<bool> showVisualPaywall({
    required AdaptyPaywall paywall,
    AdaptyVisualPaywallPurchaseSuccessResult? onPurchaseSuccess,
    AdaptyVisualPaywallPurchaseFailResult? onPurchaseFail,
    AdaptyVisualPaywallCancelResult? onCancel,
    AdaptyVisualPaywallRestoreResult? onRestore,
  }) async {
    final result = await _invokeMethodHandlingErrors<bool>(
          Method.showVisualPaywall,
          {Argument.variationId: paywall.variationId},
        ) ??
        false;
    if (result) {
      _onVisualPaywallPurchaseSuccess = onPurchaseSuccess;
      _onVisualPaywallPurchaseFail = onPurchaseFail;
      _onVisualPaywallCanceled = onCancel;
      _onVisualPaywallRestored = onRestore;
    }
    return result;
  }

  @override
  Future<bool> closeVisualPaywall() async {
    final result = await _invokeMethodHandlingErrors<bool>(
      Method.closeVisualPaywall,
    );

    _onVisualPaywallPurchaseSuccess = null;
    _onVisualPaywallPurchaseFail = null;
    _onVisualPaywallCanceled = null;
    _onVisualPaywallRestored = null;

    return result ?? false;
  }

  // ––––––– IOS ONLY METHODS –––––––

  @override
  Future<void> setApnsToken(String token) {
    if (!Platform.isIOS) return Future.value();
    return _invokeMethodHandlingErrors<void>(
      Method.setApnsToken,
      {Argument.value: token},
    );
  }

  @override
  Future<void> handlePushNotification(Map userInfo) {
    if (!Platform.isIOS) return Future.value();
    return _invokeMethodHandlingErrors<void>(
      Method.handlePushNotification,
      {Argument.userInfo: userInfo},
    );
  }

  @override
  Future<MakePurchaseResult?> makeDeferredPurchase(String productId) async {
    if (!Platform.isIOS) return null;

    final String result = await (_invokeMethodHandlingErrors(
      Method.makeDeferredPurchase,
      {Argument.productId: productId},
    ) as FutureOr<String>);
    return MakePurchaseResult.fromJson(json.decode(result));
  }

  @override
  Future<void> presentCodeRedemptionSheet() {
    if (!Platform.isIOS) return Future.value();
    return _invokeMethodHandlingErrors<void>(Method.presentCodeRedemptionSheet);
  }

  // ––––––– ANDROID ONLY METHODS –––––––

  @override
  Future<bool> newPushToken(String token) async {
    if (!Platform.isAndroid) return false;

    final bool? result = await _invokeMethodHandlingErrors(
      Method.newPushToken,
      {Argument.pushToken: token},
    );
    return result ?? false;
  }

  @override
  Future<bool> pushReceived(Map<String, String> message) async {
    if (!Platform.isAndroid) return false;

    final bool? result = await _invokeMethodHandlingErrors(
      Method.pushReceived,
      {Argument.pushMessage: message},
    );
    return result ?? false;
  }

  // ––––––– INTERNAL –––––––

  Future<T?> _invokeMethodHandlingErrors<T>(
    String method, [
    dynamic arguments,
  ]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw e.details != null ? AdaptyError.fromMap(json.decode(e.details)) : e;
    }
  }

  Future<dynamic> _handleIncomingMethodCall(MethodCall call) {
    switch (call.method) {
      case Method.deferredPurchaseProduct:
        var productIdentifier = call.arguments as String?;
        if (productIdentifier != null) {
          _deferredPurchasesController.add(productIdentifier);
        }
        return Future.value(null);
      case Method.getPaywallsResult:
        var result = call.arguments as String;
        _getPaywallsResultController.add(
          GetPaywallsResult.fromMap(json.decode(result)),
        );
        return Future.value(null);
      case Method.purchaserInfoUpdate:
        var result = call.arguments as String;
        _purchaserInfoUpdateController.add(
          AdaptyPurchaserInfo.fromMap(json.decode(result)),
        );
        return Future.value(null);
      case Method.promoReceived:
        var result = call.arguments as String;
        _promosReceiveController.add(
          AdaptyPromo.fromJson(json.decode(result)),
        );
        return Future.value(null);
      case Method.visualPaywallPurchaseSuccessResult:
        var result = call.arguments as String;
        _onVisualPaywallPurchaseSuccess?.call(
          MakePurchaseResult.fromJson(json.decode(result)),
        );
        return Future.value(null);
      case Method.visualPaywallPurchaseFailResult:
        var result = call.arguments as String;
        _onVisualPaywallPurchaseFail?.call(
          VisualPaywallPurchaseFailResult.fromJson(json.decode(result)),
        );
        return Future.value(null);
      case Method.visualPaywallCancelResult:
        _onVisualPaywallCanceled?.call();
        return Future.value(null);
      case Method.visualPaywallRestoreResult:
        var result = call.arguments as String;
        _onVisualPaywallRestored?.call(
          RestorePurchasesResult.fromJson(json.decode(result)),
        );
        return Future.value(null);
      default:
        return Future.value(null);
    }
  }
}

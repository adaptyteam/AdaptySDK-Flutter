import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/models/adapty_onboarding_screen_parameters.dart';
import 'package:flutter/services.dart';

import 'constants/arguments_names.dart';
import 'constants/method_names.dart';

import 'models/adapty_error.dart';
import 'models/adapty_ios_products_fetch_policy.dart';
import 'models/adapty_log_level.dart';
import 'models/adapty_profile.dart';
import 'models/adapty_paywall.dart';
import 'models/adapty_profile_parameters.dart';
import 'models/adapty_attribution_source.dart';
import 'models/adapty_android_subscription_update_parameters.dart';
import 'models/adapty_paywall_product.dart';
import 'models/adapty_sdk_native.dart';
export 'models/public.dart';

class Adapty {
  static final sdkVersion = '2.2.0';

  static const String _channelName = 'flutter.adapty.com/adapty';
  static const MethodChannel _channel = const MethodChannel(_channelName);

  static StreamController<AdaptyProfile> _didUpdateProfileController = StreamController.broadcast();
  static Stream<AdaptyProfile> get didUpdateProfileStream => _didUpdateProfileController.stream;

  static void activate() {
    _channel.setMethodCallHandler(_handleIncomingMethodCall);
  }

  static Future<void> setLogLevel(AdaptyLogLevel value) {
    return _invokeMethodHandlingErrors(Method.setLogLevel, {Argument.value: value.index});
  }

  static Future<AdaptyProfile> getProfile() async {
    final result = (await _invokeMethodHandlingErrors<String>(Method.getProfile)) as String;
    return AdaptyProfileJSONBuilder.fromJsonValue(json.decode(result));
  }

  static Future<void> updateProfile(AdaptyProfileParameters params) {
    return _invokeMethodHandlingErrors<void>(Method.updateProfile, {
      Argument.params: json.encode(params.jsonValue),
    });
  }

  static Future<void> identify(String customerUserId) async {
    await _invokeMethodHandlingErrors<void>(Method.identify, {
      Argument.customerUserId: customerUserId,
    });
  }

  static Future<AdaptyPaywall> getPaywall({required String id}) async {
    final result = (await _invokeMethodHandlingErrors<String>(Method.getPaywall, {
      Argument.id: id,
    })) as String;
    return AdaptyPaywallJSONBuilder.fromJsonValue(json.decode(result));
  }

  static Future<List<AdaptyPaywallProduct>> getPaywallProducts({
    required AdaptyPaywall paywall,
    AdaptyIOSProductsFetchPolicy fetchPolicy = AdaptyIOSProductsFetchPolicy.defaultPolicy,
  }) async {
    final result = (await _invokeMethodHandlingErrors<String>(Method.getPaywallProducts, {
      Argument.paywall: json.encode(paywall.jsonValue),
      if (AdaptySDKNative.isIOS) Argument.fetchPolicy: fetchPolicy.jsonValue,
    })) as String;

    final List paywallsResult = json.decode(result);
    return paywallsResult.map((e) => AdaptyPaywallProductJSONBuilder.fromJsonValue(e)).toList();
  }

  static Future<AdaptyProfile> makePurchase({
    required AdaptyPaywallProduct product,
    AdaptyAndroidSubscriptionUpdateParameters? subscriptionUpdateParams,
  }) async {
    final result = (await _invokeMethodHandlingErrors<String>(Method.makePurchase, {
      Argument.product: json.encode(product.jsonValue),
      if (subscriptionUpdateParams != null) Argument.params: subscriptionUpdateParams.jsonValue,
    })) as String;

    return AdaptyProfileJSONBuilder.fromJsonValue(json.decode(result));
  }

  static Future<AdaptyProfile> restorePurchases() async {
    final result = (await _invokeMethodHandlingErrors<String>(Method.restorePurchases)) as String;
    return AdaptyProfileJSONBuilder.fromJsonValue(json.decode(result));
  }

  static Future<void> updateAttribution(
    Map attribution, {
    required AdaptyAttributionSource source,
    String? networkUserId,
  }) async {
    return await _invokeMethodHandlingErrors<void>(Method.updateAttribution, {
      Argument.attribution: attribution,
      Argument.source: source.jsonValue,
      if (networkUserId != null) Argument.networkUserId: networkUserId,
    });
  }

  static Future<void> logShowPaywall({required AdaptyPaywall paywall}) async {
    return _invokeMethodHandlingErrors<void>(Method.logShowPaywall, {
      Argument.paywall: json.encode(paywall.jsonValue),
    });
  }

  static Future<void> logShowOnboarding({String? name, String? screenName, required int screenOrder}) async {
    final params = AdaptyOnboardingScreenParameters(name: name, screenName: screenName, screenOrder: screenOrder);
    final paramsString = json.encode(params.jsonValue);

    await _invokeMethodHandlingErrors<void>(Method.logShowOnboarding, {
      Argument.onboardingParams: paramsString,
    });
  }

  static Future<void> setTransactionVariationId(String transactionId, String variationId) {
    return _invokeMethodHandlingErrors<void>(Method.setTransactionVariationId, {
      Argument.transactionId: transactionId,
      Argument.variationId: variationId,
    });
  }

  static Future<void> setFallbackPaywalls(String paywalls) {
    return _invokeMethodHandlingErrors<void>(Method.setFallbackPaywalls, {Argument.paywalls: paywalls});
  }

  static Future<bool> logout() async {
    final result = await _invokeMethodHandlingErrors<bool>(Method.logout);
    return result ?? false;
  }

  // ––––––– IOS ONLY METHODS –––––––

  static Future<void> presentCodeRedemptionSheet() {
    if (!AdaptySDKNative.isIOS) return Future.value();
    return _invokeMethodHandlingErrors<void>(Method.presentCodeRedemptionSheet);
  }

  // ––––––– INTERNAL –––––––

  static Future<T?> _invokeMethodHandlingErrors<T>(String method, [dynamic arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw e.details != null ? AdaptyErrorJSONBuilder.fromJsonValue(json.decode(e.details)) : e;
    }
  }

  static Future<dynamic> _handleIncomingMethodCall(MethodCall call) {
    switch (call.method) {
      case IncomingMethod.didUpdateProfile:
        var result = call.arguments as String;
        _didUpdateProfileController.add(AdaptyProfileJSONBuilder.fromJsonValue(json.decode(result)));
        return Future.value(null);
      default:
        return Future.value(null);
    }
  }
}

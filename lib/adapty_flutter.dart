import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:adapty_flutter/models/adapty_android_subscription_update_params.dart';
import 'package:adapty_flutter/models/adapty_error.dart';
import 'package:adapty_flutter/models/adapty_paywall.dart';
import 'package:adapty_flutter/models/adapty_profile_parameter_builder.dart';
import 'package:adapty_flutter/models/adapty_profile.dart';
import 'package:flutter/services.dart';

import 'constants/arguments_names.dart';
import 'constants/method_names.dart';
import 'models/adapty_enums.dart';
import 'models/adapty_product.dart';

export 'entities/AdaptyAccessLevel.dart' show AdaptyAccessLevel;
export 'entities/AdaptyAndroidSubscriptionUpdateProrationMode.dart' show AdaptyAndroidSubscriptionUpdateProrationMode;
export 'entities/AdaptyAppTrackingTransparencyStatus.dart' show AdaptyAppTrackingTransparencyStatus;
export 'entities/AdaptyAttributionSource.dart' show AdaptyAttributionSource;
export 'entities/AdaptyDeferredproduct.dart' show AdaptyDeferredProduct;
export 'entities/AdaptyEligibility.dart' show AdaptyEligibility;
export 'entities/AdaptyError.dart' show AdaptyError;
export 'entities/AdaptyLogLevel.dart' show AdaptyLogLevel;
export 'entities/AdaptyNonSubscription.dart' show AdaptyNonSubscription;
export 'entities/AdaptyOnboardingScreenParameters.dart' show AdaptyOnboardingScreenParameters;
export 'entities/AdaptyPaymentMode.dart' show AdaptyPaymentMode;
export 'entities/AdaptyPaywall.dart' show AdaptyPaywall;
export 'entities/AdaptyPaywallProduct.dart' show AdaptyPaywallProduct;
export 'entities/AdaptyPeriodUnit.dart' show AdaptyPeriodUnit;
export 'entities/AdaptyProductDiscount.dart' show AdaptyProductDiscount;
export 'entities/AdaptyProfile.dart' show AdaptyProfile;
export 'entities/AdaptyProfileGender.dart' show AdaptyProfileGender;
export 'entities/AdaptyProfileParameters.dart' show AdaptyProfileParameters;
export 'entities/AdaptyProfileParametersBuilder.dart' show AdaptyProfileParametersBuilder;
export 'entities/AdaptyResult.dart' show AdaptyResult;
export 'entities/AdaptySubscription.dart' show AdaptySubscription;
export 'entities/AdaptySubscriptionPeriod.dart' show AdaptySubscriptionPeriod;
export 'entities/AdaptySubscriptionUpdateParameters.dart' show AdaptySubscriptionUpdateParameters;

class Adapty {
  static const String _channelName = 'flutter.adapty.com/adapty';
  static const MethodChannel _channel = const MethodChannel(_channelName);

  static StreamController<String> _deferredPurchasesController = StreamController.broadcast();
  static StreamController<AdaptyProfile> _didUpdateProfileController = StreamController.broadcast();

  static Stream<String> get deferredPurchasesStream => _deferredPurchasesController.stream;
  static Stream<AdaptyProfile> get didUpdateProfileStream => _didUpdateProfileController.stream;

  static void activate() {
    _channel.setMethodCallHandler(_handleIncomingMethodCall);
  }

  static Future<void> setLogLevel(AdaptyLogLevel value) {
    return _invokeMethodHandlingErrors(Method.setLogLevel, {Argument.value: value.index});
  }

  static Future<bool> identify(String customerUserId) async {
    final result = await _invokeMethodHandlingErrors<bool>(Method.identify, {
      Argument.customerUserId: customerUserId,
    });
    return result ?? false;
  }

  static Future<AdaptyPaywall> getPaywall({required String id}) async {
    final result = (await _invokeMethodHandlingErrors<String>(Method.getPaywall, {
      Argument.id: id,
    })) as String;
    return AdaptyPaywall.fromMap(json.decode(result));
  }

  static Future<List<AdaptyPaywallProduct>> getPaywallProducts({required AdaptyPaywall paywall}) async {
    // final paywallMap = paywall.toMap();
    // final paywallMapString = json.encode(paywallMap);
    final result = (await _invokeMethodHandlingErrors<String>(Method.getPaywallProducts, {
      'variation_id': paywall.variationId,
      // Argument.paywall: paywallMapString,
      // Argument.fetchPolicy: 'default',
    })) as String;

    final arr = json.decode(result);
    return List.empty();
    // return AdaptyPaywallProduct.fromMap(json.decode(result));
  }

  static Future<AdaptyProfile> getProfile() async {
    final result = (await _invokeMethodHandlingErrors<String>(Method.getProfile)) as String;
    return AdaptyProfile.fromMap(json.decode(result));
  }

  static Future<bool> updateProfile(AdaptyProfileParameterBuilder builder) async {
    final result = await _invokeMethodHandlingErrors<bool>(Method.updateProfile, {
      Argument.params: builder.map,
    });
    return result ?? false;
  }

  static Future<AdaptyProfile> makePurchase(
    AdaptyPaywallProduct product, {
    String? offerId,
    AdaptyAndroidSubscriptionUpdateParams? subscriptionUpdateParams,
  }) async {
    final result = (await _invokeMethodHandlingErrors<String>(Method.makePurchase, {
      Argument.productId: product.vendorProductId,
      if (offerId != null) Argument.offerId: offerId,
      if (product.variationId != null) Argument.variationId: product.variationId,
      if (subscriptionUpdateParams != null) Argument.params: subscriptionUpdateParams.toMap()
    })) as String;
    return AdaptyProfile.fromMap(json.decode(result));
  }

  static Future<AdaptyProfile> restorePurchases() async {
    final result = (await _invokeMethodHandlingErrors<String>(Method.restorePurchases)) as String;
    return AdaptyProfile.fromMap(json.decode(result));
  }

  static Future<bool> updateAttribution(Map attribution, {required AdaptyAttributionNetwork source, String? networkUserId}) async {
    final result = await _invokeMethodHandlingErrors<bool>(Method.updateAttribution, {
      Argument.attribution: attribution,
      Argument.source: source.stringValue(),
      if (networkUserId != null) Argument.networkUserId: networkUserId,
    });
    return result ?? false;
  }

  static Future<void> logShowPaywall({required AdaptyPaywall paywall}) async {
    if (Platform.isIOS) {
      await _invokeMethodHandlingErrors<void>(Method.logShowPaywall, {
        Argument.variationId: paywall.variationId,
      });
    } else {
      _invokeMethodHandlingErrors<void>(Method.logShowPaywall, {
        Argument.variationId: paywall.variationId,
      });
    }
  }

  static Future<void> setExternalAnalyticsEnabled(bool enabled) {
    return _invokeMethodHandlingErrors<void>(Method.setExternalAnalyticsEnabled, {
      Argument.value: enabled,
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
    if (!Platform.isIOS) return Future.value();
    return _invokeMethodHandlingErrors<void>(Method.presentCodeRedemptionSheet);
  }

  // ––––––– INTERNAL –––––––

  static Future<T?> _invokeMethodHandlingErrors<T>(String method, [dynamic arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw e.details != null ? AdaptyError.fromMap(json.decode(e.details)) : e;
    }
  }

  static Future<dynamic> _handleIncomingMethodCall(MethodCall call) {
    switch (call.method) {
      case Method.deferredPurchaseProduct:
        var productIdentifier = call.arguments as String?;
        if (productIdentifier != null) {
          _deferredPurchasesController.add(productIdentifier);
        }
        return Future.value(null);
      case Method.didUpdateProfile:
        var result = call.arguments as String;
        _didUpdateProfileController.add(AdaptyProfile.fromMap(json.decode(result)));
        return Future.value(null);
      default:
        return Future.value(null);
    }
  }
}

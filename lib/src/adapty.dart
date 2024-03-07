import 'dart:async' show StreamController;
import 'dart:convert' show json;

import 'adapty_logger.dart';
import 'package:flutter/services.dart';

import 'constants/argument.dart';
import 'constants/method.dart';

import 'models/adapty_error.dart';
import 'models/adapty_log_level.dart';
import 'models/adapty_profile.dart';
import 'models/adapty_paywall.dart';
import 'models/adapty_paywall_fetch_policy.dart';
import 'models/adapty_profile_parameters.dart';
import 'models/adapty_attribution_source.dart';
import 'models/adapty_android_subscription_update_parameters.dart';
import 'models/adapty_onboarding_screen_parameters.dart';
import 'models/adapty_paywall_product.dart';
import 'models/adapty_eligibility.dart';
import 'models/adapty_sdk_native.dart';

class Adapty {
  static final Adapty _instance = Adapty._internal();

  factory Adapty() => _instance;

  Adapty._internal();

  static const String sdkVersion = '2.10.0';

  static const String _channelName = 'flutter.adapty.com/adapty';
  static const MethodChannel _channel = const MethodChannel(_channelName);

  StreamController<AdaptyProfile> _didUpdateProfileController = StreamController.broadcast();
  Stream<AdaptyProfile> get didUpdateProfileStream => _didUpdateProfileController.stream;

  /// Use this method to initialize the Adapty SDK.
  void activate() {
    _channel.setMethodCallHandler(_handleIncomingMethodCall);
  }

  /// Set to the most appropriate level of logging.
  Future<void> setLogLevel(AdaptyLogLevel value) {
    AdaptyLogger.logLevel = value;
    return _invokeMethodHandlingErrors(Method.setLogLevel, {Argument.value: value.jsonValue});
  }

  /// The main function for getting a user profile. Allows you to define the level of access, as well as other parameters.
  ///
  /// The getProfile method provides the most up-to-date result as it always tries to query the API.
  /// If for some reason (e.g. no internet connection), the Adapty SDK fails to retrieve information from the server, the data from cache will be returned.
  /// It is also important to note that the Adapty SDK updates AdaptyProfile cache on a regular basis, in order to keep this information as up-to-date as possible.
  ///
  /// **Returns:**
  /// - the result containing a [AdaptyProfile] object.
  /// This model contains info about access levels, subscriptions, and non-subscription purchases. Generally, you have to check only access level status to determine whether the user has premium access to the app.
  Future<AdaptyProfile> getProfile() async {
    final result = (await _invokeMethodHandlingErrors<String>(Method.getProfile)) as String;
    return AdaptyProfileJSONBuilder.fromJsonValue(json.decode(result));
  }

  /// You can set optional attributes such as email, phone number, etc, to the user of your app.
  /// You can then use attributes to create user [segments](https://docs.adapty.io/v2.0/docs/segments) or just view them in CRM.
  ///
  /// **Parameters:**
  /// - [params]: use [AdaptyProfileParametersBuilder] to build this object.
  Future<void> updateProfile(AdaptyProfileParameters params) {
    return _invokeMethodHandlingErrors<void>(Method.updateProfile, {
      Argument.params: json.encode(params.jsonValue),
    });
  }

  /// Use this method for identifying user with it’s user id in your system.
  ///
  /// If you don’t have a user id on SDK configuration, you can set it later at any time with `.identify()` method.
  /// The most common cases are after registration/authorization when the user switches from being an anonymous user to an authenticated user.
  ///
  /// **Parameters:**
  /// - [customerUserId]: User identifier in your system.
  Future<void> identify(String customerUserId) async {
    await _invokeMethodHandlingErrors<void>(Method.identify, {
      Argument.customerUserId: customerUserId,
    });
  }

  /// Adapty allows you remotely configure the products that will be displayed in your app.
  /// This way you don’t have to hardcode the products and can dynamically change offers or run A/B tests without app releases.
  ///
  /// Read more on the [Adapty Documentation](https://docs.adapty.io/v2.0/docs/displaying-products)
  ///
  /// **Parameters:**
  /// - [placementId]: the identifier of the desired placement. This is the value you specified when you created the placement in the Adapty Dashboard.
  ///
  /// **Returns:**
  /// - the [AdaptyPaywall] object. This model contains the list of the products ids, paywall’s identifier, custom payload, and several other properties.
  Future<AdaptyPaywall> getPaywall({required String placementId, String? locale, AdaptyPaywallFetchPolicy? fetchPolicy, Duration? loadTimeout}) async {
    final result = (await _invokeMethodHandlingErrors<String>(Method.getPaywall, {
      Argument.placementId: placementId,
      if (locale != null) Argument.locale: locale,
      if (fetchPolicy != null) Argument.fetchPolicy: json.encode(fetchPolicy.jsonValue),
      if (loadTimeout != null) Argument.loadTimeout: loadTimeout.inMilliseconds.toDouble() / 1000.0,
    })) as String;
    return AdaptyPaywallJSONBuilder.fromJsonValue(json.decode(result));
  }

  /// Once you have a [AdaptyPaywall], fetch corresponding products array using this method.
  ///
  /// **Parameters:**
  /// - paywall: an [AdaptyPaywall] for which you want to get a products.
  ///
  /// **Returns:**
  /// - a result containing the [AdaptyPaywallProduct] objects array. You can present them in your UI.
  Future<List<AdaptyPaywallProduct>> getPaywallProducts({
    required AdaptyPaywall paywall,
  }) async {
    final result = (await _invokeMethodHandlingErrors<String>(Method.getPaywallProducts, {
      Argument.paywall: json.encode(paywall.jsonValue),
    })) as String;

    final List paywallsResult = json.decode(result);
    return paywallsResult.map((e) => AdaptyPaywallProductJSONBuilder.fromJsonValue(e)).toList();
  }

  /// Once you have an [AdaptyPaywallProduct] array, fetch introductory offers information for this products.
  ///
  /// Read more on the [Adapty Documentation](https://docs.adapty.io/docs/displaying-products#products-fetch-policy-and-intro-offer-eligibility-not-applicable-for-android)
  /// **Parameters:**
  /// - products: the [AdaptyPaywallProduct] array, for which information will be retrieved.
  ///
  /// **Returns:**
  /// - a map where Key is `vendorProductId` and Value is corresponding [AdaptyEligibility].
  Future<Map<String, AdaptyEligibility>> getProductsIntroductoryOfferEligibility({
    required List<AdaptyPaywallProduct> products,
  }) async {
    if (AdaptySDKNative.isAndroid) {
      return Map<String, AdaptyEligibility>.fromIterable(products,
          key: (item) => item.vendorProductId, value: (item) => item.subscriptionDetails?.androidIntroductoryOfferEligibility ?? AdaptyEligibility.ineligible);
    }

    final resultString = (await _invokeMethodHandlingErrors<String>(Method.getProductsIntroductoryOfferEligibility, {
      Argument.productsIds: products.map((e) => e.vendorProductId).toList(),
    })) as String;

    final Map<String, dynamic> resultMap = json.decode(resultString);
    var result = new Map<String, AdaptyEligibility>();

    for (MapEntry<String, dynamic> entry in resultMap.entries) {
      result[entry.key] = AdaptyEligibilityJSONBuilder.fromJsonValue(entry.value.toString());
    }

    return result;
  }

  /// To make the purchase, you have to call this method.
  /// Read more on the [Adapty Documentation](https://docs.adapty.io/docs/making-purchases)
  ///
  /// **Parameters:**
  /// - [product]: an [AdaptyPaywallProduct] object retrieved from the paywall.
  /// - [subscriptionUpdateParams]: an [AdaptySubscriptionUpdateParameters] object used
  /// to upgrade or downgrade a subscription (use for Android).
  /// - [isOfferPersonalized]: Specifies whether the offer is personalized to the buyer (use for Android).
  ///
  /// **Returns:**
  /// - The [AdaptyProfile] object. This model contains info about access levels, subscriptions, and non-subscription purchases.
  /// Generally, you have to check only access level status to determine whether the user has premium access to the app.
  Future<AdaptyProfile?> makePurchase({
    required AdaptyPaywallProduct product,
    AdaptyAndroidSubscriptionUpdateParameters? subscriptionUpdateParams,
    bool? isOfferPersonalized,
  }) async {
    final result = await _invokeMethodHandlingErrors<String>(Method.makePurchase, {
      Argument.product: json.encode(product.jsonValue),
      if (subscriptionUpdateParams != null) Argument.params: json.encode(subscriptionUpdateParams.jsonValue),
      if (isOfferPersonalized != null) Argument.isOfferPersonalized: isOfferPersonalized,
    });

    return (result == null) ? null : AdaptyProfileJSONBuilder.fromJsonValue(json.decode(result));
  }

  /// To restore purchases, you have to call this method.
  ///
  /// **Returns:**
  /// - A result containing the AdaptyProfile object. This model contains info about access levels, subscriptions, and non-subscription purchases.
  /// Generally, you have to check only access level status to determine whether the user has premium access to the app.
  Future<AdaptyProfile> restorePurchases() async {
    final result = (await _invokeMethodHandlingErrors<String>(Method.restorePurchases)) as String;
    return AdaptyProfileJSONBuilder.fromJsonValue(json.decode(result));
  }

  /// You can set attribution data for the profile, using method.
  /// Read more on the [Adapty Documentation](https://docs.adapty.io/docs/attribution-integration)
  ///
  /// **Parameters:**
  /// - [attribution]: a map containing attribution (conversion) data.
  /// - [source]: a source of attribution.
  /// - [networkUserId]: a string profile's identifier from the attribution service.
  Future<void> updateAttribution(
    Map attribution, {
    required AdaptyAttributionSource source,
    String? networkUserId,
  }) async {
    if (!AdaptySDKNative.isIOS && source == AdaptyAttributionSource.appleSearchAds) {
      AdaptyLogger.write(AdaptyLogLevel.warn, 'Apple Search Ads is supporting only on iOS');
      return null;
    }

    return await _invokeMethodHandlingErrors<void>(Method.updateAttribution, {
      Argument.attribution: attribution,
      Argument.source: source.jsonValue,
      if (networkUserId != null) Argument.networkUserId: networkUserId,
    });
  }

  /// Call this method to notify Adapty SDK, that particular paywall was shown to user.
  ///
  /// Adapty helps you to measure the performance of the paywalls.
  /// We automatically collect all the metrics related to purchases except for paywall views.
  /// This is because only you know when the paywall was shown to a customer. Whenever you show a paywall to your user, call .logShowPaywall(paywall) to log the event, and it will be accumulated in the paywall metrics.
  /// Read more on the [Adapty Documentation](https://docs.adapty.io/v2.0/docs/ios-displaying-products#paywall-analytics)
  ///
  /// **Parameters:**
  /// - [paywall]: An [AdaptyPaywall] object.
  Future<void> logShowPaywall({required AdaptyPaywall paywall}) async {
    return _invokeMethodHandlingErrors<void>(Method.logShowPaywall, {
      Argument.paywall: json.encode(paywall.jsonValue),
    });
  }

  /// Call this method to keep track of the user’s steps while onboarding
  ///
  /// The onboarding stage is a very common situation in modern mobile apps.
  /// The quality of its implementation, content, and number of steps can have a rather significant influence on further user behavior, especially on his desire to become a subscriber or simply make some purchases.
  /// In order for you to be able to analyze user behavior at this critical stage without leaving Adapty, we have implemented the ability to send dedicated events every time a user visits yet another onboarding screen.
  ///
  /// **Parameters:**
  /// - [name]: Name of your onboarding.
  /// - [screenName]: Readable name of a particular screen as part of onboarding.
  /// - [screenOrder]: An unsigned integer value representing the order of this screen in your onboarding sequence (it must me greater than 0).
  Future<void> logShowOnboarding({String? name, String? screenName, required int screenOrder}) async {
    final params = AdaptyOnboardingScreenParameters(name: name, screenName: screenName, screenOrder: screenOrder);
    final paramsString = json.encode(params.jsonValue);

    await _invokeMethodHandlingErrors<void>(Method.logShowOnboarding, {
      Argument.onboardingParams: paramsString,
    });
  }

  /// In Observer mode, Adapty SDK doesn’t know, where the purchase was made from.
  /// If you display products using our [Paywalls](https://docs.adapty.io/v2.0/docs/paywall) or [A/B Tests](https://docs.adapty.io/v2.0/docs/ab-test), you can manually assign variation to the purchase.
  /// After doing this, you’ll be able to see metrics in Adapty Dashboard.
  ///
  /// **Parameters:**
  /// - [variationId]: A string identifier of variation. You can get it using variationId property of AdaptyPaywall.
  /// - [transactionId]: A string identifier of your purchased transaction [SKPaymentTransaction](https://developer.apple.com/documentation/storekit/skpaymenttransaction) for iOS or string identifier (`purchase.getOrderId()`) of the purchase, where the purchase is an instance of the billing library Purchase class for Android.
  Future<void> setVariationId(String transactionId, String variationId) {
    return _invokeMethodHandlingErrors<void>(Method.setTransactionVariationId, {
      Argument.transactionId: transactionId,
      Argument.variationId: variationId,
    });
  }

  /// To set fallback paywalls, use this method. You should pass exactly the same payload you’re getting from Adapty backend. You can copy it from Adapty Dashboard.
  ///
  /// Adapty allows you to provide fallback paywalls that will be used when a user opens the app for the first time and there’s no internet connection or in the rare case when Adapty backend is down and there’s no cache on the device.
  /// Read more on the [Adapty Documentation](https://docs.adapty.io/v2.0/docs/ios-displaying-products#fallback-paywalls)
  ///
  /// **Parameters:**
  /// - [paywalls]: a JSON representation of your paywalls/products list in the exact same format as provided by Adapty backend.
  Future<void> setFallbackPaywalls(String paywalls) {
    return _invokeMethodHandlingErrors<void>(Method.setFallbackPaywalls, {Argument.paywalls: paywalls});
  }

  /// You can logout the user anytime by calling this method.
  Future<void> logout() async {
    return _invokeMethodHandlingErrors<void>(Method.logout);
  }

  // ––––––– IOS ONLY METHODS –––––––

  /// Call this method to have StoreKit present a sheet enabling the user to redeem codes provided by your app.
  Future<void> presentCodeRedemptionSheet() {
    if (!AdaptySDKNative.isIOS) return Future.value();
    return _invokeMethodHandlingErrors<void>(Method.presentCodeRedemptionSheet);
  }

  // ––––––– INTERNAL –––––––

  Future<T?> _invokeMethodHandlingErrors<T>(String method, [dynamic arguments]) async {
    AdaptyLogger.write(AdaptyLogLevel.verbose, '--> Adapty.$method()');

    try {
      final result = await _channel.invokeMethod<T>(method, arguments);
      AdaptyLogger.write(AdaptyLogLevel.verbose, '<-- Adapty.$method()');
      return result;
    } on PlatformException catch (e) {
      if (e.details != null) {
        final adaptyErrorData = json.decode(e.details);
        final adaptyError = AdaptyErrorJSONBuilder.fromJsonValue(adaptyErrorData);
        AdaptyLogger.write(AdaptyLogLevel.verbose, '<-- Adapty.$method() Adapty Error $adaptyError');
        throw adaptyError;
      } else {
        AdaptyLogger.write(AdaptyLogLevel.verbose, '<-- Adapty.$method() Error $e');
        throw e;
      }
    }
  }

  Future<dynamic> _handleIncomingMethodCall(MethodCall call) {
    AdaptyLogger.write(AdaptyLogLevel.verbose, 'handleIncomingCall ${call.method}');

    switch (call.method) {
      case IncomingMethod.didUpdateProfile:
        var result = call.arguments as String;
        final profile = AdaptyProfileJSONBuilder.fromJsonValue(json.decode(result));
        _didUpdateProfileController.add(profile);
        return Future.value(null);
      default:
        return Future.value(null);
    }
  }
}

import 'dart:async' show StreamController;
import 'dart:convert' show json;
import 'package:flutter/services.dart';

import 'adapty_logger.dart';

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
import 'models/adapty_sdk_native.dart';
import 'models/adapty_configuration.dart';
import 'models/adapty_error_code.dart';

import 'adaptyui_observer.dart';

import 'models/adaptyui_action.dart';
import 'models/adaptyui_configuration.dart';
import 'models/adaptyui_dialog.dart';
import 'models/adaptyui_view.dart';

part 'adaptyui.dart';

class Adapty {
  static final Adapty _instance = Adapty._internal();

  factory Adapty() => _instance;

  Adapty._internal();

  static const String sdkVersion = '3.2.0-SNAPSHOT';

  static const String _channelName = 'flutter.adapty.com/adapty';
  static const MethodChannel _channel = const MethodChannel(_channelName);

  StreamController<AdaptyProfile> _didUpdateProfileController = StreamController.broadcast();
  Stream<AdaptyProfile> get didUpdateProfileStream => _didUpdateProfileController.stream;

  /// Use this method to initialize the Adapty SDK.
  Future<void> activate({
    required AdaptyConfiguration configuration,
  }) {
    _channel.setMethodCallHandler(_handleIncomingMethodCall);

    return _invokeMethod<void>(
      Method.activate,
      (data) => null,
      {
        Argument.configuration: json.encode(configuration.jsonValue),
      },
    );
  }

  /// Set to the most appropriate level of logging.
  Future<void> setLogLevel(AdaptyLogLevel value) {
    AdaptyLogger.logLevel = value;

    return _invokeMethod<void>(
      Method.setLogLevel,
      (data) => null,
      {
        Argument.value: value.name,
      },
    );
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
  Future<AdaptyProfile> getProfile() {
    return _invokeMethod<AdaptyProfile>(
      Method.getProfile,
      (data) {
        final profileMap = data as Map<String, dynamic>;
        return AdaptyProfileJSONBuilder.fromJsonValue(profileMap);
      },
    );
  }

  /// You can set optional attributes such as email, phone number, etc, to the user of your app.
  /// You can then use attributes to create user [segments](https://docs.adapty.io/v2.0/docs/segments) or just view them in CRM.
  ///
  /// **Parameters:**
  /// - [params]: use [AdaptyProfileParametersBuilder] to build this object.
  Future<void> updateProfile(AdaptyProfileParameters params) {
    return _invokeMethod<void>(
      Method.updateProfile,
      (data) => null,
      {
        Argument.params: json.encode(params.jsonValue),
      },
    );
  }

  /// Use this method for identifying user with it’s user id in your system.
  ///
  /// If you don’t have a user id on SDK configuration, you can set it later at any time with `.identify()` method.
  /// The most common cases are after registration/authorization when the user switches from being an anonymous user to an authenticated user.
  ///
  /// **Parameters:**
  /// - [customerUserId]: User identifier in your system.
  Future<void> identify(String customerUserId) {
    return _invokeMethod<void>(
      Method.identify,
      (data) => null,
      {
        Argument.customerUserId: customerUserId,
      },
    );
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
  Future<AdaptyPaywall> getPaywall({
    required String placementId,
    String? locale,
    AdaptyPaywallFetchPolicy? fetchPolicy,
    Duration? loadTimeout,
  }) {
    return _invokeMethod<AdaptyPaywall>(
      Method.getPaywall,
      (data) {
        final paywallMap = data as Map<String, dynamic>;
        return AdaptyPaywallJSONBuilder.fromJsonValue(paywallMap);
      },
      {
        Argument.placementId: placementId,
        if (locale != null) Argument.locale: locale,
        if (fetchPolicy != null) Argument.fetchPolicy: json.encode(fetchPolicy.jsonValue),
        if (loadTimeout != null) Argument.loadTimeout: loadTimeout.inMilliseconds.toDouble() / 1000.0,
      },
    );
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
  }) {
    return _invokeMethod<List<AdaptyPaywallProduct>>(
      Method.getPaywallProducts,
      (data) {
        final paywallProductsMap = data as List<dynamic>;
        return paywallProductsMap.map((e) => AdaptyPaywallProductJSONBuilder.fromJsonValue(e)).toList();
      },
      {Argument.paywall: json.encode(paywall.jsonValue)},
    );
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
  Future<AdaptyProfile> makePurchase({
    required AdaptyPaywallProduct product,
    AdaptyAndroidSubscriptionUpdateParameters? subscriptionUpdateParams,
    bool? isOfferPersonalized,
  }) {
    // TODO: validate
    return _invokeMethod<AdaptyProfile>(
      Method.makePurchase,
      (data) {
        final profileMap = data as Map<String, dynamic>;
        return AdaptyProfileJSONBuilder.fromJsonValue(profileMap);
      },
      {
        Argument.product: json.encode(product.jsonValue),
        if (subscriptionUpdateParams != null) Argument.params: json.encode(subscriptionUpdateParams.jsonValue),
        if (isOfferPersonalized != null) Argument.isOfferPersonalized: isOfferPersonalized,
      },
    );
  }

  /// To restore purchases, you have to call this method.
  ///
  /// **Returns:**
  /// - A result containing the AdaptyProfile object. This model contains info about access levels, subscriptions, and non-subscription purchases.
  /// Generally, you have to check only access level status to determine whether the user has premium access to the app.
  Future<AdaptyProfile> restorePurchases() {
    return _invokeMethod<AdaptyProfile>(
      Method.restorePurchases,
      (data) {
        final profileMap = data as Map<String, dynamic>;
        return AdaptyProfileJSONBuilder.fromJsonValue(profileMap);
      },
    );
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
  }) {
    // TODO: validate
    if (!AdaptySDKNative.isIOS && source == AdaptyAttributionSource.appleSearchAds) {
      AdaptyLogger.write(AdaptyLogLevel.warn, 'Apple Search Ads is supporting only on iOS');
      return Future.value();
    }

    final attributionString = json.encode(attribution);
    return _invokeMethod<void>(
      Method.updateAttribution,
      (data) => null,
      {
        Argument.attribution: attributionString,
        Argument.source: source.jsonValue,
        if (networkUserId != null) Argument.networkUserId: networkUserId,
      },
    );
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
  Future<void> logShowPaywall({required AdaptyPaywall paywall}) {
    return _invokeMethod<void>(
      Method.logShowPaywall,
      (data) => null,
      {
        Argument.paywall: json.encode(paywall.jsonValue),
      },
    );
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
  Future<void> logShowOnboarding({
    String? name,
    String? screenName,
    required int screenOrder,
  }) {
    final params = AdaptyOnboardingScreenParameters(
      name: name,
      screenName: screenName,
      screenOrder: screenOrder,
    );

    return _invokeMethod<void>(
      Method.logShowOnboarding,
      (data) => null,
      {
        Argument.params: json.encode(params.jsonValue),
      },
    );
  }

  /// In Observer mode, Adapty SDK doesn’t know, where the purchase was made from.
  /// If you display products using our [Paywalls](https://docs.adapty.io/v2.0/docs/paywall) or [A/B Tests](https://docs.adapty.io/v2.0/docs/ab-test), you can manually assign variation to the purchase.
  /// After doing this, you’ll be able to see metrics in Adapty Dashboard.
  ///
  /// **Parameters:**
  /// - [variationId]: A string identifier of variation. You can get it using variationId property of AdaptyPaywall.
  /// - [transactionId]: A string identifier of your purchased transaction [SKPaymentTransaction](https://developer.apple.com/documentation/storekit/skpaymenttransaction) for iOS or string identifier (`purchase.getOrderId()`) of the purchase, where the purchase is an instance of the billing library Purchase class for Android.
  Future<void> setVariationId(String transactionId, String variationId) {
    return _invokeMethod<void>(
      Method.setVariationId,
      (data) => null,
      {
        Argument.transactionId: transactionId,
        Argument.variationId: variationId,
      },
    );
  }

  /// To set fallback paywalls, use this method. You should pass exactly the same payload you’re getting from Adapty backend. You can copy it from Adapty Dashboard.
  ///
  /// Adapty allows you to provide fallback paywalls that will be used when a user opens the app for the first time and there’s no internet connection or in the rare case when Adapty backend is down and there’s no cache on the device.
  /// Read more on the [Adapty Documentation](https://docs.adapty.io/v2.0/docs/ios-displaying-products#fallback-paywalls)
  ///
  /// **Parameters:**
  /// - [assetId]: a path to the asset file with fallback paywalls.
  Future<void> setFallbackPaywalls(String assetId) {
    return _invokeMethod<void>(
      Method.setFallbackPaywalls,
      (data) => null,
      {
        Argument.assetId: assetId,
      },
    );
  }

  /// You can logout the user anytime by calling this method.
  Future<void> logout() {
    return _invokeMethod<void>(Method.logout, (data) => null);
  }

  // ––––––– IOS ONLY METHODS –––––––

  /// Call this method to have StoreKit present a sheet enabling the user to redeem codes provided by your app.
  Future<void> presentCodeRedemptionSheet() {
    if (!AdaptySDKNative.isIOS) return Future.value();
    return _invokeMethod<void>(Method.presentCodeRedemptionSheet, (data) => null);
  }

  // ––––––– INTERNAL –––––––

  Future<T> _invokeMethod<T>(String method, T Function(dynamic) responseParser, [dynamic arguments]) async {
    final stamp = AdaptyLogger.stamp;
    AdaptyLogger.write(AdaptyLogLevel.verbose, '[$stamp] --> Adapty.$method(), Args: $arguments');

    try {
      final stringResult = await _channel.invokeMethod<String>(method, arguments);

      if (stringResult == null) {
        // TODO: inspect this
        throw AdaptyError('Adapty.$method() returned null', AdaptyErrorCode.emptyResult, null);
      }

      final decodedResult = json.decode(stringResult) as Map<String, dynamic>;
      AdaptyLogger.write(AdaptyLogLevel.verbose, '[$stamp] <-- Adapty.$method(), Result: $decodedResult');

      if (decodedResult.containsKey(Argument.error)) {
        final adaptyErrorData = decodedResult[Argument.error];

        final adaptyError = AdaptyErrorJSONBuilder.fromJsonValue(adaptyErrorData);
        throw adaptyError;
      } else {
        final successData = decodedResult[Argument.success];
        final successObject = responseParser(successData);

        AdaptyLogger.write(AdaptyLogLevel.verbose, '[$stamp] <-- Adapty.$method(), Success Object: $successObject');

        return successObject;
      }
    } on AdaptyError catch (e) {
      AdaptyLogger.write(AdaptyLogLevel.verbose, '[$stamp] <-- Adapty.$method() Error: $e');
      throw e;
    } catch (e) {
      final adaptyError = AdaptyError(
        'Internal plugin error in Adapty.$method()',
        AdaptyErrorCode.internalPluginError,
        e.toString(),
      );

      AdaptyLogger.write(AdaptyLogLevel.verbose, '[$stamp] <-- Adapty.$method() Error: $adaptyError');
      throw adaptyError;
    }
  }

  Future<dynamic> _handleIncomingMethodCall(MethodCall call) {
    AdaptyLogger.write(AdaptyLogLevel.verbose, 'handleIncomingCall ${call.method}');

    AdaptyUIView decodeView() {
      return AdaptyUIViewJSONBuilder.fromJsonValue(json.decode(call.arguments[Argument.view]));
    }

    AdaptyPaywallProduct decodeProduct() {
      return AdaptyPaywallProductJSONBuilder.fromJsonValue(json.decode(call.arguments[Argument.product]));
    }

    AdaptyProfile decodeProfile() {
      return AdaptyProfileJSONBuilder.fromJsonValue(json.decode(call.arguments[Argument.profile]));
    }

    AdaptyError decodeError() {
      return AdaptyErrorJSONBuilder.fromJsonValue(json.decode(call.arguments[Argument.error]));
    }

    switch (call.method) {
      case IncomingMethod.didUpdateProfile:
        _didUpdateProfileController.add(decodeProfile());
        return Future.value(null);
      case Method.paywallViewDidPerformAction:
        final action = AdaptyUIActionJSONBuilder.fromJsonValue(json.decode(call.arguments[Argument.action]));
        AdaptyUI()._observer?.paywallViewDidPerformAction(decodeView(), action);
        return Future.value(null);
      case Method.paywallViewDidPerformSystemBackAction:
        AdaptyUI()._observer?.paywallViewDidPerformAction(
              decodeView(),
              const AdaptyUIAction(AdaptyUIActionType.androidSystemBack, null),
            );
        return Future.value(null);
      case Method.paywallViewDidSelectProduct:
        AdaptyUI()._observer?.paywallViewDidSelectProduct(
              decodeView(),
              call.arguments[Argument.productId] as String,
            );
        return Future.value(null);
      case Method.paywallViewDidStartPurchase:
        AdaptyUI()._observer?.paywallViewDidStartPurchase(
              decodeView(),
              decodeProduct(),
            );
        return Future.value(null);
      case Method.paywallViewDidCancelPurchase:
        AdaptyUI()._observer?.paywallViewDidCancelPurchase(
              decodeView(),
              decodeProduct(),
            );
        return Future.value(null);
      case Method.paywallViewDidFinishPurchase:
        AdaptyUI()._observer?.paywallViewDidFinishPurchase(
              decodeView(),
              decodeProduct(),
              decodeProfile(),
            );
        return Future.value(null);
      case Method.paywallViewDidFailPurchase:
        AdaptyUI()._observer?.paywallViewDidFailPurchase(
              decodeView(),
              decodeProduct(),
              decodeError(),
            );
        return Future.value(null);
      case Method.paywallViewDidFinishRestore:
        AdaptyUI()._observer?.paywallViewDidFinishRestore(
              decodeView(),
              decodeProfile(),
            );
        return Future.value(null);
      case Method.paywallViewDidStartRestore:
        AdaptyUI()._observer?.paywallViewDidStartRestore(decodeView());
        return Future.value(null);
      case Method.paywallViewDidFailRestore:
        AdaptyUI()._observer?.paywallViewDidFailRestore(
              decodeView(),
              decodeError(),
            );
        return Future.value(null);
      case Method.paywallViewDidFailRendering:
        AdaptyUI()._observer?.paywallViewDidFailRendering(
              decodeView(),
              decodeError(),
            );
        return Future.value(null);
      case Method.paywallViewDidFailLoadingProducts:
        AdaptyUI()._observer?.paywallViewDidFailLoadingProducts(
              decodeView(),
              decodeError(),
            );
        return Future.value(null);
      default:
        return Future.value(null);
    }
  }
}

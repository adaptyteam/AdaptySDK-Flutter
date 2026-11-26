// ignore_for_file: deprecated_member_use_from_same_package
import 'dart:convert' show json;

import 'adapty_logger.dart';

import 'constants/argument.dart';
import 'constants/method.dart';

import 'models/adapty_error.dart';
import 'models/adapty_external_attribution_provider.dart';
import 'models/adapty_log_level.dart';
import 'models/adapty_onboarding.dart';
import 'models/adapty_product_identifier.dart';
import 'models/adapty_promoted_product.dart';
import 'models/adapty_profile.dart';
import 'models/adapty_flow.dart';
import 'models/adapty_flow_paywall.dart';
import 'models/adapty_flow_fetch_policy.dart';
import 'models/adapty_purchase_parameters.dart';
import 'models/adapty_profile_parameters.dart';
import 'models/adapty_purchase_result.dart';
import 'models/adapty_paywall_product.dart';
import 'models/adapty_sdk_native.dart';
import 'models/adapty_configuration.dart';
import 'models/adapty_error_code.dart';
import 'models/adapty_refund_preference.dart';
import 'models/adapty_installation_details.dart';
import 'models/adapty_customer_identity.dart';
import 'models/adapty_web_presentation.dart';
import 'models/adapty_store_message_type.dart';

import 'adaptyui_observer.dart';
import 'adaptyui_system_requests_handler.dart';
import 'adaptyui_observer_mode_resolver.dart';

import 'models/adaptyui/adaptyui_dialog.dart';
import 'models/adaptyui/adaptyui_ios_presentation_style.dart';
import 'models/adaptyui/adaptyui_onboarding_view.dart';
import 'models/adaptyui/adaptyui_flow_view.dart';

import 'models/custom_assets/adaptyui_custom_assets.dart';

import 'models/private/json_builder.dart';
import 'adapty_version.dart';
import 'runtime/adapty_internal_error_sink.dart';
import 'runtime/adapty_runtime.dart';
import 'runtime/bridge.dart';
import 'runtime/event_dispatcher.dart';

part 'adaptyui.dart';

class Adapty {
  static final Adapty _instance = Adapty._internal();

  factory Adapty() => _instance;

  Adapty._internal();

  static String get sdkVersion => adaptySDKVersion;

  Stream<AdaptyProfile> get didUpdateProfileStream => AdaptyRuntime.current.core.profileUpdates.stream;

  /// A broadcast stream of App Store promoted purchases: products the user starts buying from your
  /// App Store page. iOS 16.4 or later; it never emits in observer mode.
  ///
  /// While at least one subscription to it is active, complete each purchase with
  /// [makePromotedPurchase], or it never happens; with none, the SDK completes it itself, and
  /// cancelling the last subscription also completes each purchase no subscription has received
  /// yet. To catch a purchase delivered at launch, subscribe before [activate].
  Stream<AdaptyPromotedProduct> get didReceivePromotedPurchaseStream =>
      AdaptyRuntime.current.core.promotedPurchasesStream;

  /// A broadcast stream of installation details collected by Adapty Attribution.
  ///
  /// Emits only when Adapty Attribution is enabled with
  /// [AdaptyConfiguration.withAdaptyAttributionEnabled]; it is off by default.
  ///
  /// On iOS, details collected on an earlier launch are delivered during [activate] at every later
  /// launch, so a subscription made once [activate] completes misses them: subscribe before
  /// [activate], or read them with [getCurrentInstallationStatus]. On Android, details from an
  /// earlier launch are not delivered again; read them with [getCurrentInstallationStatus].
  Stream<AdaptyInstallationDetails> get onUpdateInstallationDetailsSuccessStream =>
      AdaptyRuntime.current.core.installationDetailsSuccess.stream;

  /// A broadcast stream of errors from collecting installation details.
  ///
  /// Emits only when Adapty Attribution is enabled with
  /// [AdaptyConfiguration.withAdaptyAttributionEnabled]; it is off by default.
  ///
  /// On iOS, collecting starts during [activate]: subscribe before [activate], as with
  /// [onUpdateInstallationDetailsSuccessStream].
  Stream<AdaptyError> get onUpdateInstallationDetailsFailStream =>
      AdaptyRuntime.current.core.installationDetailsFail.stream;

  /// Returns true if the native SDK is activated and the plugin is activated.
  Future<bool> isActivated() async {
    return await _invokeMethod<bool>(
      NativeMethod.isActivated,
      (data) => data as bool,
      null,
    );
  }

  /// Use this method to initialize the plugin after hot restart. Please check isActivated before calling this method. Don't use this method in release builds.
  /// Until it or [activate] is called, no event of the native side reaches the plugin, for example profile updates,
  /// promoted purchases, installation details and the events of flows and onboardings, the load errors of embedded
  /// flow views included.
  void setupAfterHotRestart() {
    AdaptyLogger.write(AdaptyLogLevel.verbose, 'Adapty.setupAfterHotRestart()');
    final rt = AdaptyRuntime.current;
    rt.setEventHandler((eventName, jsonPayload) => _tryHandleIncomingEvent(rt, eventName, jsonPayload));
  }

  /// Use this method to initialize the Adapty SDK.
  ///
  /// Await it before calling other methods: on iOS, a call sent before the returned `Future`
  /// completes can fail with [AdaptyErrorCode.notActivated] (2002), although activation then
  /// succeeds.
  Future<void> activate({
    required AdaptyConfiguration configuration,
  }) async {
    final rt = AdaptyRuntime.current;
    rt.setEventHandler((eventName, jsonPayload) => _tryHandleIncomingEvent(rt, eventName, jsonPayload));

    // The configuration's level, else the current one (set with setLogLevel, info by default). Sent even when the
    // configuration has none: the native SDKs would fall back to their own defaults, no logs at all on Android.
    final logLevel = configuration.logLevelIfSet ?? AdaptyLogger.logLevel;
    // Set before the call, so that the call's own log lines already use it.
    AdaptyLogger.logLevel = logLevel;

    await _invokeMethod<void>(
      NativeMethod.activate,
      (data) => null,
      {
        Argument.configuration: configuration.jsonValueWithLogLevel(logLevel),
      },
    );
  }

  /// Set to the most appropriate level of logging.
  ///
  /// You can call it before [activate]: [activate] keeps this level unless the configuration
  /// sets one with [AdaptyConfiguration.withLogLevel].
  Future<void> setLogLevel(AdaptyLogLevel value) {
    AdaptyLogger.logLevel = value;

    return _invokeMethod<void>(
      NativeMethod.setLogLevel,
      (data) => null,
      {
        Argument.value: value.name,
      },
    );
  }

  /// Returns the current state of the installation details collected by Adapty Attribution.
  ///
  /// Adapty Attribution is off by default; enable it with
  /// [AdaptyConfiguration.withAdaptyAttributionEnabled]. While it is off, the result is
  /// [AdaptyInstallationStatusNotAvailable].
  Future<AdaptyInstallationStatus> getCurrentInstallationStatus() {
    return _invokeMethod<AdaptyInstallationStatus>(
      NativeMethod.getCurrentInstallationStatus,
      (data) {
        final installationDetailsMap = data as Map<String, dynamic>;
        return AdaptyInstallationStatusJSONBuilder.fromJsonValue(installationDetailsMap);
      },
      null,
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
      NativeMethod.getProfile,
      (data) {
        final profileMap = data as Map<String, dynamic>;
        return AdaptyProfileJSONBuilder.fromJsonValue(profileMap);
      },
      null,
    );
  }

  /// You can set optional attributes such as email, phone number, etc, to the user of your app.
  /// You can then use attributes to create user [segments](https://adapty.io/docs/segments) or just view them in CRM.
  ///
  /// **Parameters:**
  /// - [params]: use [AdaptyProfileParametersBuilder] to build this object.
  Future<void> updateProfile(AdaptyProfileParameters params) {
    return _invokeMethod<void>(
      NativeMethod.updateProfile,
      (data) => null,
      {
        Argument.params: params.jsonValue,
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
  /// - [iosAppAccountToken]: iOS App Account Token, a UUID string. On iOS any other value makes [identify] fail with [AdaptyErrorCode.decodingFailed] (2006) and the user is not identified. Android ignores it.
  /// - [androidObfuscatedAccountId]: The obfuscated account identifier (use for Android), [read more](https://developer.android.com/google/play/billing/developer-payload#attribute).
  Future<void> identify(
    String customerUserId, {
    String? iosAppAccountToken,
    String? androidObfuscatedAccountId,
  }) {
    final parameters = AdaptyCustomerIdentity(
      iosAppAccountToken,
      androidObfuscatedAccountId,
    );

    return _invokeMethod<void>(
      NativeMethod.identify,
      (data) => null,
      {
        Argument.customerUserId: customerUserId,
        if (!parameters.isEmpty) Argument.parameters: parameters.jsonValue,
      },
    );
  }

  /// This method enables you to retrieve the paywall from the Default Audience without having to wait for the Adapty SDK to send all the user information required for segmentation to the server.
  ///
  /// **Parameters:**
  /// - [placementId]: the identifier of the desired placement. This is the value you specified when you created the placement in the Adapty Dashboard.
  /// - [locale]: has no effect. Starting with 4.0.0 a flow is localized when its view is built,
  /// so pass the locale to `AdaptyUI.createFlowView` or `AdaptyUIFlowPlatformView` instead.
  /// - [fetchPolicy]: the fetch policy of the paywall.
  ///
  /// **Returns:**
  /// - the [AdaptyFlow] object. This model contains the list of the products ids, flow’s identifier, custom payload, and several other properties.
  Future<AdaptyFlow> getFlowForDefaultAudience({
    required String placementId,
    @Deprecated(
      'Has no effect for flows. Starting Adapty SDK 4.0.0 the locale is applied when the flow view is built — '
      'pass it to AdaptyUI.createFlowView or AdaptyUIFlowPlatformView instead.',
    )
    String? locale,
    AdaptyFlowFetchPolicy? fetchPolicy,
  }) {
    _warnIfFlowLocalePassed(locale, 'getFlowForDefaultAudience');

    return _invokeMethod<AdaptyFlow>(
      NativeMethod.getFlowForDefaultAudience,
      (data) {
        final flowMap = data as Map<String, dynamic>;
        return AdaptyFlowJSONBuilder.fromJsonValue(flowMap);
      },
      {
        Argument.placementId: placementId,
        if (fetchPolicy != null) Argument.fetchPolicy: fetchPolicy.jsonValue,
      },
    );
  }

  /// Adapty allows you remotely configure the products that will be displayed in your app.
  /// This way you don’t have to hardcode the products and can dynamically change offers or run A/B tests without app releases.
  ///
  /// Read more on the [Adapty Documentation](https://adapty.io/docs/fetch-paywalls-and-products-flutter)
  ///
  /// **Parameters:**
  /// - [placementId]: the identifier of the desired placement. This is the value you specified when you created the placement in the Adapty Dashboard.
  /// - [locale]: has no effect. Starting with 4.0.0 a flow is localized when its view is built,
  /// so pass the locale to `AdaptyUI.createFlowView` or `AdaptyUIFlowPlatformView` instead.
  /// - [fetchPolicy]: by default SDK will try to load data from server and will return cached data in case of failure. Otherwise use `.returnCacheDataElseLoad` to return cached data if it exists.
  /// - [loadTimeout]: the timeout for the paywall loading.
  ///
  /// **Returns:**
  /// - the [AdaptyFlow] object. This model contains the list of the products ids, flow’s identifier, custom payload, and several other properties.
  Future<AdaptyFlow> getFlow({
    required String placementId,
    @Deprecated(
      'Has no effect for flows. Starting Adapty SDK 4.0.0 the locale is applied when the flow view is built — '
      'pass it to AdaptyUI.createFlowView or AdaptyUIFlowPlatformView instead.',
    )
    String? locale,
    AdaptyFlowFetchPolicy? fetchPolicy,
    Duration? loadTimeout,
  }) {
    _warnIfFlowLocalePassed(locale, 'getFlow');

    return _invokeMethod<AdaptyFlow>(
      NativeMethod.getFlow,
      (data) {
        final flowMap = data as Map<String, dynamic>;
        return AdaptyFlowJSONBuilder.fromJsonValue(flowMap);
      },
      {
        Argument.placementId: placementId,
        if (fetchPolicy != null) Argument.fetchPolicy: fetchPolicy.jsonValue,
        if (loadTimeout != null) Argument.loadTimeout: loadTimeout.inMilliseconds.toDouble() / 1000.0,
      },
    );
  }

  /// Loads the flows of the given placements into the cache; the future completes once every
  /// placement has loaded or failed. Call it after [activate].
  ///
  /// Only the placement data is cached, not the flow's UI, images or products. [getFlow] returns
  /// the cached flow without a network request only with
  /// [AdaptyFlowFetchPolicy.returnCacheDataElseLoad], or with
  /// [AdaptyFlowFetchPolicy.returnCacheDataIfNotExpiredElseLoad] within its `maxAge`; on a test
  /// device it goes to the network first with every policy. If some placements fail to load, the
  /// call fails with one [AdaptyError], and the ones that loaded stay cached.
  ///
  /// **Parameters:**
  /// - [placementIds]: the identifiers of the placements, as set in the Adapty Dashboard.
  /// - [loadTimeout]: how long to wait for the targeted flows, 5 seconds by default; less than 1
  /// second counts as 1. After that time the flows may be loaded for the default audience instead.
  Future<void> preloadFlows({
    required List<String> placementIds,
    Duration? loadTimeout,
  }) {
    return _invokeMethod<void>(
      NativeMethod.preloadFlows,
      (data) => null,
      {
        Argument.placementIds: placementIds,
        Argument.loadTimeout: (loadTimeout ?? const Duration(seconds: 5)).inMilliseconds.toDouble() / 1000.0,
      },
    );
  }

  /// Loads the flows of the given placements for the default audience ("All Users") into the
  /// cache, as [getFlowForDefaultAudience] fetches them: faster than [preloadFlows], but without
  /// targeting by country, attribution or custom attributes. Otherwise it works as
  /// [preloadFlows]. Call it after [activate].
  ///
  /// **Parameters:**
  /// - [placementIds]: the identifiers of the placements, as set in the Adapty Dashboard.
  Future<void> preloadFlowsForDefaultAudience({
    required List<String> placementIds,
  }) {
    return _invokeMethod<void>(
      NativeMethod.preloadFlowsForDefaultAudience,
      (data) => null,
      {
        Argument.placementIds: placementIds,
      },
    );
  }

  /// Once you have a [AdaptyFlow], fetch corresponding products array using this method.
  ///
  /// **Parameters:**
  /// - flow: an [AdaptyFlow] for which you want to get a products.
  ///
  /// **Returns:**
  /// - a result containing the [AdaptyPaywallProduct] objects array. You can present them in your UI.
  Future<List<AdaptyPaywallProduct>> getPaywallProducts({
    required AdaptyFlow flow,
  }) {
    return _invokeMethod<List<AdaptyPaywallProduct>>(
      NativeMethod.getPaywallProducts,
      (data) {
        final paywallProductsMap = data as List<dynamic>;
        return paywallProductsMap.map((e) => AdaptyPaywallProductJSONBuilder.fromJsonValue(e)).toList();
      },
      {
        Argument.flow: flow.jsonValue,
      },
    );
  }

  @Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
  Future<AdaptyOnboarding> getOnboarding({
    required String placementId,
    String? locale,
    AdaptyFlowFetchPolicy? fetchPolicy,
    Duration? loadTimeout,
  }) {
    return _invokeMethod<AdaptyOnboarding>(
      NativeMethod.getOnboarding,
      (data) {
        final onboardingMap = data as Map<String, dynamic>;
        return AdaptyOnboardingJSONBuilder.fromJsonValue(onboardingMap);
      },
      {
        Argument.placementId: placementId,
        if (locale != null) Argument.locale: locale,
        if (fetchPolicy != null) Argument.fetchPolicy: fetchPolicy.jsonValue,
        if (loadTimeout != null) Argument.loadTimeout: loadTimeout.inMilliseconds.toDouble() / 1000.0,
      },
    );
  }

  @Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
  Future<AdaptyOnboarding> getOnboardingForDefaultAudience({
    required String placementId,
    String? locale,
    AdaptyFlowFetchPolicy? fetchPolicy,
  }) {
    return _invokeMethod<AdaptyOnboarding>(
      NativeMethod.getOnboardingForDefaultAudience,
      (data) {
        final onboardingMap = data as Map<String, dynamic>;
        return AdaptyOnboardingJSONBuilder.fromJsonValue(onboardingMap);
      },
      {
        Argument.placementId: placementId,
        if (locale != null) Argument.locale: locale,
        if (fetchPolicy != null) Argument.fetchPolicy: fetchPolicy.jsonValue,
      },
    );
  }

  /// To make the purchase, you have to call this method.
  /// Read more on the [Adapty Documentation](https://adapty.io/docs/flutter-making-purchases)
  ///
  /// On iOS, buying a subscription buys the billing plan described by
  /// [AdaptyProductSubscription.pricingTerms]. If that plan can't be bought on this device or
  /// in this storefront, the call fails with an [AdaptyError] with
  /// [AdaptyErrorCode.billingPlanUnavailable].
  ///
  /// **Parameters:**
  /// - [product]: an [AdaptyPaywallProduct] object retrieved from the paywall.
  /// - [parameters]: an [AdaptyPurchaseParameters] object used to pass additional parameters to the purchase.
  ///
  /// **Returns:**
  /// - The [AdaptyPurchaseResult] object. This model contains info about the purchase result.
  Future<AdaptyPurchaseResult> makePurchase({
    required AdaptyPaywallProduct product,
    AdaptyPurchaseParameters? parameters,
  }) {
    return _invokeMethod<AdaptyPurchaseResult>(
      NativeMethod.makePurchase,
      (data) {
        final purchaseResultMap = data as Map<String, dynamic>;
        return AdaptyPurchaseResultJSONBuilder.fromJsonValue(purchaseResultMap);
      },
      {
        Argument.product: product.jsonValue,
        if (parameters != null) Argument.parameters: parameters.jsonValue,
      },
    );
  }

  /// Continue a promoted purchase received from the App Store. iOS only.
  ///
  /// Call this with a product from [didReceivePromotedPurchaseStream]. You need it only while
  /// you have a subscription to that stream: with no subscriber the SDK calls it itself. A
  /// promoted product carries no paywall context, so no purchase parameters are accepted.
  ///
  /// Promoted in-app purchases are an App Store feature; on other platforms
  /// the returned future completes with an error.
  ///
  /// A promoted subscription is always billed up front: its
  /// [AdaptyProductSubscription.pricingTerms] have [AdaptySubscriptionBillingPlan.upFront].
  ///
  /// **Parameters:**
  /// - [product]: an [AdaptyPromotedProduct] object received from [didReceivePromotedPurchaseStream].
  ///
  /// **Returns:**
  /// - The [AdaptyPurchaseResult] object. This model contains info about the purchase result.
  Future<AdaptyPurchaseResult> makePromotedPurchase({
    required AdaptyPromotedProduct product,
  }) {
    return _invokeMethod<AdaptyPurchaseResult>(
      NativeMethod.makePromotedPurchase,
      (data) {
        final purchaseResultMap = data as Map<String, dynamic>;
        return AdaptyPurchaseResultJSONBuilder.fromJsonValue(purchaseResultMap);
      },
      {
        Argument.product: product.jsonValue,
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
      NativeMethod.restorePurchases,
      (data) {
        final profileMap = data as Map<String, dynamic>;
        return AdaptyProfileJSONBuilder.fromJsonValue(profileMap);
      },
      null,
    );
  }

  /// You can set integration identifiers for the profile, using method.
  ///
  /// **Parameters:**
  /// - [key]: a identifier of the integration.
  /// - [value]: a value of the integration identifier.
  Future<void> setIntegrationIdentifier({
    required String key,
    required String value,
  }) {
    return _invokeMethod<void>(
      NativeMethod.setIntegrationIdentifiers,
      (data) => null,
      {
        Argument.keyValues: {key: value},
      },
    );
  }

  /// Sends external attribution data for the current profile.
  ///
  /// The method returns after the backend accepts the data for asynchronous
  /// processing. A successful return does not mean that the data has already
  /// been processed or that the profile has already been updated.
  ///
  /// Read more in the [Adapty documentation](https://adapty.io/docs/attribution-integration).
  ///
  /// **Parameters:**
  /// - [attribution]: a map containing attribution (conversion) data.
  /// - [provider]: the external attribution provider.
  Future<void> updateExternalAttribution(
    Map attribution, {
    required AdaptyExternalAttributionProvider provider,
  }) async {
    late final String encodedAttribution;
    try {
      encodedAttribution = json.encode(attribution);
    } catch (error) {
      throw AdaptyError(
        'Failed to encode external attribution data',
        AdaptyErrorCode.wrongParam,
        error.toString(),
      );
    }

    return _invokeMethod<void>(
      NativeMethod.updateExternalAttribution,
      (data) => null,
      {
        Argument.attribution: encodedAttribution,
        Argument.provider: provider.rawValue,
      },
    );
  }

  /// Call this method to notify Adapty SDK, that particular paywall was shown to user.
  ///
  /// Adapty helps you to measure the performance of the paywalls.
  /// We automatically collect all the metrics related to purchases except for paywall views.
  /// This is because only you know when the flow was shown to a customer. Whenever you show a flow to your user, call .logShowFlow(flow: flow) to log the event, and it will be accumulated in the flow metrics.
  /// Read more on the [Adapty Documentation](https://adapty.io/docs/present-remote-config-paywalls-flutter)
  ///
  /// **Parameters:**
  /// - [flow]: An [AdaptyFlow] object.
  Future<void> logShowFlow({required AdaptyFlow flow}) {
    return _invokeMethod<void>(
      NativeMethod.logShowFlow,
      (data) => null,
      {
        Argument.flow: flow.jsonValue,
      },
    );
  }

  /// In Observer mode, Adapty SDK doesn’t know, where the purchase was made from.
  /// If you display products using our [Paywalls](https://adapty.io/docs/paywalls) or [A/B Tests](https://adapty.io/docs/ab-tests), you can manually assign variation to the purchase.
  /// After doing this, you’ll be able to see metrics in Adapty Dashboard.
  ///
  /// On iOS, also pass the signed StoreKit 2 transaction as [appleJwsTransaction] when your
  /// purchase library provides it.
  ///
  /// **Parameters:**
  /// - [transactionId]: A string identifier of your purchased transaction [SKPaymentTransaction](https://developer.apple.com/documentation/storekit/skpaymenttransaction) (SK1) or [Transaction](https://developer.apple.com/documentation/storekit/transaction) (SK2) for iOS or string identifier (`purchase.getOrderId()`) of the purchase, where the purchase is an instance of the billing library Purchase class for Android.
  /// - [variationId]: A string identifier of variation. You can get it using the variationId property of AdaptyFlow / AdaptyFlowPaywall.
  /// - [appleJwsTransaction]: iOS only. The JWS (`VerificationResult.jwsRepresentation`) of the
  /// same StoreKit 2 transaction as [transactionId]. Sent as is; ignored on other platforms.
  Future<void> reportTransaction({
    required String transactionId,
    String? variationId,
    String? appleJwsTransaction,
  }) {
    return _invokeMethod<void>(
      NativeMethod.reportTransaction,
      (data) => null,
      {
        Argument.transactionId: transactionId,
        if (variationId != null) Argument.variationId: variationId,
        if (AdaptySDKNative.isIOS && appleJwsTransaction != null) Argument.appleJwsTransaction: appleJwsTransaction,
      },
    );
  }

  /// To set fallback paywalls, use this method. You should pass exactly the same payload you’re getting from Adapty backend. You can copy it from Adapty Dashboard.
  ///
  /// Adapty allows you to provide fallback paywalls that will be used when a user opens the app for the first time and there’s no internet connection or in the rare case when Adapty backend is down and there’s no cache on the device.
  /// Read more on the [Adapty Documentation](https://adapty.io/docs/flutter-use-fallback-paywalls)
  ///
  /// **Parameters:**
  /// - [assetId]: a path to the asset file with fallback paywalls.
  Future<void> setFallback(String assetId) {
    return _invokeMethod<void>(
      NativeMethod.setFallback,
      (data) => null,
      {
        Argument.assetId: assetId,
      },
    );
  }

  /// You can logout the user anytime by calling this method.
  Future<void> logout() {
    return _invokeMethod<void>(NativeMethod.logout, (data) => null, null);
  }

  Future<String> createWebPaywallUrl({
    AdaptyFlowPaywall? paywall,
    AdaptyPaywallProduct? product,
  }) async {
    Map<String, dynamic>? arguments;

    if (paywall != null) {
      arguments = {Argument.paywall: paywall.jsonValue};
    } else if (product != null) {
      arguments = {Argument.product: product.jsonValue};
    } else {
      throw AdaptyError(
        'Either paywall or product parameter must be provided',
        AdaptyErrorCode.wrongParam,
        null,
      );
    }

    return _invokeMethod<String>(
      NativeMethod.createWebPaywallUrl,
      (data) => data as String,
      arguments,
    );
  }

  Future<void> openWebPaywall({
    AdaptyFlowPaywall? paywall,
    AdaptyPaywallProduct? product,
    AdaptyWebPresentation openIn = AdaptyWebPresentation.externalBrowser,
  }) async {
    Map<String, dynamic>? arguments = {Argument.openIn: openIn.jsonValue};

    if (paywall != null) {
      arguments[Argument.paywall] = paywall.jsonValue;
    } else if (product != null) {
      arguments[Argument.product] = product.jsonValue;
    } else {
      throw AdaptyError(
        'Either paywall or product parameter must be provided',
        AdaptyErrorCode.wrongParam,
        null,
      );
    }

    return _invokeMethod<void>(
      NativeMethod.openWebPaywall,
      (data) => null,
      arguments,
    );
  }

  /// Returns the types of the store messages waiting to be shown on iOS 16 or later, each once,
  /// in no particular order. The SDK keeps them only with [AdaptyStoreMessagesHandling.manual],
  /// once [activate] has completed; no event tells you about messages that arrive later.
  ///
  /// On Android it returns `null`: Google Play doesn't report pending messages. Below iOS 16 it
  /// fails with [AdaptyErrorCode.decodingFailed].
  ///
  /// **Returns:**
  /// - the types of the pending messages on iOS, or `null` on Android.
  Future<List<AdaptyStoreMessageType>?> getPendingStoreMessageTypes() {
    if (!AdaptySDKNative.isIOS) return Future.value(null);
    return _invokeMethod<List<AdaptyStoreMessageType>>(
      NativeMethod.getPendingStoreMessageTypes,
      (data) {
        final types = data as List<dynamic>;
        return types.map((type) => AdaptyStoreMessageType(type as String)).toList();
      },
      null,
    );
  }

  /// Shows the pending store messages: App Store messages on iOS 16 or later, Google Play in-app
  /// messages on Android.
  ///
  /// Below iOS 16 it fails with [AdaptyErrorCode.decodingFailed]. On iOS 16 or later it does
  /// nothing unless [AdaptyStoreMessagesHandling.manual] is set and [activate] has completed, and
  /// it fails with [AdaptyErrorCode.operationInProgress] when it has messages to show while another
  /// call is showing messages, or with [AdaptyErrorCode.resolverFailure] when no window scene is in
  /// the foreground. On Android, once [activate] is called, it asks Google Play in either mode,
  /// returns at once and never fails; with [AdaptyStoreMessagesHandling.auto], call it once after
  /// [activate] to show the messages at launch, on Android only.
  ///
  /// **Parameters:**
  /// - [iosFilter]: the message types to show on iOS: omit it for all, pass an empty list for none.
  /// Ignored on Android.
  Future<void> showStoreMessages({
    List<AdaptyStoreMessageType>? iosFilter,
  }) {
    return _invokeMethod<void>(
      NativeMethod.showStoreMessages,
      (data) => null,
      {
        if (AdaptySDKNative.isIOS && iosFilter != null) Argument.filter: iosFilter.map((type) => type.value).toList(),
      },
    );
  }

  // ––––––– IOS ONLY METHODS –––––––

  Future<void> updateCollectingRefundDataConsent(bool consent) {
    if (!AdaptySDKNative.isIOS) return Future.value();
    return _invokeMethod<void>(
      NativeMethod.updateCollectingRefundDataConsent,
      (data) => null,
      {
        Argument.consent: consent,
      },
    );
  }

  Future<void> updateRefundPreference(AdaptyRefundPreference refundPreference) {
    if (!AdaptySDKNative.isIOS) return Future.value();
    return _invokeMethod<void>(
      NativeMethod.updateRefundPreference,
      (data) => null,
      {Argument.refundPreference: refundPreference.jsonValue},
    );
  }

  /// Call this method to have StoreKit present a sheet enabling the user to redeem codes provided by your app.
  Future<void> presentCodeRedemptionSheet() {
    if (!AdaptySDKNative.isIOS) return Future.value();
    return _invokeMethod<void>(NativeMethod.presentCodeRedemptionSheet, (data) => null, null);
  }

  // ––––––– INTERNAL –––––––

  /// The `locale` argument of the flow-fetching methods is a leftover from 3.x,
  /// where a paywall was localized at fetch time. Since 4.0.0 a flow is localized
  /// when its view is built, so neither iOS nor Android does anything with it.
  /// The annotation alone is not enough — the Dart analyzer does not report
  /// deprecated named parameters at call sites — so warn at runtime instead of
  /// dropping the value silently.
  void _warnIfFlowLocalePassed(String? locale, String method) {
    if (locale == null) return;

    AdaptyLogger.write(
      AdaptyLogLevel.warn,
      'Adapty.$method(locale: "$locale"): the locale is ignored for flows. '
      'Since Adapty SDK 4.0.0 a flow is localized when its view is built — '
      'pass the locale to AdaptyUI.createFlowView or AdaptyUIFlowPlatformView instead.',
    );
  }

  Future<T> _invokeMethod<T>(
    NativeRequest method,
    T Function(dynamic) responseParser,
    Map<String, dynamic>? arguments,
  ) {
    return adaptyInvoke<T>(AdaptyRuntime.current, method, responseParser, arguments);
  }

  Future<dynamic> _tryHandleIncomingEvent(AdaptyRuntime rt, String eventName, String jsonPayload) async {
    try {
      return await rt.runBound(() => const AdaptyEventDispatcher().dispatch(rt, eventName, jsonPayload));
    } on IncomingEventFailure catch (failure) {
      rt.diagnostics.errorSink.report(AdaptyInternalErrorRecord(
        failure.kind,
        failure.error,
        stack: failure.stack,
        context: failure.label ?? eventName,
        correlationId: failure.correlationId,
      ));
      return null;
    } catch (e, s) {
      rt.diagnostics.errorSink.report(AdaptyInternalErrorRecord(
        AdaptyInternalErrorKind.eventDecodeFailed,
        e,
        stack: s,
        context: eventName,
      ));
      return null;
    }
  }
}

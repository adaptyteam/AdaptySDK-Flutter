// The table of calls of the public API that reach the native side, with what each one has to send
// on each platform, written out by hand from the native decoders.
// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/painting.dart' show Color;

import '../../../tool/contract/src/contract_schema.dart';
import '../../../tool/contract/src/corpus.dart';
import '../../support/contract/contract_runtime.dart';
import 'golden_cases.dart';

const ios = ContractPlatform.ios;
const android = ContractPlatform.android;

/// What a case has to send on one platform: the arguments of the channel call as
/// `ContractCall.normalizedArguments` has them, the native decoders they follow ([source]) and the
/// keys a native does not act on ([ignoredBy], JSON Pointer to the platforms that ignore the key).
final class SentRequest {
  const SentRequest(this.arguments, {required this.source, this.ignoredBy = const {}});

  final Map<String, Object?> arguments;

  /// The decoders of the request, `file:line`, per platform (`ios@…`, `android@…`).
  final String source;
  final Map<String, Set<ContractPlatform>> ignoredBy;
}

/// One call of the public API: the channel method it has to reach, the name of the case, what it
/// does and what it has to send on each platform it runs on. A null [SentRequest] is a platform the
/// SDK does not send the method on.
final class ApiCall {
  const ApiCall(this.method, this.caseName, this.call, this.expected);

  final String method;
  final String caseName;
  final Future<void> Function(ContractRuntime rt) call;
  final Map<ContractPlatform, SentRequest?> expected;

  /// `<method>/<case>`, as the baseline names a case.
  String get name => '$method/$caseName';
  Iterable<ContractPlatform> get platforms => expected.keys;
}

/// The same request on both platforms.
Map<ContractPlatform, SentRequest?> _both(SentRequest request) => {ios: request, android: request};

// ---------------------------------------------------------------------------------------------
// Sources: the native decoders of each request.

final _iosRef = repositoryRefs.ios;
final _androidRef = repositoryRefs.android;
const _plugin = 'Sources.AdaptyPlugin/Requests';
const _handler = 'crossplatform/src/main/java/com/adapty/internal/crossplatform/AdaptyCallHandler.kt';
const _cross = 'crossplatform/src/main/java/com/adapty/internal/crossplatform';

String _decoders(String ios, String? android) =>
    '$_iosRef $_plugin/$ios${android == null ? '; android has no branch for it: $_androidRef $_handler:104' : '; $_androidRef $android'}';

String _iosOnly(String ios) => '$_iosRef $_plugin/$ios';

// ---------------------------------------------------------------------------------------------
// What came from the native side and goes back to it.

final _corpus = Corpus.load('.');

Object? _copy(Object? value) => jsonDecode(jsonEncode(value));

/// The `success` value of the case [caseName] of the response of [method] on [platform].
Map<String, Object?> _answer(String method, ContractPlatform platform, {String caseName = 'default'}) {
  final payload = _corpus.fixture(CorpusKind.response, method, caseName, platform)!.payload! as Map<String, Object?>;
  return _copy(payload['success'])! as Map<String, Object?>;
}

/// The flow of the default `get_flow` case of [platform] as it has to go back to the native side:
/// as that native wrote it, except the keys it writes in a variation and never reads back there,
/// which the SDK does not keep:
/// - iOS: `response_created_at` of a variation (written with the placement of the variation,
///   `Sources/Placements/Entities/AdaptyFlowPaywall.swift:89`, `Sources/Placements/Entities/AdaptyPlacement.swift:89`;
///   a flow reads its variations with the placement of the flow, `AdaptyFlowPaywall.swift:55-58`);
/// - Android: `timestamp` of a product of a variation (written from the backend product,
///   `$_cross/AdaptyFlowPaywallTypeAdapterFactory.kt:53-75`; read into `BackendProduct.timestamp`,
///   `adapty/src/main/java/com/adapty/internal/utils/ProductMapper.kt:206`, which nothing uses).
Map<String, Object?> _flowSentBack(ContractPlatform platform) {
  final flow = _answer('get_flow', platform);
  for (final variation in (flow['variations']! as List).cast<Map<String, Object?>>()) {
    switch (platform) {
      case ContractPlatform.ios:
        variation.remove('response_created_at');
      case ContractPlatform.android:
        for (final product in (variation['products']! as List).cast<Map<String, Object?>>()) {
          product.remove('timestamp');
        }
    }
  }
  return flow;
}

/// The first variation of [_flowSentBack], which goes back on its own as the paywall of a web
/// purchase. Read on its own, iOS reads `response_created_at` of the variation into the version
/// of its placement with 0 for a missing one (`Sources/Placements/Entities/AdaptyPlacement.swift:74`),
/// which only the placement cache compares (`Sources/Placements/Storage/PlacementContent+Cache.swift:165`),
/// not the web paywall.
Map<String, Object?> _paywallSentBack(ContractPlatform platform) =>
    (_flowSentBack(platform)['variations']! as List).first as Map<String, Object?>;

final _productDecoders =
    'product: $_iosRef Sources.AdaptyPlugin/Codable/AdaptyPluginPaywallProduct+Codable.swift:24-41; '
    '$_androidRef $_cross/AdaptyPaywallProductTypeAdapterFactory.kt:36-49 (payload_data required, '
    'paywall_product_index, adapty_product_id and flow_product_id moved into it), the rest by reflection '
    'of adapty/src/main/java/com/adapty/models/AdaptyPaywallProduct.kt:24-37';

/// The keys of a product of the response shape the SDK sends back too: iOS does not read them;
/// Android reads the titles and the price into its product model, which the purchase does not use
/// (`adapty/src/main/java/com/adapty/internal/utils/ProductMapper.kt:210-231`), and has no field for
/// `is_family_shareable`.
const _productInResponseShape = [
  'localized_description',
  'localized_title',
  'region_code',
  'is_family_shareable',
  'price',
];

Map<String, Set<ContractPlatform>> _productIgnored(String at, ContractPlatform platform) => {
  for (final key in _productInResponseShape)
    if (platform == ios || key != 'region_code') '$at/$key': {ios, android},
  // Android takes the offer out of a subscription before it reads it
  // (AdaptyProductSubscriptionDetailsTypeAdapterFactory.kt:53), iOS reads it.
  '$at/subscription/offer': {android},
};

/// The product of the default `get_paywall_products` case of [platform] as a purchase sends it.
Map<String, Object?> _productSentBack(ContractPlatform platform) => switch (platform) {
  ContractPlatform.ios => {
    'vendor_product_id': 'com.app.yearly',
    'flow_product_id': 'flow-product-1',
    'adapty_product_id': 'adapty-yearly',
    'paywall_variation_id': 'variation-id',
    'paywall_ab_test_name': 'ab-test',
    'paywall_name': 'Paywall',
    'subscription': {
      'pricing_terms': {'billing_plan_id': 'up_front'},
      'offer': {
        'offer_identifier': {'id': null, 'type': 'introductory'},
      },
    },
    'paywall_product_index': 0,
    'access_level_id': 'premium',
    'product_type': 'annual',
    'localized_description': 'Premium for a year',
    'localized_title': 'Premium',
    'region_code': 'DE',
    'is_family_shareable': false,
    'price': {'amount': 119.88, 'currency_code': 'EUR', 'currency_symbol': '€', 'localized_string': '119,88 €'},
    'web_purchase_url': 'https://example.com/pay',
  },
  ContractPlatform.android => {
    'vendor_product_id': 'com.app.yearly',
    'flow_product_id': 'flow-product-1',
    'adapty_product_id': 'adapty-yearly',
    'paywall_variation_id': 'variation-id',
    'paywall_ab_test_name': 'ab-test',
    'paywall_name': 'Paywall',
    'subscription': {
      'offer': {
        'offer_identifier': {'id': 'intro-offer', 'type': 'introductory'},
      },
    },
    'paywall_product_index': 0,
    'access_level_id': 'premium',
    'product_type': 'annual',
    'localized_description': 'Premium for a year',
    'localized_title': 'Premium',
    'is_family_shareable': false,
    'price': {'amount': 119.88, 'currency_code': 'EUR', 'currency_symbol': '€', 'localized_string': '119,88 €'},
    'payload_data':
        'eyJwcmljZV9hbW91bnRfbWljcm9zIjoxMTk4ODAwMDAsImN1cnJlbmN5X2NvZGUiOiJFVVIiLCJ0\n'
        'eXBlIjoic3VicyIsInN1YnNjcmlwdGlvbl9kYXRhIjp7ImJhc2VfcGxhbl9pZCI6InllYXJseS1i\n'
        'YXNlIiwib2ZmZXJfaWQiOiJpbnRyby1vZmZlciJ9fQ==\n',
    'web_purchase_url': 'https://example.com/pay',
  },
};

// ---------------------------------------------------------------------------------------------
// What the cases call.

Future<AdaptyFlow> _flow() => Adapty().getFlow(placementId: 'placement-id');

Future<AdaptyPaywallProduct> _product() async => (await Adapty().getPaywallProducts(flow: await _flow())).first;

Future<AdaptyUIFlowView> _flowView() async => AdaptyUI().createFlowView(flow: await _flow());

Future<AdaptyUIOnboardingView> _onboardingView() async =>
    AdaptyUI().createOnboardingView(onboarding: await Adapty().getOnboarding(placementId: 'placement-id'));

AdaptyConfiguration _fullConfiguration() => AdaptyConfiguration(apiKey: 'public-key')
  ..withCustomerUserId(
    'user-1',
    iosAppAccountToken: '7f5e0a3c-2b1d-4c8e-9f60-1a2b3c4d5e6f',
    androidObfuscatedAccountId: 'obfuscated-1',
  )
  ..withObserverMode(true)
  ..withAdaptyAttributionEnabled(true)
  ..withAppleIdfaCollectionDisabled(true)
  ..withGoogleAdvertisingIdCollectionDisabled(true)
  ..withGoogleEnablePendingPrepaidPlans(true)
  ..withGoogleLocalAccessLevelAllowed(true)
  ..withIpAddressCollectionDisabled(true)
  ..withAppleClearDataOnBackup(true)
  ..withLogLevel(AdaptyLogLevel.verbose)
  ..withBackendProxyHost('proxy.example.com')
  ..withBackendProxyPort(8080)
  ..withServerCluster(AdaptyServerCluster.eu)
  ..withStoreMessagesHandling(AdaptyStoreMessagesHandling.manual)
  ..withActivateUI(false)
  ..withMediaCacheConfiguration(
    const AdaptyUIMediaCacheConfiguration(
      memoryStorageTotalCostLimit: 1024,
      memoryStorageCountLimit: 10,
      diskStorageSizeLimit: 2048,
    ),
  );

final _purchaseParameters = AdaptyPurchaseParameters(
  subscriptionUpdateParams: const AdaptyAndroidSubscriptionUpdateParameters(
    'com.app.monthly',
    AdaptyAndroidSubscriptionUpdateReplacementMode.chargeProratedPrice,
  ),
  isOfferPersonalized: true,
);

const _purchaseParametersSent = {
  'subscription_update_params': {
    'old_sub_vendor_product_id': 'com.app.monthly',
    'replacement_mode': 'charge_prorated_price',
  },
  'is_offer_personalized': true,
};

const _configurationIgnored = {
  // iOS: Sources/Configuration/AdaptyConfiguration.Builder+Decodable.swift:13-31 has no such keys.
  '/configuration/google_adid_collection_disabled': {ios},
  '/configuration/google_enable_pending_prepaid_plans': {ios},
  '/configuration/google_local_access_level_allowed': {ios},
  // Android: CrossplatformConfigTypeAdapterFactory.kt:33-72 has no such keys.
  '/configuration/apple_idfa_collection_disabled': {android},
  '/configuration/activate_ui': {android},
  // Android reads only the disk limit (AdaptyUIMediaCacheConfigurationDeserializer.kt:18).
  '/configuration/media_cache/memory_storage_total_cost_limit': {android},
  '/configuration/media_cache/memory_storage_count_limit': {android},
};

final _activateDecoders =
    '$_iosRef $_plugin/Request.Activate.swift:20-46, Sources/Configuration/AdaptyConfiguration.Builder+Decodable.swift:13-70, '
    'Sources.AdaptyPlugin/Codable.AdaptyUI/AdaptyUI.Configuration+Decodable.swift:12-41 (media_cache, only with activate_ui); '
    '$_androidRef $_handler:108-134, $_cross/CrossplatformConfigTypeAdapterFactory.kt:33-72, '
    '$_cross/AdaptyUIMediaCacheConfigurationDeserializer.kt:18';

final _profileParametersDecoders =
    '$_iosRef $_plugin/Request.UpdateProfile.swift:17-25, Sources/Profile/Entities/AdaptyProfileParameters.Builder.swift:108-129 '
    '(att_status as an integer or a string, Sources/Profile/Entities/AdaptyProfileParameters.AppTrackingTransparencyStatus.swift:84-93); '
    '$_androidRef $_handler:365-374, $_cross/entities.kt:105-107, adapty/src/main/java/com/adapty/models/AdaptyProfileParameters.kt:6-14';

final _createFlowViewDecoders =
    '$_iosRef $_plugin/Request.AdaptyUICreateFlowView.swift:53-71 (no enable_safe_area_paddings, no product_purchase_parameters); '
    '$_androidRef $_handler:471-482, $_cross/ui/CreateFlowViewArgs.kt:8-19, $_cross/CreateFlowViewArgsTypeAdapterFactory.kt:16-29';

final _webPaywallDecoders =
    '$_iosRef $_plugin/Request.CreateWebPaywallUrl.swift:17-26, $_plugin/Request.OpenWebPaywall.swift:18-29, '
    'paywall: Sources/Placements/Entities/AdaptyFlowPaywall.swift:46-79, Sources/Placements/Entities/AdaptyPlacement.swift:64-75; '
    '$_androidRef $_handler:406-449, $_cross/WebPurchaseArgsTypeAdapterFactory.kt:41-63, '
    '$_cross/AdaptyFlowPaywallTypeAdapterFactory.kt:24-51';

final _flowDecoders =
    'flow: $_iosRef Sources/Placements/Entities/AdaptyFlow.swift:46-83, Sources/Placements/Entities/AdaptyFlowPaywall.swift:55-79; '
    '$_androidRef $_cross/AdaptyFlowTypeAdapterFactory.kt:28-58, $_cross/AdaptyFlowPaywallTypeAdapterFactory.kt:24-51';

final _onboardingDecoders =
    'onboarding: $_iosRef Sources/Placements/Entities/AdaptyOnboarding.swift:56-77; '
    '$_androidRef adapty/src/main/java/com/adapty/models/AdaptyOnboarding.kt:11-19 by reflection, '
    '$_cross/SerializationFieldNamingStrategy.kt:50-61';

// ---------------------------------------------------------------------------------------------

/// Every call of the public API that reaches the native side, by method and case.
final List<ApiCall> apiCalls = [
  // activate
  ApiCall(
    'activate',
    'minimal',
    (rt) => Adapty().activate(configuration: AdaptyConfiguration(apiKey: 'public-key')),
    _both(
      SentRequest(
        {
          'configuration': {
            'api_key': 'public-key',
            'observer_mode': false,
            'adapty_attribution_enabled': false,
            'ip_address_collection_disabled': false,
            'apple_idfa_collection_disabled': false,
            'google_adid_collection_disabled': false,
            'google_enable_pending_prepaid_plans': false,
            'google_local_access_level_allowed': false,
            'log_level': 'info',
            'cross_platform_sdk_name': 'flutter',
            'cross_platform_sdk_version': '<sdk-version>',
            'media_cache': {
              'memory_storage_total_cost_limit': 104857600,
              'memory_storage_count_limit': 2147483647,
              'disk_storage_size_limit': 104857600,
            },
            'activate_ui': true,
          },
        },
        source: _activateDecoders,
        ignoredBy: _configurationIgnored,
      ),
    ),
  ),
  ApiCall('activate', 'full', (rt) => Adapty().activate(configuration: _fullConfiguration()), {
    for (final platform in ContractPlatform.values)
      platform: SentRequest(
        {
          'configuration': {
            'api_key': 'public-key',
            'customer_user_id': 'user-1',
            'customer_identity_parameters': {
              'app_account_token': '7f5e0a3c-2b1d-4c8e-9f60-1a2b3c4d5e6f',
              'obfuscated_account_id': 'obfuscated-1',
            },
            'observer_mode': true,
            'adapty_attribution_enabled': true,
            'ip_address_collection_disabled': true,
            'clear_data_on_backup': true,
            'apple_idfa_collection_disabled': true,
            'google_adid_collection_disabled': true,
            'google_enable_pending_prepaid_plans': true,
            'google_local_access_level_allowed': true,
            'backend_proxy_host': 'proxy.example.com',
            'backend_proxy_port': 8080,
            'log_level': 'verbose',
            'cross_platform_sdk_name': 'flutter',
            'cross_platform_sdk_version': '<sdk-version>',
            'server_cluster': 'eu',
            'store_messages_handling': 'manual',
            'media_cache': {
              'memory_storage_total_cost_limit': 1024,
              'memory_storage_count_limit': 10,
              'disk_storage_size_limit': 2048,
            },
            'activate_ui': false,
          },
        },
        source: _activateDecoders,
        ignoredBy: {
          ..._configurationIgnored,
          '/configuration/clear_data_on_backup': {android},
          '/configuration/backend_proxy_host': {android},
          '/configuration/backend_proxy_port': {android},
          // Sources/Profile/Entities/CustomerIdentityParameters.swift:14-20 reads the token only;
          // CrossplatformConfigTypeAdapterFactory.kt:44-49 the obfuscated id only.
          '/configuration/customer_identity_parameters/obfuscated_account_id': {ios},
          '/configuration/customer_identity_parameters/app_account_token': {android},
          // Without activate_ui iOS does not read the media cache (Request.Activate.swift:36-41).
          '/configuration/media_cache': {ios},
        },
      ),
  }),
  ApiCall(
    'set_log_level',
    'default',
    (rt) => Adapty().setLogLevel(AdaptyLogLevel.verbose),
    _both(
      SentRequest(const {
        'value': 'verbose',
      }, source: _decoders('Request.LogLevel.swift:20-33', '$_handler:186-194, $_cross/entities.kt:64-66')),
    ),
  ),

  // profile
  ApiCall(
    'get_profile',
    'default',
    (rt) => Adapty().getProfile(),
    _both(SentRequest(const {}, source: _decoders('Request.GetProfile.swift:12-17', '$_handler:335-339'))),
  ),
  ApiCall(
    'update_profile',
    'default',
    (rt) {
      final builder = AdaptyProfileParametersBuilder()
        ..setFirstName('John')
        ..setLastName('Appleseed')
        ..setGender(AdaptyProfileGender.male)
        ..setBirthday(DateTime(1990, 5, 17))
        ..setEmail('john@example.com')
        ..setPhoneNumber('+15550001111')
        ..setAnalyticsDisabled(false)
        ..setCustomStringAttribute('gold', 'tier')
        ..setCustomDoubleAttribute(3.5, 'score');
      return Adapty().updateProfile(builder.build());
    },
    _both(
      SentRequest({
        'params': {
          'first_name': 'John',
          'last_name': 'Appleseed',
          'gender': 'm',
          'birthday': '1990-05-17',
          'email': 'john@example.com',
          'phone_number': '+15550001111',
          'custom_attributes': {'tier': 'gold', 'score': 3.5},
          'analytics_disabled': false,
        },
      }, source: _profileParametersDecoders),
    ),
  ),
  ApiCall(
    'update_profile',
    'att_status',
    (rt) => Adapty().updateProfile(
      (AdaptyProfileParametersBuilder()
            ..setAppTrackingTransparencyStatus(AdaptyIOSAppTrackingTransparencyStatus.authorized))
          .build(),
    ),
    {
      // iOS reads the tracking status as its number or as its name.
      ios: SentRequest({
        'params': {'att_status': 'authorized'},
      }, source: _profileParametersDecoders),
      // The SDK does not send the tracking status on Android, which has no field for it.
      android: SentRequest({'params': {}}, source: _profileParametersDecoders),
    },
  ),
  ApiCall(
    'update_profile',
    'remove_custom_attribute',
    (rt) => Adapty().updateProfile((AdaptyProfileParametersBuilder()..removeCustomAttribute('tier')).build()),
    _both(
      SentRequest({
        'params': {
          'custom_attributes': {'tier': null},
        },
      }, source: _profileParametersDecoders),
    ),
  ),
  ApiCall(
    'identify',
    'default',
    (rt) => Adapty().identify('user-1'),
    _both(
      SentRequest(
        const {'customer_user_id': 'user-1'},
        source: _decoders(
          'Request.Identify.swift:18-21',
          '$_handler:175-184, $_cross/IdentifyArgsTypeAdapterFactory.kt:21-36',
        ),
      ),
    ),
  ),
  ApiCall(
    'identify',
    'with_parameters',
    (rt) => Adapty().identify(
      'user-1',
      iosAppAccountToken: '7f5e0a3c-2b1d-4c8e-9f60-1a2b3c4d5e6f',
      androidObfuscatedAccountId: 'obfuscated-1',
    ),
    _both(
      SentRequest(
        const {
          'customer_user_id': 'user-1',
          'parameters': {
            'app_account_token': '7f5e0a3c-2b1d-4c8e-9f60-1a2b3c4d5e6f',
            'obfuscated_account_id': 'obfuscated-1',
          },
        },
        source:
            '${_decoders('Request.Identify.swift:18-21', '$_handler:175-184, $_cross/IdentifyArgsTypeAdapterFactory.kt:21-36')}, '
            'parameters: $_iosRef Sources/Profile/Entities/CustomerIdentityParameters.swift:14-20',
        ignoredBy: const {
          '/parameters/obfuscated_account_id': {ios},
          '/parameters/app_account_token': {android},
        },
      ),
    ),
  ),

  // flows
  ApiCall(
    'get_flow',
    'default',
    (rt) => _flow(),
    _both(SentRequest(const {'placement_id': 'placement-id'}, source: _getFlowDecoders)),
  ),
  ApiCall(
    'get_flow',
    'reload_revalidating_cache_data',
    (rt) =>
        Adapty().getFlow(placementId: 'placement-id', fetchPolicy: AdaptyFlowFetchPolicy.reloadRevalidatingCacheData),
    _both(
      SentRequest(const {
        'placement_id': 'placement-id',
        'fetch_policy': {'type': 'reload_revalidating_cache_data'},
      }, source: _getFlowDecoders),
    ),
  ),
  ApiCall(
    'get_flow',
    'return_cache_data_else_load',
    (rt) => Adapty().getFlow(placementId: 'placement-id', fetchPolicy: AdaptyFlowFetchPolicy.returnCacheDataElseLoad),
    _both(
      SentRequest(const {
        'placement_id': 'placement-id',
        'fetch_policy': {'type': 'return_cache_data_else_load'},
      }, source: _getFlowDecoders),
    ),
  ),
  ApiCall(
    'get_flow',
    'max_age_and_load_timeout',
    (rt) => Adapty().getFlow(
      placementId: 'placement-id',
      fetchPolicy: AdaptyFlowFetchPolicy.returnCacheDataIfNotExpiredElseLoad(
        const Duration(minutes: 1, milliseconds: 500),
      ),
      loadTimeout: const Duration(milliseconds: 2500),
    ),
    _both(
      // Both natives read max_age and load_timeout in seconds.
      SentRequest(const {
        'placement_id': 'placement-id',
        'fetch_policy': {'type': 'return_cache_data_if_not_expired_else_load', 'max_age': 60.5},
        'load_timeout': 2.5,
      }, source: _getFlowDecoders),
    ),
  ),
  ApiCall(
    'get_flow',
    'with_locale',
    (rt) => Adapty().getFlow(placementId: 'placement-id', locale: 'fr'),
    _both(
      // Neither native reads a locale of a flow request.
      SentRequest(const {'placement_id': 'placement-id'}, source: _getFlowDecoders),
    ),
  ),
  ApiCall(
    'get_flow_for_default_audience',
    'default',
    (rt) => Adapty().getFlowForDefaultAudience(placementId: 'placement-id'),
    _both(SentRequest(const {'placement_id': 'placement-id'}, source: _getFlowForDefaultAudienceDecoders)),
  ),
  ApiCall(
    'get_flow_for_default_audience',
    'with_fetch_policy',
    (rt) => Adapty().getFlowForDefaultAudience(
      placementId: 'placement-id',
      fetchPolicy: AdaptyFlowFetchPolicy.returnCacheDataElseLoad,
    ),
    _both(
      SentRequest(const {
        'placement_id': 'placement-id',
        'fetch_policy': {'type': 'return_cache_data_else_load'},
      }, source: _getFlowForDefaultAudienceDecoders),
    ),
  ),
  ApiCall(
    'preload_flows',
    'default',
    (rt) => Adapty().preloadFlows(placementIds: ['placement-a', 'placement-b']),
    _both(
      // Without a timeout the SDK sends its own 5 seconds.
      SentRequest(const {
        'placement_ids': ['placement-a', 'placement-b'],
        'load_timeout': 5.0,
      }, source: _preloadFlowsDecoders),
    ),
  ),
  ApiCall(
    'preload_flows',
    'empty',
    (rt) => Adapty().preloadFlows(placementIds: const []),
    _both(SentRequest(const {'placement_ids': [], 'load_timeout': 5.0}, source: _preloadFlowsDecoders)),
  ),
  ApiCall(
    'preload_flows',
    'with_load_timeout',
    (rt) => Adapty().preloadFlows(placementIds: ['placement-a'], loadTimeout: const Duration(milliseconds: 1500)),
    _both(
      SentRequest(const {
        'placement_ids': ['placement-a'],
        'load_timeout': 1.5,
      }, source: _preloadFlowsDecoders),
    ),
  ),
  ApiCall(
    'preload_flows_for_default_audience',
    'default',
    (rt) => Adapty().preloadFlowsForDefaultAudience(placementIds: ['placement-a']),
    _both(
      SentRequest(
        const {
          'placement_ids': ['placement-a'],
        },
        source: _decoders(
          'Request.PreloadFlowsForDefaultAudience.swift:17-19',
          '$_handler:250-259, $_cross/entities.kt:50-53',
        ),
      ),
    ),
  ),
  ApiCall('get_paywall_products', 'default', (rt) => _product(), {
    for (final platform in ContractPlatform.values)
      platform: SentRequest(
        {'flow': _flowSentBack(platform)},
        source:
            '${_decoders('Request.GetPaywallProducts.swift:17-19', '$_handler:261-270, $_cross/entities.kt:55-57')}; $_flowDecoders',
      ),
  }),
  ApiCall('log_show_flow', 'default', (rt) async => Adapty().logShowFlow(flow: await _flow()), {
    for (final platform in ContractPlatform.values)
      platform: SentRequest(
        {'flow': _flowSentBack(platform)},
        source:
            '${_decoders('Request.LogShowFlow.swift:17-19', '$_handler:196-205, $_cross/entities.kt:72-74')}; $_flowDecoders',
      ),
  }),

  // onboardings
  ApiCall(
    'get_onboarding',
    'default',
    (rt) => Adapty().getOnboarding(placementId: 'placement-id'),
    _both(SentRequest(const {'placement_id': 'placement-id'}, source: _getOnboardingDecoders)),
  ),
  ApiCall(
    'get_onboarding',
    'with_options',
    (rt) => Adapty().getOnboarding(
      placementId: 'placement-id',
      locale: 'fr',
      fetchPolicy: AdaptyFlowFetchPolicy.reloadRevalidatingCacheData,
      loadTimeout: const Duration(seconds: 3),
    ),
    _both(
      SentRequest(const {
        'placement_id': 'placement-id',
        'locale': 'fr',
        'fetch_policy': {'type': 'reload_revalidating_cache_data'},
        'load_timeout': 3.0,
      }, source: _getOnboardingDecoders),
    ),
  ),
  ApiCall(
    'get_onboarding_for_default_audience',
    'default',
    (rt) => Adapty().getOnboardingForDefaultAudience(placementId: 'placement-id'),
    _both(SentRequest(const {'placement_id': 'placement-id'}, source: _getOnboardingForDefaultAudienceDecoders)),
  ),
  ApiCall(
    'get_onboarding_for_default_audience',
    'with_options',
    (rt) => Adapty().getOnboardingForDefaultAudience(
      placementId: 'placement-id',
      locale: 'fr',
      fetchPolicy: AdaptyFlowFetchPolicy.returnCacheDataIfNotExpiredElseLoad(const Duration(seconds: 30)),
    ),
    _both(
      SentRequest(const {
        'placement_id': 'placement-id',
        'locale': 'fr',
        'fetch_policy': {'type': 'return_cache_data_if_not_expired_else_load', 'max_age': 30.0},
      }, source: _getOnboardingForDefaultAudienceDecoders),
    ),
  ),

  // purchases
  ApiCall('make_purchase', 'default', (rt) async => Adapty().makePurchase(product: await _product()), {
    for (final platform in ContractPlatform.values)
      platform: SentRequest(
        {'product': _productSentBack(platform)},
        source: '$_makePurchaseDecoders; $_productDecoders',
        ignoredBy: _productIgnored('/product', platform),
      ),
  }),
  ApiCall(
    'make_purchase',
    'with_parameters',
    (rt) async => Adapty().makePurchase(product: await _product(), parameters: _purchaseParameters),
    {
      for (final platform in ContractPlatform.values)
        platform: SentRequest(
          {'product': _productSentBack(platform), 'parameters': _purchaseParametersSent},
          source:
              '$_makePurchaseDecoders, parameters: $_androidRef $_cross/AdaptyPurchaseParametersTypeAdapterFactory.kt:15-29; '
              '$_productDecoders',
          ignoredBy: {
            ..._productIgnored('/product', platform),
            '/parameters': {ios},
          },
        ),
    },
  ),
  ApiCall(
    'make_promoted_purchase',
    'default',
    (rt) async {
      final promoted = Adapty().didReceivePromotedPurchaseStream.first;
      await rt.native.sendEvent('did_receive_promoted_purchase');
      await Adapty().makePromotedPurchase(product: await promoted);
    },
    {
      // Android never sends a promoted product, so there is nothing to buy there.
      ios: SentRequest(
        const {
          'product': {'purchase_intent_id': 'purchase-intent-1', 'vendor_product_id': 'promoted.product'},
        },
        source:
            '${_iosOnly('Request.MakePromotedPurchase.swift:16-18')}, Sources.AdaptyPlugin/Codable/AdaptyPluginPromotedProduct+Codable.swift:19-25',
      ),
    },
  ),
  ApiCall(
    'restore_purchases',
    'default',
    (rt) => Adapty().restorePurchases(),
    _both(SentRequest(const {}, source: _decoders('Request.RestorePurchases.swift:12', '$_handler:322-326'))),
  ),
  ApiCall(
    'report_transaction',
    'default',
    (rt) => Adapty().reportTransaction(
      transactionId: 'transaction-1',
      variationId: 'variation-id',
      appleJwsTransaction: 'jws-token',
    ),
    {
      ios: SentRequest(const {
        'transaction_id': 'transaction-1',
        'variation_id': 'variation-id',
        'apple_jws_transaction': 'jws-token',
      }, source: _reportTransactionDecoders),
      // The SDK does not send the signed iOS transaction on Android, which does not read it.
      android: SentRequest(const {
        'transaction_id': 'transaction-1',
        'variation_id': 'variation-id',
      }, source: _reportTransactionDecoders),
    },
  ),
  ApiCall(
    'report_transaction',
    'minimal',
    (rt) => Adapty().reportTransaction(transactionId: 'transaction-1'),
    _both(SentRequest(const {'transaction_id': 'transaction-1'}, source: _reportTransactionDecoders)),
  ),

  // web paywalls
  ApiCall(
    'create_web_paywall_url',
    'paywall',
    (rt) async => Adapty().createWebPaywallUrl(paywall: (await _flow()).paywalls.first),
    {
      for (final platform in ContractPlatform.values)
        platform: SentRequest({'paywall': _paywallSentBack(platform)}, source: _webPaywallDecoders),
    },
  ),
  ApiCall('create_web_paywall_url', 'product', (rt) async => Adapty().createWebPaywallUrl(product: await _product()), {
    for (final platform in ContractPlatform.values)
      platform: SentRequest(
        {'product': _productSentBack(platform)},
        source: '$_webPaywallDecoders; $_productDecoders',
        ignoredBy: _productIgnored('/product', platform),
      ),
  }),
  ApiCall(
    'open_web_paywall',
    'paywall',
    (rt) async => Adapty().openWebPaywall(paywall: (await _flow()).paywalls.first),
    {
      for (final platform in ContractPlatform.values)
        platform: SentRequest({
          'open_in': 'browser_out_app',
          'paywall': _paywallSentBack(platform),
        }, source: _webPaywallDecoders),
    },
  ),
  ApiCall(
    'open_web_paywall',
    'product',
    (rt) async => Adapty().openWebPaywall(product: await _product(), openIn: AdaptyWebPresentation.inAppBrowser),
    {
      for (final platform in ContractPlatform.values)
        platform: SentRequest(
          {'open_in': 'browser_in_app', 'product': _productSentBack(platform)},
          source: '$_webPaywallDecoders; $_productDecoders',
          ignoredBy: _productIgnored('/product', platform),
        ),
    },
  ),

  // other calls of the SDK
  ApiCall(
    'update_external_attribution_data',
    'default',
    (rt) => Adapty().updateExternalAttribution({
      'campaign': 'spring',
      'clicks': 3,
    }, provider: AdaptyExternalAttributionProvider.appsflyer),
    _both(
      // Both natives read the attribution as a JSON object in a string.
      SentRequest(
        const {'attribution': '{"campaign":"spring","clicks":3}', 'provider': 'appsflyer'},
        source: _decoders(
          'Request.UpdateExternalAttributionData.swift:18-21',
          '$_handler:354-363, $_cross/UpdateExternalAttributionArgsTypeAdapterFactory.kt:24-37',
        ),
      ),
    ),
  ),
  ApiCall(
    'set_fallback',
    'default',
    (rt) => Adapty().setFallback('assets/fallback.json'),
    _both(
      // iOS reads asset_id with the request the Flutter plugin registers; Android reads asset_id first.
      SentRequest(
        const {'asset_id': 'assets/fallback.json'},
        source: _decoders(
          'Request.SetFallback.swift:33-39 (SetFallbackByAssetId)',
          '$_handler:395-404, $_cross/FileLocationArgsDeserializer.kt:16-28',
        ),
      ),
    ),
  ),
  ApiCall(
    'logout',
    'default',
    (rt) => Adapty().logout(),
    _both(SentRequest(const {}, source: _decoders('Request.Logout.swift:12', '$_handler:451-455'))),
  ),
  ApiCall(
    'is_activated',
    'default',
    (rt) => Adapty().isActivated(),
    _both(SentRequest(const {}, source: _decoders('Request.IsActivated.swift:12', '$_handler:457-459'))),
  ),
  ApiCall(
    'set_integration_identifiers',
    'default',
    (rt) => Adapty().setIntegrationIdentifier(key: 'firebase_app_instance_id', value: 'instance-1'),
    _both(
      // Android takes the first key of the map; the SDK sends one.
      SentRequest(
        const {
          'key_values': {'firebase_app_instance_id': 'instance-1'},
        },
        source: _decoders(
          'Request.SetIntegrationIdentifier.swift:17-19',
          '$_handler:341-352, $_cross/SetIntegrationIdArgsTypeAdapterFactory.kt:26-45',
        ),
      ),
    ),
  ),
  ApiCall(
    'get_current_installation_status',
    'default',
    (rt) => Adapty().getCurrentInstallationStatus(),
    _both(
      SentRequest(const {}, source: _decoders('Request.GetCurrentInstallationStatus.swift:12', '$_handler:389-393')),
    ),
  ),
  ApiCall('get_pending_store_message_types', 'default', (rt) => Adapty().getPendingStoreMessageTypes(), {
    ios: SentRequest(const {}, source: _decoders('Request.GetPendingStoreMessageTypes.swift:15-20', null)),
    android: null,
  }),
  ApiCall(
    'show_store_messages',
    'with_filter',
    (rt) => Adapty().showStoreMessages(
      iosFilter: const [AdaptyStoreMessageType.billingIssue, AdaptyStoreMessageType('storekit_7')],
    ),
    {
      ios: SentRequest(const {
        'filter': ['billing_issue', 'storekit_7'],
      }, source: _showStoreMessagesDecoders),
      // Android reads no arguments of this call; the SDK sends the iOS filter only on iOS.
      android: SentRequest(const {}, source: _showStoreMessagesDecoders),
    },
  ),
  ApiCall(
    'show_store_messages',
    'default',
    (rt) => Adapty().showStoreMessages(),
    _both(SentRequest(const {}, source: _showStoreMessagesDecoders)),
  ),
  ApiCall(
    'update_collecting_refund_data_consent',
    'default',
    (rt) => Adapty().updateCollectingRefundDataConsent(true),
    {
      ios: SentRequest(const {
        'consent': true,
      }, source: _decoders('Request.UpdateCollectingRefundDataConsent.swift:17-19', null)),
      android: null,
    },
  ),
  ApiCall(
    'update_refund_preference',
    'default',
    (rt) => Adapty().updateRefundPreference(AdaptyRefundPreference.grant),
    {
      ios: SentRequest(const {
        'refund_preference': 'grant',
      }, source: _decoders('Request.UpdateRefundPreference.swift:17-19', null)),
      android: null,
    },
  ),
  ApiCall('present_code_redemption_sheet', 'default', (rt) => Adapty().presentCodeRedemptionSheet(), {
    ios: SentRequest(const {}, source: _decoders('Request.PresentCodeRedemptionSheet.swift:12', null)),
    android: null,
  }),

  // flow views
  ApiCall('adapty_ui_create_flow_view', 'default', (rt) => _flowView(), {
    for (final platform in ContractPlatform.values)
      platform: SentRequest(
        {'flow': _flowSentBack(platform), 'preload_products': false, 'enable_safe_area_paddings': true},
        source: '$_createFlowViewDecoders; $_flowDecoders',
        ignoredBy: const {
          '/enable_safe_area_paddings': {ios},
        },
      ),
  }),
  ApiCall(
    'adapty_ui_create_flow_view',
    'full',
    (rt) async => AdaptyUI().createFlowView(
      flow: await _flow(),
      locale: 'fr',
      customLayoutId: 'layout-2',
      loadTimeout: const Duration(milliseconds: 4500),
      preloadProducts: true,
      androidEnableSafeArea: false,
      customTags: const {'USERNAME': 'John'},
      customTimers: {'sale_end': DateTime.utc(2026, 8, 24, 9, 34, 24, 727)},
      customAssets: {
        'brand_color': const AdaptyCustomAsset.color(color: Color(0xFF112233)),
        'hero': const AdaptyCustomAsset.localImageAsset(assetId: 'assets/hero.png'),
        'intro': const AdaptyCustomAsset.localVideoFile(path: '/tmp/intro.mp4'),
      },
    ),
    {
      for (final platform in ContractPlatform.values)
        platform: SentRequest(
          {
            'flow': _flowSentBack(platform),
            'locale': 'fr',
            'custom_layout_id': 'layout-2',
            'preload_products': true,
            'enable_safe_area_paddings': false,
            'load_timeout': 4.5,
            'custom_tags': const {'USERNAME': 'John'},
            'custom_timers': const {'sale_end': '2026-08-24T09:34:24.727Z'},
            'custom_assets': const [
              {'id': 'brand_color', 'type': 'color', 'value': '#112233FF'},
              {'id': 'hero', 'type': 'image', 'asset_id': 'assets/hero.png'},
              {'id': 'intro', 'type': 'video', 'path': '/tmp/intro.mp4'},
            ],
          },
          source:
              '$_createFlowViewDecoders, custom_assets: $_iosRef Sources.AdaptyPlugin/Codable.AdaptyUI/AdaptyUI.AdaptyCustomAssets.Identifiable.swift:29-93; '
              '$_androidRef $_cross/AdaptyCustomAssetTypeAdapterFactory.kt:31-115; $_flowDecoders',
          ignoredBy: const {
            '/enable_safe_area_paddings': {ios},
          },
        ),
    },
  ),
  ApiCall(
    'adapty_ui_create_flow_view',
    'product_purchase_parameters',
    (rt) async => AdaptyUI().createFlowView(
      flow: await _flow(),
      productPurchaseParams: {
        const AdaptyProductIdentifier(vendorProductId: 'com.app.yearly', adaptyProductId: 'adapty-yearly'):
            _purchaseParameters,
      },
    ),
    {
      for (final platform in ContractPlatform.values)
        platform: SentRequest(
          {
            'flow': _flowSentBack(platform),
            'preload_products': false,
            'enable_safe_area_paddings': true,
            'product_purchase_parameters': const {'adapty-yearly': _purchaseParametersSent},
          },
          source: '$_createFlowViewDecoders; $_flowDecoders',
          ignoredBy: const {
            '/enable_safe_area_paddings': {ios},
            '/product_purchase_parameters': {ios},
          },
        ),
    },
  ),
  ApiCall(
    'adapty_ui_present_flow_view',
    'default',
    (rt) async => AdaptyUI().presentFlowView(await _flowView()),
    _both(
      SentRequest(
        const {'id': 'view-1', 'ios_presentation_style': 'full_screen'},
        source: _presentFlowViewDecoders,
        ignoredBy: const {
          '/ios_presentation_style': {android},
        },
      ),
    ),
  ),
  ApiCall(
    'adapty_ui_present_flow_view',
    'page_sheet',
    (rt) async =>
        AdaptyUI().presentFlowView(await _flowView(), iosPresentationStyle: AdaptyUIIOSPresentationStyle.pageSheet),
    _both(
      SentRequest(
        const {'id': 'view-1', 'ios_presentation_style': 'page_sheet'},
        source: _presentFlowViewDecoders,
        ignoredBy: const {
          '/ios_presentation_style': {android},
        },
      ),
    ),
  ),
  ApiCall(
    'adapty_ui_dismiss_flow_view',
    'default',
    (rt) async => AdaptyUI().dismissFlowView(await _flowView()),
    _both(SentRequest(const {'id': 'view-1', 'destroy': true}, source: _dismissFlowViewDecoders)),
  ),
  ApiCall(
    'adapty_ui_dismiss_flow_view',
    'keep',
    (rt) async => AdaptyUI().dismissFlowView(await _flowView(), destroy: false),
    _both(SentRequest(const {'id': 'view-1', 'destroy': false}, source: _dismissFlowViewDecoders)),
  ),
  ApiCall(
    'adapty_ui_destroy_flow_view',
    'default',
    (rt) async => AdaptyUI().destroyFlowView(await _flowView()),
    _both(
      SentRequest(const {
        'id': 'view-1',
      }, source: _decoders('Request.AdaptyUIDestroyFlowView.swift:17-19', '$_handler:511-522, $_cross/ui/args.kt:7')),
    ),
  ),
  ApiCall(
    'adapty_ui_send_app_message',
    'default',
    (rt) async => AdaptyUI().sendAppMessage(await _flowView(), {
      'step': 'welcome',
      'count': 2,
      'tags': ['a'],
    }),
    _both(
      SentRequest(const {
        'id': 'view-1',
        'message_id': '00000000-0000-4000-8000-000000000001',
        'payload': {
          'step': 'welcome',
          'count': 2,
          'tags': ['a'],
        },
      }, source: _decoders('Request.AdaptyUISendAppMessage.swift:18-29', '$_handler:630-646, $_cross/ui/args.kt:11')),
    ),
  ),

  // onboarding views
  ApiCall('adapty_ui_create_onboarding_view', 'default', (rt) => _onboardingView(), {
    for (final platform in ContractPlatform.values)
      platform: SentRequest({
        'onboarding': _answer('get_onboarding', platform),
        'external_urls_presentation': 'browser_in_app',
      }, source: '$_createOnboardingViewDecoders; $_onboardingDecoders'),
  }),
  ApiCall(
    'adapty_ui_create_onboarding_view',
    'without_remote_config',
    (rt) async {
      rt.native.respond('get_onboarding', 'without_remote_config');
      await AdaptyUI().createOnboardingView(
        onboarding: await Adapty().getOnboarding(placementId: 'placement-id'),
        externalUrlsPresentation: AdaptyWebPresentation.externalBrowser,
      );
    },
    _both(
      // The SDK sends remote_config: null for an onboarding without one; both natives read null as
      // none (iOS decodeIfPresent, Sources/Placements/Entities/AdaptyOnboarding.swift:73; Android a
      // nullable field, adapty/src/main/java/com/adapty/models/AdaptyOnboarding.kt:14).
      SentRequest({
        'onboarding': {..._answer('get_onboarding', ios, caseName: 'without_remote_config'), 'remote_config': null},
        'external_urls_presentation': 'browser_out_app',
      }, source: '$_createOnboardingViewDecoders; $_onboardingDecoders'),
    ),
  ),
  ApiCall(
    'adapty_ui_present_onboarding_view',
    'default',
    (rt) async => AdaptyUI().presentOnboardingView(await _onboardingView()),
    _both(
      SentRequest(
        const {'id': 'view-1', 'ios_presentation_style': 'full_screen'},
        source: _decoders(
          'Request.AdaptyUIPresentOnboardingView.swift:18-21',
          '$_handler:537-548, $_cross/ui/args.kt:3',
        ),
        ignoredBy: const {
          '/ios_presentation_style': {android},
        },
      ),
    ),
  ),
  ApiCall(
    'adapty_ui_dismiss_onboarding_view',
    'default',
    (rt) async => AdaptyUI().dismissOnboardingView(await _onboardingView()),
    _both(
      SentRequest(const {
        'id': 'view-1',
        'destroy': true,
      }, source: _decoders('Request.AdaptyUIDismissOnboardingView.swift:18-27', '$_handler:550-562')),
    ),
  ),

  // dialogs, links, reviews
  ApiCall(
    'adapty_ui_show_dialog',
    'default',
    (rt) => AdaptyUI().showDialog(
      'view-1',
      title: 'Leave?',
      content: 'Your progress is kept.',
      primaryActionTitle: 'Stay',
      secondaryActionTitle: 'Leave',
    ),
    _both(
      SentRequest(const {
        'id': 'view-1',
        'configuration': {
          'title': 'Leave?',
          'content': 'Your progress is kept.',
          'default_action_title': 'Stay',
          'secondary_action_title': 'Leave',
        },
      }, source: _showDialogDecoders),
    ),
  ),
  ApiCall(
    'adapty_ui_show_dialog',
    'primary_only',
    (rt) =>
        AdaptyUI().showDialog('view-1', title: 'Leave?', content: 'Your progress is kept.', primaryActionTitle: 'OK'),
    _both(
      SentRequest(const {
        'id': 'view-1',
        'configuration': {'title': 'Leave?', 'content': 'Your progress is kept.', 'default_action_title': 'OK'},
      }, source: _showDialogDecoders),
    ),
  ),
  ApiCall(
    'adapty_ui_open_url',
    'default',
    (rt) => AdaptyUI().openUrl('https://example.com/terms'),
    _both(
      SentRequest(const {'url': 'https://example.com/terms', 'open_in': 'browser_out_app'}, source: _openUrlDecoders),
    ),
  ),
  ApiCall(
    'adapty_ui_open_url',
    'in_app',
    (rt) => AdaptyUI().openUrl('https://example.com/terms', openIn: AdaptyWebPresentation.inAppBrowser),
    _both(
      SentRequest(const {'url': 'https://example.com/terms', 'open_in': 'browser_in_app'}, source: _openUrlDecoders),
    ),
  ),
  ApiCall(
    'adapty_ui_request_app_review',
    'default',
    (rt) => AdaptyUI().requestAppReview(),
    _both(
      SentRequest(const {}, source: _decoders('Request.AdaptyUIRequestAppReview.swift:10-15', '$_handler:612-617')),
    ),
  ),
];

final _getFlowDecoders = _decoders(
  'Request.GetFlow.swift:19-23',
  '$_handler:207-220, $_cross/entities.kt:37-42 (locale read, not used)',
);
final _getFlowForDefaultAudienceDecoders = _decoders(
  'Request.GetFlowForDefaultAudience.swift:18-21',
  '$_handler:222-234, $_cross/entities.kt:44-48',
);
final _preloadFlowsDecoders = _decoders(
  'Request.PreloadFlows.swift:18-21',
  '$_handler:236-248, $_cross/entities.kt:50-53',
);
final _getOnboardingDecoders = _decoders(
  'Request.GetOnboarding.swift:21-26',
  '$_handler:272-286, $_cross/entities.kt:37-42',
);
final _getOnboardingForDefaultAudienceDecoders = _decoders(
  'Request.GetOnboardingForDefaultAudience.swift:19-23',
  '$_handler:288-301, $_cross/entities.kt:44-48',
);
final _makePurchaseDecoders = _decoders(
  'Request.MakePurchase.swift:16-18 (no parameters)',
  '$_handler:303-320, $_cross/entities.kt:76-79',
);
final _reportTransactionDecoders = _decoders(
  'Request.ReportTransaction.swift:19-23',
  '$_handler:376-387, $_cross/entities.kt:90-93 (no apple_jws_transaction)',
);
final _showStoreMessagesDecoders = _decoders(
  'Request.ShowStoreMessage.swift:19-21',
  '$_handler:328-333 (no arguments)',
);
final _presentFlowViewDecoders = _decoders(
  'Request.AdaptyUIPresentFlowView.swift:18-21',
  '$_handler:484-495, $_cross/ui/args.kt:3 (id only)',
);
final _dismissFlowViewDecoders = _decoders(
  'Request.AdaptyUIDismissFlowView.swift:18-21',
  '$_handler:497-509, $_cross/ui/args.kt:5',
);
final _createOnboardingViewDecoders = _decoders(
  'Request.AdaptyUICreateOnboardingView.swift:20-23',
  '$_handler:524-535, $_cross/ui/CreateOnboardingViewArgs.kt:6-9',
);
final _showDialogDecoders = _decoders(
  'Request.AdaptyUIShowDialog.swift:18-21, Sources.AdaptyPlugin/Codable.AdaptyUI/AdaptyUI.DialogConfiguration+Encodable.swift:12-27',
  '$_handler:648-660, $_cross/ui/AdaptyUiDialogConfig.kt:6-11',
);
final _openUrlDecoders = _decoders(
  'Request.AdaptyUIOpenUrl.swift:17-26',
  '$_handler:619-628, $_cross/entities.kt:119-122',
);

// ---------------------------------------------------------------------------------------------
// What the tests of the embedded views share with the table: the same models go into the creation
// parameters of a view as into the request that creates one.

/// The flow of the default `get_flow` case of [platform] as it has to go back to the native side.
Map<String, Object?> flowSentBack(ContractPlatform platform) => _flowSentBack(platform);

/// The onboarding of the default `get_onboarding` case of [platform] as it has to go back to the native side.
Map<String, Object?> onboardingSentBack(ContractPlatform platform) => _answer('get_onboarding', platform);

/// The purchase parameters of the cases with product purchase parameters, and how they are sent.
AdaptyPurchaseParameters get purchaseParameters => _purchaseParameters;
const purchaseParametersSent = _purchaseParametersSent;

/// The decoders of a flow and of an onboarding, per platform.
final flowDecoders = _flowDecoders;
final onboardingDecoders = _onboardingDecoders;

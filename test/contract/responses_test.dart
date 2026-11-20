// What the SDK makes of every response and event of the contract corpus: every key the contract describes is read
// by the model that decodes it, unless it is listed with the reason the SDK leaves it alone.
import 'dart:convert';
import 'dart:io';

import 'package:adapty_flutter/adapty_flutter.dart'
    show
        Adapty,
        AdaptyPaymentMode,
        AdaptyPeriodUnit,
        AdaptyRenewalType,
        AdaptySubscriptionOfferType,
        AdaptyWebPresentation;
import 'package:adapty_flutter/src/constants/method.dart';
import 'package:adapty_flutter/src/models/adapty_error.dart';
import 'package:adapty_flutter/src/models/adapty_flow.dart';
import 'package:adapty_flutter/src/models/adapty_installation_details.dart';
import 'package:adapty_flutter/src/models/adapty_onboarding.dart';
import 'package:adapty_flutter/src/models/adapty_paywall_product.dart';
import 'package:adapty_flutter/src/models/adapty_profile.dart';
import 'package:adapty_flutter/src/models/adapty_promoted_product.dart';
import 'package:adapty_flutter/src/models/adapty_purchase_result.dart';
import 'package:adapty_flutter/src/models/adaptyui/adaptyui_action.dart';
import 'package:adapty_flutter/src/models/adaptyui/adaptyui_dialog.dart';
import 'package:adapty_flutter/src/models/adaptyui/adaptyui_flow_view.dart';
import 'package:adapty_flutter/src/models/adaptyui/adaptyui_onboarding_meta.dart';
import 'package:adapty_flutter/src/models/adaptyui/adaptyui_onboarding_state_updated_params.dart';
import 'package:adapty_flutter/src/models/adaptyui/adaptyui_onboarding_view.dart';
import 'package:adapty_flutter/src/models/adaptyui/adaptyui_onboardings_analytics_event.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/contract_schema.dart';
import '../../tool/contract/src/contract_source.dart';
import '../../tool/contract/src/corpus.dart';
import '../../tool/contract/src/schema_keys.dart';
import '../../tool/contract/src/source_refs.dart';
import '../support/contract/contract_runtime.dart';
import 'support/golden_cases.dart';
import 'support/projections.dart';
import 'support/read_tracking_map.dart';

const ios = ContractPlatform.ios;
const android = ContractPlatform.android;

final _schema = ContractSchema.load('.');
final _corpus = Corpus.load('.');

Object? _payload(CorpusKind kind, String name, String caseName, ContractPlatform platform) =>
    _corpus.fixture(kind, name, caseName, platform)!.payload;

// ---------------------------------------------------------------------------------------------
// How the SDK reads each response and event: by hand, from the parser each call of the public API
// hands the success value to (lib/src/adapty.dart, lib/src/adaptyui.dart) and from the event
// dispatcher (lib/src/runtime/event_dispatcher.dart). The envelope is read as the bridge reads it
// (lib/src/runtime/bridge.dart): the error when there is one, the success value otherwise.

typedef _Read = Object? Function(dynamic value);

Object? _nothing(dynamic value) => null;

/// The model each method decodes its success value into.
final Map<String, _Read> _responseReaders = {
  'activate': _nothing,
  'adapty_ui_create_flow_view': (v) => AdaptyUIFlowViewJSONBuilder.fromJsonValue(v),
  'adapty_ui_create_onboarding_view': (v) => AdaptyUIOnboardingViewJSONBuilder.fromJsonValue(v),
  'adapty_ui_destroy_flow_view': _nothing,
  'adapty_ui_dismiss_flow_view': _nothing,
  'adapty_ui_dismiss_onboarding_view': _nothing,
  'adapty_ui_open_url': _nothing,
  'adapty_ui_present_flow_view': _nothing,
  'adapty_ui_present_onboarding_view': _nothing,
  'adapty_ui_request_app_review': _nothing,
  'adapty_ui_send_app_message': _nothing,
  'adapty_ui_show_dialog': (v) => AdaptyUIDialogActionTypeJSONBuilder.fromJsonValue(v as String),
  'create_web_paywall_url': (v) => v as String,
  'flow_view_did_answer_permission': _nothing,
  'get_current_installation_status': (v) => AdaptyInstallationStatusJSONBuilder.fromJsonValue(v),
  'get_flow': (v) => AdaptyFlowJSONBuilder.fromJsonValue(v),
  'get_flow_for_default_audience': (v) => AdaptyFlowJSONBuilder.fromJsonValue(v),
  'get_onboarding': (v) => AdaptyOnboardingJSONBuilder.fromJsonValue(v),
  'get_onboarding_for_default_audience': (v) => AdaptyOnboardingJSONBuilder.fromJsonValue(v),
  'get_paywall_products': (v) => [for (final p in v as List<dynamic>) AdaptyPaywallProductJSONBuilder.fromJsonValue(p)],
  'get_pending_store_message_types': (v) => [for (final t in v as List<dynamic>) t as String],
  'get_profile': (v) => AdaptyProfileJSONBuilder.fromJsonValue(v),
  'identify': _nothing,
  'is_activated': (v) => v as bool,
  'log_show_flow': _nothing,
  'logout': _nothing,
  'make_promoted_purchase': (v) => AdaptyPurchaseResultJSONBuilder.fromJsonValue(v),
  'make_purchase': (v) => AdaptyPurchaseResultJSONBuilder.fromJsonValue(v),
  'observer_purchase_did_finish': _nothing,
  'observer_purchase_did_start': _nothing,
  'observer_restore_did_finish': _nothing,
  'observer_restore_did_start': _nothing,
  'open_web_paywall': _nothing,
  'preload_flows': _nothing,
  'preload_flows_for_default_audience': _nothing,
  'present_code_redemption_sheet': _nothing,
  'report_transaction': _nothing,
  'restore_purchases': (v) => AdaptyProfileJSONBuilder.fromJsonValue(v),
  'set_fallback': _nothing,
  'set_integration_identifiers': _nothing,
  'set_log_level': _nothing,
  'show_store_messages': _nothing,
  'update_collecting_refund_data_consent': _nothing,
  'update_external_attribution_data': _nothing,
  'update_profile': _nothing,
  'update_refund_preference': _nothing,
};

Object? _readEnvelope(String method, Map<String, dynamic> envelope) => envelope.containsKey('error')
    ? AdaptyErrorJSONBuilder.fromJsonValue(envelope['error'])
    : _responseReaders[method]!(envelope['success']);

AdaptyUIFlowView _view(Map<String, dynamic> e) => AdaptyUIFlowViewJSONBuilder.fromJsonValue(e['view']);
AdaptyUIOnboardingView _onboardingView(Map<String, dynamic> e) =>
    AdaptyUIOnboardingViewJSONBuilder.fromJsonValue(e['view']);
AdaptyUIOnboardingMeta _meta(Map<String, dynamic> e) => AdaptyUIOnboardingMetaJSONBuilder.fromJsonValue(e['meta']);
AdaptyPaywallProduct _product(Map<String, dynamic> e) => AdaptyPaywallProductJSONBuilder.fromJsonValue(e['product']);
AdaptyError _error(Map<String, dynamic> e) => AdaptyErrorJSONBuilder.fromJsonValue(e['error']);
AdaptyProfile _profile(Map<String, dynamic> e) => AdaptyProfileJSONBuilder.fromJsonValue(e['profile']);

/// What the SDK reads from each event.
///
/// The top level of an event is read here as the event dispatcher reads it, not by the dispatcher itself: it takes the
/// event as a JSON string, so its own lookups cannot be tracked without changing it. For the keys of the top level this
/// table is a copy of the dispatcher, and the tracking proves only the models under them; that the dispatcher reads the
/// top level shows in what an event delivers to the app (the event routes) and in the events it cannot read
/// (errors_test.dart). In the same way the model each method decodes is the one the public API hands its success value
/// to; getProfile, getPaywallProducts and the cases the contract rejects go through the public API.
final Map<String, Object? Function(Map<String, dynamic> event)> _eventReaders = {
  'did_load_latest_profile': (e) => _profile(e),
  'did_receive_promoted_purchase': (e) => AdaptyPromotedProductJSONBuilder.fromJsonValue(e['product']),
  'on_installation_details_success': (e) => AdaptyInstallationDetailsJSONBuilder.fromJsonValue(e['details']),
  'on_installation_details_fail': (e) => _error(e),
  'flow_view_did_appear': (e) => _view(e),
  'flow_view_did_disappear': (e) => _view(e),
  'flow_view_did_perform_action': (e) => [_view(e), AdaptyUIActionJSONBuilder.fromJsonValue(e['action'])],
  'flow_view_did_select_product': (e) => [_view(e), e['product_id'] as String],
  'flow_view_did_start_purchase': (e) => [_view(e), _product(e)],
  'flow_view_did_finish_purchase': (e) => [
    _view(e),
    _product(e),
    AdaptyPurchaseResultJSONBuilder.fromJsonValue(e['purchased_result']),
  ],
  'flow_view_did_fail_purchase': (e) => [_view(e), _product(e), _error(e)],
  'flow_view_did_finish_restore': (e) => [_view(e), _profile(e)],
  'flow_view_did_start_restore': (e) => _view(e),
  'flow_view_did_fail_restore': (e) => [_view(e), _error(e)],
  'flow_view_did_receive_error': (e) => [_view(e), _error(e)],
  'flow_view_did_fail_loading_products': (e) => [_view(e), _error(e)],
  'flow_view_did_finish_web_payment_navigation': (e) => [
    _view(e),
    if (e['product'] != null) _product(e),
    if (e['error'] != null) _error(e),
  ],
  'flow_view_did_ask_permission': (e) => [
    e['event_id'] as String,
    _view(e),
    e['permission'] as String,
    (e['custom_args'] as Map?)?.map((key, value) => MapEntry(key as String, value as String)),
  ],
  'flow_view_did_request_app_review': (e) => _view(e),
  'flow_view_did_receive_analytic_event': (e) => [
    e['name'] as String,
    (e['params'] as Map?)?.cast<String, dynamic>(),
    _view(e),
  ],
  'flow_view_observer_did_initiate_purchase': (e) => [e['event_id'] as String, _view(e), _product(e)],
  'flow_view_observer_did_initiate_restore': (e) => [e['event_id'] as String, _view(e)],
  'onboarding_did_finish_loading': (e) => [_onboardingView(e), _meta(e)],
  'onboarding_did_fail_with_error': (e) => [_onboardingView(e), _error(e)],
  'onboarding_on_analytics_action': (e) => [
    _onboardingView(e),
    _meta(e),
    AdaptyOnboardingsAnalyticsEventJSONBuilder.fromJsonValue(e['event']),
  ],
  'onboarding_on_close_action': (e) => [_onboardingView(e), _meta(e), e['action_id'] as String],
  'onboarding_on_custom_action': (e) => [_onboardingView(e), _meta(e), e['action_id'] as String],
  'onboarding_on_paywall_action': (e) => [_onboardingView(e), _meta(e), e['action_id'] as String],
  'onboarding_on_state_updated_action': (e) {
    final action = e['action'] as Map<String, dynamic>;
    return [
      _onboardingView(e),
      _meta(e),
      action['element_id'] as String,
      AdaptyOnboardingsStateUpdatedParamsJSONBuilder.fromJsonValue(action),
    ];
  },
};

final _iosRef = repositoryRefs.ios;
final _androidRef = repositoryRefs.android;

/// The keys the contract describes that the SDK leaves unread, by the property of the schema (`*` stands for one
/// segment), with the platforms whose native writes them, why the SDK leaves them alone and where that shows. A key
/// left unread leaves its whole value unread.
final Map<String, ({Set<ContractPlatform> platforms, String reason, String source})> _notRead = {
  r'#/$events/*/properties/id': (
    platforms: {ios, android},
    reason: 'the SDK takes the event from the name of the channel call, which the native sets to the same id',
    source: 'lib/src/runtime/event_dispatcher.dart:81',
  ),
  r'#/$defs/AdaptyFlowPaywall/properties/placement': (
    platforms: {ios, android},
    reason:
        'a variation of a flow takes the placement of the flow, as the iOS decoder does; the native writes that '
        'placement into each variation',
    source:
        'lib/src/models/private/adapty_flow_paywall_json_builder.dart:23-25; '
        '$_iosRef Sources/Placements/Entities/AdaptyFlowPaywall.swift:55-58,88; '
        '$_androidRef adapty/src/main/java/com/adapty/models/AdaptyFlowPaywall.kt:14',
  ),
  r'#/$defs/AdaptyFlowPaywall/properties/response_created_at': (
    platforms: {ios},
    reason:
        'written with the placement of a variation; the native does not read it back from a variation of a flow '
        'and the SDK keeps the one of the flow',
    source:
        '$_iosRef Sources/Placements/Entities/AdaptyPlacement.swift:89, '
        'Sources/Placements/Entities/AdaptyFlowPaywall.swift:55-58',
  ),
  r'#/$defs/AdaptyFlowPaywall.ProductReference/properties/timestamp': (
    platforms: {android},
    reason: 'written from the backend product; read back into a field nothing uses',
    source:
        '$_androidRef crossplatform/src/main/java/com/adapty/internal/crossplatform/AdaptyFlowPaywallTypeAdapterFactory.kt:53-75, '
        'adapty/src/main/java/com/adapty/internal/utils/ProductMapper.kt:206',
  ),
  r'#/$defs/AdaptyFlowPaywall.ProductReference/properties/pricing_terms/items/properties/promotional_offer_id': (
    platforms: {ios},
    reason:
        'an item of the pricing terms is kept as the native wrote it and sent back with the product; only its '
        'billing plan is read',
    source: 'lib/src/models/private/product_reference_json_builder.dart:56-66',
  ),
  r'#/$defs/AdaptyFlowPaywall.ProductReference/properties/pricing_terms/items/properties/win_back_offer_id': (
    platforms: {ios},
    reason:
        'an item of the pricing terms is kept as the native wrote it and sent back with the product; only its '
        'billing plan is read',
    source: 'lib/src/models/private/product_reference_json_builder.dart:56-66',
  ),
  r'#/$defs/AdaptyProfile.AccessLevel/properties/renewal_info_signed_at': (
    platforms: {ios},
    reason:
        'not in the contract: a schema fix adds what the native writes; the access level of the SDK has no such '
        'field',
    source:
        '$_iosRef Sources/Profile/Entities/AdaptyProfile.AccessLevel.swift:98,146; contract/overlays/schema_fixes.yaml',
  ),
  r'#/$defs/AdaptyProduct.Subscription/properties/offer_id': (
    platforms: {android},
    reason:
        'not in the contract at this level: the native moves the offer into `offer` only when it has phases and '
        'leaves it here otherwise; the SDK reads an offer only from `offer`',
    source:
        '$_androidRef crossplatform/src/main/java/com/adapty/internal/crossplatform/AdaptyProductSubscriptionDetailsTypeAdapterFactory.kt:31-47; '
        'contract/overlays/schema_fixes.yaml',
  ),
  r'#/$defs/AdaptyProduct.Subscription/properties/offer_tags': (
    platforms: {android},
    reason:
        'not in the contract at this level: the native moves the offer tags into `offer` only when it has phases '
        'and leaves them here otherwise; the SDK reads them only from `offer`',
    source:
        '$_androidRef crossplatform/src/main/java/com/adapty/internal/crossplatform/AdaptyProductSubscriptionDetailsTypeAdapterFactory.kt:31-47; '
        'contract/overlays/schema_fixes.yaml',
  ),
};

/// The row of [_notRead] for the property at [pointer], if any.
String? _notReadRow(String pointer) {
  for (final row in _notRead.keys) {
    final pattern = RegExp('^${row.split('*').map(RegExp.escape).join('[^/]+')}\$');
    if (pattern.hasMatch(pointer)) return row;
  }
  return null;
}

/// What the SDK reads of [fixture] on [platform]: the keys the contract describes, the keys looked up, and the rows of
/// [_notRead] that let a key go unread.
({List<String> unread, Set<String> rowsUsed}) _readKeys(CorpusFixture fixture, ContractPlatform platform) {
  final entry = switch (fixture.kind) {
    CorpusKind.response => _schema.responseEntry(fixture.name),
    CorpusKind.event => _schema.eventEntry(fixture.name),
    CorpusKind.request => throw ArgumentError.value(fixture, 'fixture', 'a request is not read by the SDK'),
  };
  final keys = schemaKeys(entry, fixture.payload, platform);
  final tracker = ReadTracker();
  final payload = tracker.track(fixture.payload)! as Map<String, dynamic>;
  switch (fixture.kind) {
    case CorpusKind.response:
      _readEnvelope(fixture.name, payload);
    case CorpusKind.event:
      _eventReaders[fixture.name]!(payload);
    case CorpusKind.request:
  }
  final unread = keys.described.difference(tracker.read);
  // A key the list lets go unread on this platform, and so everything under it.
  final leftAlone = <String, String>{
    for (final key in unread)
      if (_notReadRow(keys.pointers[key]!) case final row? when _notRead[row]!.platforms.contains(platform)) key: row,
  };
  bool under(String key) => leftAlone.keys.any((top) => key == top || key.startsWith('$top/'));
  return (
    unread: [
      for (final key in unread)
        if (!under(key)) '$key (${keys.pointers[key]})',
    ]..sort(),
    rowsUsed: leftAlone.values.toSet(),
  );
}

/// The platforms a fixture is a case of: its own, or every platform that answers the method or sends the event.
Set<ContractPlatform> _platformsOf(CorpusFixture fixture) => switch (fixture.platform) {
  final ContractPlatform platform => {platform},
  null => switch (fixture.kind) {
    CorpusKind.response => _schema.methodPlatforms[fixture.name]!,
    CorpusKind.event => _schema.eventPlatforms[fixture.name]!,
    CorpusKind.request => const {},
  },
};

// ---------------------------------------------------------------------------------------------
// What an app gets from the default cases, written out by hand from the fixtures: dates as the instants the native
// wrote, units and modes as their values, what a platform does not write as the value the SDK documents for it.

final _aug24 = DateTime.utc(2026, 8, 24, 9, 34, 24, 727);
final _sep24 = DateTime.utc(2026, 9, 24, 9, 34, 24, 727);

Map<String, Object?> _accessLevel({required String store, String? offerId}) => {
  'id': 'premium',
  'isActive': true,
  'vendorProductId': 'com.app.yearly',
  'store': store,
  'activatedAt': _aug24,
  'renewedAt': _aug24,
  'expiresAt': _sep24,
  'isLifetime': false,
  'activeIntroductoryOfferType': 'free_trial',
  'activePromotionalOfferType': null,
  'activePromotionalOfferId': null,
  'offerId': offerId,
  'willRenew': true,
  'isInGracePeriod': false,
  'unsubscribedAt': _sep10,
  'billingIssueDetectedAt': _sep12,
  'startsAt': _aug24,
  'cancellationReason': null,
  'isRefund': true,
  'billingPlan': 'up_front',
  'commitmentInfo': null,
};

Map<String, Object?> _subscription({required String store}) => {
  'store': store,
  'vendorProductId': 'com.app.yearly',
  'vendorTransactionId': 'transaction-2',
  'vendorOriginalTransactionId': 'transaction-1',
  'isActive': true,
  'isLifetime': false,
  'activatedAt': _aug24,
  'renewedAt': _aug24,
  'expiresAt': _sep24,
  'startsAt': _aug24,
  'unsubscribedAt': _sep10,
  'billingIssueDetectedAt': _sep12,
  'isInGracePeriod': true,
  'isSandbox': true,
  'isRefund': false,
  'willRenew': true,
  'activeIntroductoryOfferType': 'free_trial',
  'activePromotionalOfferType': null,
  'activePromotionalOfferId': null,
  'offerId': null,
  'cancellationReason': null,
  'billingPlan': 'up_front',
  'commitmentInfo': null,
};

Map<String, Object?> _coins({required String store}) => {
  'purchaseId': 'purchase-1',
  'store': store,
  'vendorProductId': 'com.app.coins',
  'vendorTransactionId': 'transaction-3',
  'purchasedAt': _aug24,
  'isSandbox': false,
  'isRefund': false,
  'isConsumable': true,
};

/// A double equal to [value]; a whole number as an int does not match.
Matcher _double(num value) => allOf(isA<double>(), value.toDouble());

final _profileIos = {
  'profileId': 'profile-1',
  'customerUserId': 'user-1',
  // A number reaches the app as a double on both platforms, whether the native side writes it whole or not.
  'customAttributes': {'plan': 'pro', 'age': _double(30)},
  'accessLevels': {'premium': _accessLevel(store: 'app_store')},
  'subscriptions': {'com.app.yearly': _subscription(store: 'app_store')},
  'nonSubscriptions': {
    'com.app.coins': [_coins(store: 'app_store')],
  },
  'appliedExternalAttributionProviders': ['apple_search_ads'],
  'isTestUser': false,
};

final _profileAndroid = {
  'profileId': 'profile-1',
  'customerUserId': 'user-1',
  'customAttributes': {'plan': 'pro', 'age': _double(30)},
  'accessLevels': {'premium': _accessLevel(store: 'play_store', offerId: 'intro-offer')},
  'subscriptions': {'com.app.yearly': _subscription(store: 'play_store')},
  'nonSubscriptions': {
    'com.app.coins': [_coins(store: 'play_store')],
  },
  'appliedExternalAttributionProviders': <Object?>[],
  'isTestUser': false,
};

final _sep10 = DateTime.utc(2026, 9, 10, 9, 34, 24, 727);
final _sep12 = DateTime.utc(2026, 9, 12, 9, 34, 24, 727);

/// What the full profiles add to an access level and a subscription: every optional field the native writes when set.
final _optionalFields = {
  'activePromotionalOfferType': 'pay_up_front',
  'activePromotionalOfferId': 'promo-offer-1',
  'offerId': 'promo-offer-1',
  'willRenew': false,
  'cancellationReason': 'voluntarily_cancelled',
  'billingPlan': 'monthly',
  'commitmentInfo': {
    'billingPeriodNumber': 1,
    'totalBillingPeriods': 12,
    'expiresAt': DateTime.utc(2027, 8, 24, 9, 34, 24, 727),
  },
};

final _profileFullIos = {
  ..._profileIos,
  // A custom attribute the native keeps without a value reaches the app as null.
  'customAttributes': {'plan': 'pro', 'age': _double(30), 'removed': null},
  'accessLevels': {
    'premium': {..._accessLevel(store: 'app_store'), ..._optionalFields},
  },
  'subscriptions': {
    'com.app.yearly': {..._subscription(store: 'app_store'), ..._optionalFields},
  },
};

final _profileFullAndroid = {
  ..._profileAndroid,
  'accessLevels': {
    'premium': {..._accessLevel(store: 'app_store'), ..._optionalFields},
  },
  'subscriptions': {
    'com.app.yearly': {..._subscription(store: 'app_store'), ..._optionalFields},
  },
  'appliedExternalAttributionProviders': ['adjust'],
};

Map<String, Object?> _eur(double amount, String localized) => {
  'amount': amount,
  'currencyCode': 'EUR',
  'currencySymbol': '€',
  'localizedString': localized,
};

const _year = {'unit': AdaptyPeriodUnit.year, 'numberOfUnits': 1};
const _month = {'unit': AdaptyPeriodUnit.month, 'numberOfUnits': 1};

Map<String, Object?> _yearlyProduct({
  required bool isFamilyShareable,
  required String? regionCode,
  required Map<String, Object?> subscription,
}) => {
  'vendorProductId': 'com.app.yearly',
  'flowProductId': 'flow-product-1',
  'accessLevelId': 'premium',
  'productType': 'annual',
  'paywallVariationId': 'variation-id',
  'paywallABTestName': 'ab-test',
  'paywallName': 'Paywall',
  'localizedDescription': 'Premium for a year',
  'localizedTitle': 'Premium',
  'isFamilyShareable': isFamilyShareable,
  'regionCode': regionCode,
  'price': _eur(119.88, '119,88 €'),
  'subscription': subscription,
  'paywallProductIndex': 0,
};

Map<String, Object?> _introPhase() => {
  'price': _eur(4.99, '4,99 €'),
  'numberOfPeriods': 3,
  'paymentMode': AdaptyPaymentMode.payAsYouGo,
  'subscriptionPeriod': _month,
  'localizedSubscriptionPeriod': '1 month',
  'localizedNumberOfPeriods': '3 months',
  'identifier': null,
};

final _productIos = _yearlyProduct(
  isFamilyShareable: false,
  regionCode: 'DE',
  subscription: {
    'groupIdentifier': 'group-1',
    'period': _year,
    'localizedPeriod': '1 year',
    'offer': {
      'identifier': {'id': null, 'type': AdaptySubscriptionOfferType.introductory},
      'phases': [_introPhase()],
      'offerTags': null,
    },
    'renewalType': AdaptyRenewalType.autorenewable,
    'basePlanId': null,
    'pricingTerms': {
      'billingPlan': 'up_front',
      'billingPrice': _eur(119.88, '119,88 €'),
      'billingPeriod': _year,
      'commitmentInfo': {'price': _eur(119.88, '119,88 €'), 'period': _year},
    },
  },
);

final _productAndroid = _yearlyProduct(
  isFamilyShareable: false,
  regionCode: null,
  subscription: {
    'groupIdentifier': null,
    'period': _year,
    'localizedPeriod': '1 year',
    'offer': {
      'identifier': {'id': 'intro-offer', 'type': AdaptySubscriptionOfferType.introductory},
      'phases': [_introPhase()],
      'offerTags': ['intro'],
    },
    'renewalType': AdaptyRenewalType.autorenewable,
    'basePlanId': 'yearly-base',
    'pricingTerms': null,
  },
);

const _placement = {
  'id': 'placement-id',
  'audienceName': 'All Users',
  'revision': 1,
  'abTestName': 'ab-test',
  'placementAudienceVersionId': 'audience-version-1',
  'isTrackingPurchases': true,
};

Map<String, Object?> _flow({required String? basePlanId}) => {
  'placement': _placement,
  'instanceIdentity': 'flow-1',
  'name': 'Flow',
  'variationId': 'variation-id',
  'variationName': 'Variation A',
  'remoteConfigs': [
    {
      'locale': 'en',
      'data': '{"title":"Hello"}',
      'dictionary': {'title': 'Hello'},
    },
  ],
  'paywalls': [
    {
      'placement': _placement,
      'instanceIdentity': 'paywall-1',
      'name': 'Paywall',
      'variationId': 'variation-id',
      'productIdentifiers': [
        {'vendorProductId': 'com.app.yearly', 'basePlanId': basePlanId},
      ],
    },
  ],
  'hasViewConfiguration': true,
  'productIdentifiers': [
    {'vendorProductId': 'com.app.yearly', 'basePlanId': basePlanId},
  ],
};

const _placementNotTracking = {
  'id': 'placement-id',
  'audienceName': 'All Users',
  'revision': 1,
  'abTestName': 'ab-test',
  'placementAudienceVersionId': 'audience-version-1',
  'isTrackingPurchases': false,
};

/// A flow with only what a native always writes: no variation name, remote config, layouts, tracking or web purchase.
Map<String, Object?> _minimalFlow({required String? basePlanId, required bool hasViewConfiguration}) => {
  'placement': _placementNotTracking,
  'instanceIdentity': 'flow-1',
  'name': 'Flow',
  'variationId': 'variation-id',
  'variationName': null,
  'remoteConfigs': <Object?>[],
  'paywalls': [
    {
      'placement': _placementNotTracking,
      'instanceIdentity': 'paywall-1',
      'name': 'Paywall',
      'variationId': 'variation-id',
      'productIdentifiers': [
        {'vendorProductId': 'com.app.yearly', 'basePlanId': basePlanId},
      ],
    },
  ],
  'hasViewConfiguration': hasViewConfiguration,
  'productIdentifiers': [
    {'vendorProductId': 'com.app.yearly', 'basePlanId': basePlanId},
  ],
};

/// The cases of the models whose values the SDK turns into something else, and what an app has to get.
final List<
  ({String method, String caseName, ContractPlatform platform, Object? Function(Object?) project, Object? expected})
>
_projected = [
  (method: 'get_profile', caseName: 'default', platform: ios, project: _profileOf, expected: _profileIos),
  (method: 'get_profile', caseName: 'default', platform: android, project: _profileOf, expected: _profileAndroid),
  (method: 'get_paywall_products', caseName: 'default', platform: ios, project: _productsOf, expected: [_productIos]),
  (
    method: 'get_paywall_products',
    caseName: 'default',
    platform: android,
    project: _productsOf,
    expected: [_productAndroid],
  ),
  (
    method: 'get_paywall_products',
    caseName: 'other_offers',
    platform: ios,
    project: _offerValuesOf,
    expected: [
      {
        'vendorProductId': 'com.app.monthly',
        'period': {'unit': AdaptyPeriodUnit.month, 'numberOfUnits': 1},
        'localizedPeriod': '1 month',
        'renewalType': AdaptyRenewalType.autorenewable,
        'offer': {
          'type': AdaptySubscriptionOfferType.promotional,
          'id': 'promo-1',
          'phases': [
            {
              'price': 4.99,
              'paymentMode': AdaptyPaymentMode.payAsYouGo,
              'numberOfPeriods': 3,
              'subscriptionPeriod': {'unit': AdaptyPeriodUnit.month, 'numberOfUnits': 1},
              'localizedSubscriptionPeriod': '1 month',
              'localizedNumberOfPeriods': '3 months',
            },
          ],
        },
      },
      {
        'vendorProductId': 'com.app.quarterly',
        'period': {'unit': AdaptyPeriodUnit.month, 'numberOfUnits': 3},
        'localizedPeriod': '3 months',
        'renewalType': AdaptyRenewalType.autorenewable,
        'offer': {
          'type': AdaptySubscriptionOfferType.winBack,
          'id': 'win-back-1',
          'phases': [
            {
              'price': 14.99,
              'paymentMode': AdaptyPaymentMode.payUpFront,
              'numberOfPeriods': 1,
              'subscriptionPeriod': {'unit': AdaptyPeriodUnit.month, 'numberOfUnits': 3},
              'localizedSubscriptionPeriod': '3 months',
              'localizedNumberOfPeriods': '3 months',
            },
          ],
        },
      },
      {
        'vendorProductId': 'com.app.weekly',
        'period': {'unit': AdaptyPeriodUnit.week, 'numberOfUnits': 1},
        'localizedPeriod': '1 week',
        'renewalType': AdaptyRenewalType.autorenewable,
        'offer': {
          'type': AdaptySubscriptionOfferType.introductory,
          'id': null,
          'phases': [
            {
              'price': 0.0,
              'paymentMode': AdaptyPaymentMode.freeTrial,
              'numberOfPeriods': 1,
              'subscriptionPeriod': {'unit': AdaptyPeriodUnit.day, 'numberOfUnits': 3},
              'localizedSubscriptionPeriod': '3 days',
              'localizedNumberOfPeriods': '3 days',
            },
          ],
        },
      },
      {
        'vendorProductId': 'com.app.other',
        'period': {'unit': AdaptyPeriodUnit.unknown, 'numberOfUnits': 1},
        'localizedPeriod': null,
        'renewalType': AdaptyRenewalType.autorenewable,
        'offer': {
          'type': AdaptySubscriptionOfferType.introductory,
          'id': null,
          'phases': [
            {
              'price': 1.99,
              'paymentMode': AdaptyPaymentMode.unknown,
              'numberOfPeriods': 1,
              'subscriptionPeriod': {'unit': AdaptyPeriodUnit.unknown, 'numberOfUnits': 1},
              'localizedSubscriptionPeriod': null,
              'localizedNumberOfPeriods': null,
            },
          ],
        },
      },
    ],
  ),
  (
    method: 'get_paywall_products',
    caseName: 'other_offers',
    platform: android,
    project: _offerValuesOf,
    expected: [
      {
        'vendorProductId': 'com.app.monthly',
        'period': {'unit': AdaptyPeriodUnit.month, 'numberOfUnits': 1},
        'localizedPeriod': '1 month',
        'renewalType': AdaptyRenewalType.autorenewable,
        'offer': {
          'type': AdaptySubscriptionOfferType.introductory,
          'id': 'intro-monthly',
          'phases': [
            {
              'price': 0.0,
              'paymentMode': AdaptyPaymentMode.freeTrial,
              'numberOfPeriods': 1,
              'subscriptionPeriod': {'unit': AdaptyPeriodUnit.day, 'numberOfUnits': 3},
              'localizedSubscriptionPeriod': '3 days',
              'localizedNumberOfPeriods': '3 days',
            },
            {
              'price': 4.99,
              'paymentMode': AdaptyPaymentMode.payAsYouGo,
              'numberOfPeriods': 3,
              'subscriptionPeriod': {'unit': AdaptyPeriodUnit.month, 'numberOfUnits': 1},
              'localizedSubscriptionPeriod': '1 month',
              'localizedNumberOfPeriods': '3 months',
            },
          ],
        },
      },
      {
        'vendorProductId': 'com.app.quarterly',
        'period': {'unit': AdaptyPeriodUnit.month, 'numberOfUnits': 3},
        'localizedPeriod': '3 months',
        'renewalType': AdaptyRenewalType.autorenewable,
        'offer': {
          'type': AdaptySubscriptionOfferType.introductory,
          'id': 'intro-quarterly',
          'phases': [
            {
              'price': 14.99,
              'paymentMode': AdaptyPaymentMode.payUpFront,
              'numberOfPeriods': 1,
              'subscriptionPeriod': {'unit': AdaptyPeriodUnit.month, 'numberOfUnits': 3},
              'localizedSubscriptionPeriod': '3 months',
              'localizedNumberOfPeriods': '3 months',
            },
          ],
        },
      },
      {
        'vendorProductId': 'com.app.prepaid',
        'period': {'unit': AdaptyPeriodUnit.month, 'numberOfUnits': 1},
        'localizedPeriod': '1 month',
        'renewalType': AdaptyRenewalType.prepaid,
        'offer': null,
      },
      {
        'vendorProductId': 'com.app.other',
        'period': {'unit': AdaptyPeriodUnit.unknown, 'numberOfUnits': 0},
        'localizedPeriod': '',
        'renewalType': AdaptyRenewalType.autorenewable,
        'offer': {
          'type': AdaptySubscriptionOfferType.introductory,
          'id': 'intro-other',
          'phases': [
            {
              'price': 1.99,
              'paymentMode': AdaptyPaymentMode.payUpFront,
              'numberOfPeriods': 1,
              'subscriptionPeriod': {'unit': AdaptyPeriodUnit.unknown, 'numberOfUnits': 0},
              'localizedSubscriptionPeriod': '',
              'localizedNumberOfPeriods': '',
            },
          ],
        },
      },
    ],
  ),
  (method: 'get_flow', caseName: 'default', platform: ios, project: _flowOf, expected: _flow(basePlanId: null)),
  (
    method: 'get_flow',
    caseName: 'default',
    platform: android,
    project: _flowOf,
    expected: _flow(basePlanId: 'yearly-base'),
  ),
  (
    method: 'make_purchase',
    caseName: 'default',
    platform: ios,
    project: _purchaseOf,
    expected: {
      'result': 'success',
      'profile': _profileIos,
      'appleJwsTransaction': 'eyJhbGciOiJFUzI1NiJ9.e30.c2lnbmF0dXJl',
      'googlePurchaseToken': null,
    },
  ),
  (
    method: 'make_purchase',
    caseName: 'default',
    platform: android,
    project: _purchaseOf,
    expected: {
      'result': 'success',
      'profile': _profileAndroid,
      'appleJwsTransaction': null,
      'googlePurchaseToken': 'purchase-token-1',
    },
  ),
  (method: 'make_purchase', caseName: 'pending', platform: ios, project: _purchaseOf, expected: {'result': 'pending'}),
  (
    method: 'make_purchase',
    caseName: 'user_cancelled',
    platform: android,
    project: _purchaseOf,
    expected: {'result': 'user cancelled'},
  ),
  (
    method: 'get_current_installation_status',
    caseName: 'default',
    platform: ios,
    project: _installationOf,
    expected: {
      'status': 'determined',
      'details': {
        'installId': 'install-1',
        'installTime': _aug24,
        'appLaunchCount': 4,
        'payload': '{"campaign":"campaign-1"}',
      },
    },
  ),
  (
    method: 'get_current_installation_status',
    caseName: 'not_determined',
    platform: android,
    project: _installationOf,
    expected: {'status': 'not determined'},
  ),
  (
    method: 'get_profile',
    caseName: 'error',
    platform: ios,
    project: _errorOf,
    expected: {
      'code': 2002,
      'message': 'something failed',
      'detail': '{"adapty_code":2002,"message":"something failed","detail":"AdaptyError.notActivated"}',
    },
  ),
  (
    method: 'get_profile',
    caseName: 'error',
    platform: android,
    project: _errorOf,
    expected: {'code': 2002, 'message': 'something failed', 'detail': null},
  ),
  (method: 'get_profile', caseName: 'full', platform: ios, project: _profileOf, expected: _profileFullIos),
  (method: 'get_profile', caseName: 'full', platform: android, project: _profileOf, expected: _profileFullAndroid),
  (
    method: 'get_flow',
    caseName: 'minimal',
    platform: ios,
    project: _flowOf,
    expected: _minimalFlow(basePlanId: null, hasViewConfiguration: false),
  ),
  (
    method: 'get_flow',
    caseName: 'minimal',
    platform: android,
    project: _flowOf,
    expected: _minimalFlow(basePlanId: 'yearly-base', hasViewConfiguration: true),
  ),
  for (final platform in [ios, android]) ...[
    (
      method: 'get_current_installation_status',
      caseName: 'not_available',
      platform: platform,
      project: _installationOf,
      expected: {'status': 'not available'},
    ),
    (
      method: 'adapty_ui_show_dialog',
      caseName: 'secondary',
      platform: platform,
      project: _itself,
      expected: AdaptyUIDialogActionType.secondary,
    ),
    (
      method: 'adapty_ui_create_flow_view',
      caseName: 'default',
      platform: platform,
      project: _flowViewOf,
      expected: {'id': 'view-1', 'placementId': 'placement-id', 'variationId': 'variation-id', 'locale': 'en'},
    ),
    (
      method: 'adapty_ui_create_onboarding_view',
      caseName: 'default',
      platform: platform,
      project: _onboardingViewOf,
      expected: {'id': 'view-1', 'placementId': 'placement-id', 'variationId': 'variation-id'},
    ),
  ],
];

Object? _profileOf(Object? model) => projectProfile(model! as AdaptyProfile);
Object? _productsOf(Object? model) => [
  for (final p in model! as List<Object?>) projectProduct(p! as AdaptyPaywallProduct),
];

/// What each product gives of its periods, renewal and offer: the values of the cases of other offers, which differ
/// from the default product in these only.
Object? _offerValuesOf(Object? model) => [
  for (final p in (model! as List<Object?>).cast<AdaptyPaywallProduct>())
    if (p.subscription case final s?)
      {
        'vendorProductId': p.vendorProductId,
        'period': {'unit': s.period.unit, 'numberOfUnits': s.period.numberOfUnits},
        'localizedPeriod': s.localizedPeriod,
        'renewalType': s.renewalType,
        'offer': switch (s.offer) {
          null => null,
          final o => {
            'type': o.identifier.type,
            'id': o.identifier.id,
            'phases': [
              for (final phase in o.phases)
                {
                  'price': phase.price.amount,
                  'paymentMode': phase.paymentMode,
                  'numberOfPeriods': phase.numberOfPeriods,
                  'subscriptionPeriod': {
                    'unit': phase.subscriptionPeriod.unit,
                    'numberOfUnits': phase.subscriptionPeriod.numberOfUnits,
                  },
                  'localizedSubscriptionPeriod': phase.localizedSubscriptionPeriod,
                  'localizedNumberOfPeriods': phase.localizedNumberOfPeriods,
                },
            ],
          },
        },
      },
];
Object? _flowOf(Object? model) => projectFlow(model! as AdaptyFlow);
Object? _purchaseOf(Object? model) => projectPurchaseResult(model! as AdaptyPurchaseResult);
Object? _installationOf(Object? model) => projectInstallationStatus(model! as AdaptyInstallationStatus);
Object? _errorOf(Object? model) => projectError(model! as AdaptyError);
Object? _itself(Object? model) => model;
Object? _flowViewOf(Object? model) => projectFlowView(model! as AdaptyUIFlowView);
Object? _onboardingViewOf(Object? model) => projectOnboardingView(model! as AdaptyUIOnboardingView);

/// The cases of events whose models the SDK builds from values, what the model of each case gives an app: the last
/// thing its reader hands on.
final List<({String event, String caseName, Object? Function(Object?) project, Object? expected})> _projectedEvents = [
  (
    event: 'flow_view_did_perform_action',
    caseName: 'open_url',
    project: _lastOf(projectAction),
    expected: {'type': 'open_url', 'url': 'https://example.com/terms', 'openIn': AdaptyWebPresentation.inAppBrowser},
  ),
  (
    event: 'flow_view_did_perform_action',
    caseName: 'open_url_out_of_app',
    project: _lastOf(projectAction),
    expected: {'type': 'open_url', 'url': 'https://example.com/terms', 'openIn': AdaptyWebPresentation.externalBrowser},
  ),
  (
    event: 'onboarding_on_analytics_action',
    caseName: 'screen_completed',
    project: _lastOf(projectAnalyticsEvent),
    expected: {'name': 'screen_completed', 'elementId': 'element-1', 'reply': 'yes'},
  ),
  (
    event: 'onboarding_on_state_updated_action',
    caseName: 'date_picker',
    project: _lastOf(projectStateUpdatedParams),
    expected: {'type': 'date_picker', 'day': 24, 'month': 8, 'year': 1990},
  ),
];

Object? Function(Object?) _lastOf<T>(Object? Function(T) project) =>
    (read) => project((read! as List<Object?>).last as T);

/// [payload] with [key] added to the object at [path].
Object? _withKeyAt(Object? payload, String path, String key) {
  final copy = jsonDecode(jsonEncode(payload));
  Object? holder = copy;
  for (final segment in path.split('/').skip(1)) {
    final name = segment.replaceAll('~1', '/').replaceAll('~0', '~');
    holder = holder is List ? holder[int.parse(name)] : (holder! as Map)[name];
  }
  (holder! as Map)[key] = {
    'nested': [1, 'two'],
  };
  return copy;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the read tracking map', () {
    test('marks a key looked up with [] or containsKey, at its path', () {
      final tracker = ReadTracker();
      final json =
          tracker.track({
                'a': 1,
                'b': {'c': 2, 'd': 3},
                'e': 4,
              })!
              as Map<String, dynamic>;

      json['a'];
      (json['b'] as Map<String, dynamic>).containsKey('d');

      expect(tracker.read, {'/a', '/b', '/b/d'});
    });

    test('marks nothing when a map is gone over, but hands out its values wrapped', () {
      final tracker = ReadTracker();
      final json =
          tracker.track({
                'a': {'x': 1},
                'b': {'y': 2},
                'c': {'z': 3},
                'd': {'w': 4},
              })!
              as Map<String, dynamic>;

      json.keys.toList();
      json.forEach((key, value) {
        if (key == 'a') (value as Map<String, dynamic>)['x'];
      });
      for (final entry in json.entries) {
        if (entry.key == 'b') (entry.value as Map<String, dynamic>)['y'];
      }
      json.map((key, value) => MapEntry(key, key == 'c' ? (value as Map<String, dynamic>)['z'] : null));
      json.values.toList();

      expect(tracker.read, {'/a/x', '/b/y', '/c/z'});
    });

    test('hands out the items of a list wrapped, with their index in the path', () {
      final tracker = ReadTracker();
      final json =
          tracker.track({
                'list': [
                  {'k': 1},
                  {'k': 2},
                ],
              })!
              as Map<String, dynamic>;

      for (final item in json['list'] as List<dynamic>) {
        (item as Map<String, dynamic>)['k'];
      }

      expect(tracker.read, {'/list', '/list/0/k', '/list/1/k'});
    });

    test('a copy made with Map.from reads nothing', () {
      final tracker = ReadTracker();
      final json = tracker.track({'a': 1, 'b': 2})! as Map<String, dynamic>;

      final copy = Map<String, dynamic>.from(json);
      copy['a'];

      expect(tracker.read, isEmpty);
    });

    test('a key with a slash or a tilde is escaped in the path', () {
      final tracker = ReadTracker();
      final json = tracker.track({'a/b~c': 1})! as Map<String, dynamic>;

      json['a/b~c'];

      expect(tracker.read, {'/a~1b~0c'});
    });

    test('cannot be written', () {
      final json = ReadTracker().track({'a': 1, 'l': <Object?>[]})! as Map<String, dynamic>;

      expect(() => json['b'] = 2, throwsUnsupportedError);
      expect(() => json.remove('a'), throwsUnsupportedError);
      expect(() => (json['l'] as List<dynamic>).add(1), throwsUnsupportedError);
    });
  });

  group('the keys of a payload', () {
    final payload = _payload(CorpusKind.response, 'get_profile', 'default', ios);
    late final keys = schemaKeys(_schema.responseEntry('get_profile'), payload, ios);

    test('a property of a model, under the branch of the envelope the payload matches, is described', () {
      expect(keys.described, containsAll(['/success', '/success/profile_id', '/success/paid_access_levels']));
    });

    test('a key of a dictionary is data, and the properties of its value are described', () {
      expect(keys.data, containsAll(['/success/paid_access_levels/premium', '/success/custom_attributes/age']));
      expect(keys.described, contains('/success/paid_access_levels/premium/is_active'));
      expect(keys.described, isNot(contains('/success/paid_access_levels/premium')));
    });

    test('a property a schema fix adds is described on its platform only', () {
      const key = '/success/paid_access_levels/premium/renewal_info_signed_at';
      expect(keys.described, contains(key));

      final onAndroid = schemaKeys(_schema.responseEntry('get_profile'), {
        'success': (payload! as Map<String, Object?>)['success'],
      }, android);
      expect(onAndroid.described, isNot(contains(key)));
      expect(onAndroid.undescribed, contains(key));
    });

    test('an object with properties and no dictionary is closed; a dictionary is not', () {
      expect(keys.closed, containsAll(['', '/success', '/success/paid_access_levels/premium']));
      expect(keys.closed, isNot(contains('/success/paid_access_levels')));
      expect(keys.closed, isNot(contains('/success/custom_attributes')));
    });

    test('a key the schema has no place for is undescribed', () {
      final extra = schemaKeys(_schema.responseEntry('get_profile'), {
        'success': {...((payload! as Map<String, Object?>)['success']! as Map<String, Object?>), 'nickname': 'x'},
      }, ios);
      expect(extra.undescribed, {'/success/nickname'});
    });
  });

  group('a model that leaves keys unread is caught', () {
    final payload = _payload(CorpusKind.response, 'get_profile', 'default', ios);
    final entry = _schema.responseEntry('get_profile');

    List<String> unread(Object? Function(Map<String, dynamic> success) decode) {
      final tracker = ReadTracker();
      final json = tracker.track(payload)! as Map<String, dynamic>;
      decode(json['success'] as Map<String, dynamic>);
      return (schemaKeys(entry, payload, ios).described.difference(tracker.read).toList()..sort());
    }

    test('a model that reads no key leaves every key unread', () {
      expect(unread((_) => null), containsAll(['/success/profile_id', '/success/paid_access_levels/premium/id']));
    });

    test('a model read from a copy made with Map.from leaves its keys unread', () {
      expect(unread((json) => Map<String, dynamic>.from(json)['profile_id']), contains('/success/profile_id'));
    });

    test('the profile reads the keys of every access level in its dictionary', () {
      final left = unread(AdaptyProfileJSONBuilder.fromJsonValue);
      expect(left.where((k) => k.startsWith('/success/paid_access_levels/premium/') && k.endsWith('/id')), isEmpty);
      expect(left, isNot(contains('/success/paid_access_levels/premium/is_active')));
    });
  });

  group('the rows of the keys left unread', () {
    const refs = {'ios@release/9.9.9', 'android@9.9.9'};
    late String root;
    setUp(() {
      root = Directory.systemTemp.createTempSync('not_read_').path;
      addTearDown(() => Directory(root).deleteSync(recursive: true));
      File('$root/lib/a.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('one\ntwo\nthree\n');
    });

    List<String> problems(String reason, String source) => sourceProblems(reason, source, refs: refs, root: root);

    test('a row with a reason and files of this repository and of a fixed native has no problem', () {
      expect(
        problems(
          'why',
          'lib/a.dart:2-3; ios@release/9.9.9 Sources/A.swift:10,12-14, Sources/B.swift; android@9.9.9 b/C.kt:4',
        ),
        isEmpty,
      );
    });

    test('a native file whose name has a plus is a file with its lines', () {
      expect(
        problems('why', 'ios@release/9.9.9 Sources/A+Codable.swift:10-12, Sources.UI/B+Encodable.swift:3'),
        isEmpty,
      );
    });

    test('a row without a reason or a source is a problem', () {
      expect(problems(' ', 'lib/a.dart:1'), [contains('no reason')]);
      expect(problems('why', ''), [contains('no source')]);
    });

    test('a file of this repository that is not there, or has fewer lines than named, is a problem', () {
      expect(problems('why', 'lib/b.dart:1'), [contains('lib/b.dart')]);
      expect(problems('why', 'lib/a.dart:2-4'), [contains('lib/a.dart:2-4')]);
      expect(problems('why', 'lib/a.dart:1,9'), [contains('lib/a.dart:1,9')]);
    });

    test('a native file without the ref the contract is fixed to is a problem', () {
      expect(problems('why', 'Sources/A.swift:10'), [contains('Sources/A.swift:10')]);
      expect(problems('why', 'ios@release/9.9.8 Sources/A.swift:10'), [contains('ios@release/9.9.8')]);
    });

    test('a star of a row stands for one segment of a pointer', () {
      expect(_notReadRow(r'#/$events/FlowViewEvent.DidAppear/properties/id'), r'#/$events/*/properties/id');
      expect(_notReadRow(r'#/$events/FlowViewEvent.DidAppear/properties/view/properties/id'), isNull);
    });

    test('every row of this test has a reason and a source naming files that are there', () {
      final source = ContractSource.load('.');
      final fixed = {'ios@${source.iosRef}', 'android@${source.androidCrossplatform}'};
      expect([
        for (final MapEntry(key: row, value: (platforms: _, :reason, source: text)) in _notRead.entries)
          for (final problem in sourceProblems(reason, text, refs: fixed)) '$row: $problem',
      ], isEmpty);
    });
  });

  group('every key of a contract response or event is read', () {
    test('every method and event of the corpus has its reader', () {
      final methods = {
        for (final f in _corpus.fixtures)
          if (f.kind == CorpusKind.response) f.name,
      };
      final events = {
        for (final f in _corpus.fixtures)
          if (f.kind == CorpusKind.event) f.name,
      };
      expect(_responseReaders.keys.toSet(), methods);
      expect(_eventReaders.keys.toSet(), events);
      expect(methods, {
        for (final m in NativeMethod.values) m.wireName,
        for (final m in NativeEventResponse.values) m.wireName,
      });
    });

    final fixtures = [
      for (final f in _corpus.fixtures)
        if (f.kind != CorpusKind.request && !f.isNegative) f,
    ]..sort((a, b) => a.path.compareTo(b.path));
    for (final fixture in fixtures) {
      for (final platform in _platformsOf(fixture)) {
        test('${fixture.kind.name} ${fixture.name}/${fixture.caseName} on ${platform.name}', () {
          installContractRuntime(platform: platform);
          expect(_readKeys(fixture, platform).unread, isEmpty);
        });
      }
    }

    test('every row of the keys left unread is still left unread by a fixture on each of its platforms', () {
      final used = <(String, ContractPlatform)>{};
      for (final fixture in fixtures) {
        for (final platform in _platformsOf(fixture)) {
          installContractRuntime(platform: platform);
          used.addAll(_readKeys(fixture, platform).rowsUsed.map((row) => (row, platform)));
        }
      }
      expect([
        for (final MapEntry(key: row, value: (:platforms, reason: _, source: _)) in _notRead.entries)
          for (final platform in platforms)
            if (!used.contains((row, platform))) '$row on ${platform.name}',
      ], isEmpty);
    });
  });

  group('a decoded model gives an app what the native wrote', () {
    for (final row in _projected) {
      test('${row.method}/${row.caseName} on ${row.platform.name}', () {
        installContractRuntime(platform: row.platform);
        final payload = _payload(CorpusKind.response, row.method, row.caseName, row.platform)! as Map<String, dynamic>;

        expect(row.project(_readEnvelope(row.method, payload)), row.expected);
      });
    }
  });

  group('a decoded event model gives an app what the native wrote', () {
    test('every row names a case of the corpus', () {
      expect([
        for (final row in _projectedEvents)
          if (!_corpus.fixtures.any(
            (f) => f.kind == CorpusKind.event && f.name == row.event && f.caseName == row.caseName,
          ))
            '${row.event}/${row.caseName}',
      ], isEmpty);
    });

    for (final row in _projectedEvents) {
      final fixtures = _corpus.fixtures.where(
        (f) => f.kind == CorpusKind.event && f.name == row.event && f.caseName == row.caseName,
      );
      for (final fixture in fixtures) {
        for (final platform in _platformsOf(fixture)) {
          test('${row.event}/${row.caseName} on ${platform.name}', () {
            installContractRuntime(platform: platform);

            expect(row.project(_eventReaders[row.event]!(fixture.payload! as Map<String, dynamic>)), row.expected);
          });
        }
      }
    }
  });

  group('a key the contract does not know changes nothing', () {
    for (final row in _projected) {
      test('${row.method}/${row.caseName} on ${row.platform.name}, at every level', () {
        installContractRuntime(platform: row.platform);
        final fixture = _corpus.fixture(CorpusKind.response, row.method, row.caseName, row.platform)!;
        final without = row.project(_readEnvelope(row.method, fixture.payload! as Map<String, dynamic>));
        final closed = schemaKeys(_schema.responseEntry(row.method), fixture.payload, row.platform).closed;
        expect(closed, isNotEmpty);

        for (final path in closed) {
          final payload = _withKeyAt(fixture.payload, path, 'key_not_in_the_contract')! as Map<String, dynamic>;
          expect(row.project(_readEnvelope(row.method, payload)), without, reason: 'an unknown key at "$path"');
        }
      });
    }
  });

  group('through the public API', () {
    for (final (platform, expected) in [(ios, _profileIos), (android, _profileAndroid)]) {
      test('getProfile on ${platform.name} gives the profile the native wrote', () async {
        installContractRuntime(platform: platform);

        expect(projectProfile(await Adapty().getProfile()), expected);
      });
    }

    for (final (platform, expected) in [(ios, _productIos), (android, _productAndroid)]) {
      test('getPaywallProducts on ${platform.name} gives the products the native wrote', () async {
        installContractRuntime(platform: platform);

        final flow = await Adapty().getFlow(placementId: 'placement-id');
        final products = await Adapty().getPaywallProducts(flow: flow);

        expect([for (final p in products) projectProduct(p)], [expected]);
      });
    }
  });
}

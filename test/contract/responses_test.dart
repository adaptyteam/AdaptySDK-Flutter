// What the SDK makes of every response and event of the contract corpus: every key the contract describes is read
// by the model that decodes it, unless it is listed with the reason the SDK leaves it alone.
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
import '../../tool/contract/src/corpus.dart';
import '../support/contract/contract_runtime.dart';
import 'support/read_tracking_map.dart';
import 'support/schema_keys.dart';

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

const _iosRef = 'ios@release/4.4.1';
const _androidRef = 'android@4.4.0';

/// The keys the contract describes that the SDK leaves unread, by the property of the schema (`*` stands for one
/// segment), with the platforms whose native writes them, why the SDK leaves them alone and where that shows. A key
/// left unread leaves its whole value unread.
const Map<String, ({Set<ContractPlatform> platforms, String reason, String source})> _notRead = {
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
        '$_iosRef Sources/Placements/Entities/AdaptyFlowPaywall.swift:55-58,89; '
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
}

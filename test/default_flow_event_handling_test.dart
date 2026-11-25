/// What the SDK does with each incoming flow event when the app sets no observer, in the payload
/// shapes of both native SDKs, and what an observer that keeps the base `flowViewDidPerformAction`
/// does with the close and the Android system back actions.
///
/// `AdaptyLogger.logLevel` is static and outlives a test, so `setUp` saves it and restates the
/// default and `tearDown` restores it.
import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

/// An app observer that implements only what it must and keeps every default of the base class.
class _BaseObserver extends AdaptyUIFlowsEventsObserver {
  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) {}

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  final printed = <String>[];
  late AdaptyLogLevel savedLogLevel;

  /// Delivers the event in a guarded zone and returns what escaped it uncaught.
  Future<List<Object>> sendEvent(String method, Map<String, dynamic> arguments) async {
    final caught = <Object>[];
    await runZonedGuarded(
      () async {
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
          _channel.name,
          const StandardMethodCodec().encodeMethodCall(MethodCall(method, jsonEncode({'id': method, ...arguments}))),
          (_) {},
        );
        await pumpEventQueue();
      },
      (error, _) => caught.add(error),
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => printed.add(line)),
    );
    return caught;
  }

  /// Sends each event, without an observer, and returns, per event name, every native call,
  /// uncaught error and printed log line it caused.
  Future<Map<String, List<String>>> effectsOfEventsWithoutObserver(
    List<(String, String, Map<String, dynamic>)> events,
  ) async {
    final effects = <String, List<String>>{};
    for (final (name, method, arguments) in events) {
      calls.clear();
      printed.clear();
      final caught = await sendEvent(method, arguments);
      final found = [
        ...calls.map((call) => 'native call ${call.method}'),
        ...caught.map((error) => 'uncaught $error'),
        ...printed.map((line) => 'log $line'),
      ];
      if (found.isNotEmpty) effects[name] = found;
    }
    return effects;
  }

  setUp(() {
    calls.clear();
    printed.clear();
    savedLogLevel = AdaptyLogger.logLevel;
    // The SDK default: `info`, `warn` and `error` lines print at this level, `verbose` ones do not.
    AdaptyLogger.logLevel = AdaptyLogLevel.info;
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return jsonEncode({'success': true});
    });
  });

  tearDown(() {
    AdaptyUI().setFlowsEventsObserver(null);
    AdaptyLogger.logLevel = savedLogLevel;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('without an observer, no outcome, lifecycle or action event in the iOS shape makes a call or a log', () async {
    final effects = await effectsOfEventsWithoutObserver(_flowEvents(_iosView, _iosError, _iosProfile));

    expect(effects, isEmpty);
  });

  test(
    'without an observer, no outcome, lifecycle or action event in the Android shape makes a call or a log',
    () async {
      final effects = await effectsOfEventsWithoutObserver(_flowEvents(_androidView, _androidError, _androidProfile));

      expect(effects, isEmpty);
    },
  );

  test('an observer that keeps the base flowViewDidPerformAction makes no call on the Android system back', () async {
    AdaptyUI().setFlowsEventsObserver(_BaseObserver());

    final caught = await sendEvent('flow_view_did_perform_action', {
      'view': _androidView,
      'action': {'type': 'system_back'},
    });

    expect(calls, isEmpty);
    expect(caught, isEmpty);
    expect(printed, isEmpty);
  });

  test('an observer that keeps the base flowViewDidPerformAction dismisses a presented flow on close', () async {
    AdaptyUI().setFlowsEventsObserver(_BaseObserver());

    final caught = await sendEvent('flow_view_did_perform_action', {
      'view': _androidView,
      'action': {'type': 'close'},
    });

    expect(calls.map((call) => call.method), ['adapty_ui_dismiss_flow_view']);
    expect(jsonDecode(calls.single.arguments as String), {'id': 'view-2', 'destroy': true});
    expect(caught, isEmpty);
  });
}

/// Every incoming flow event that the default handling leaves to the app, by name, method and
/// arguments, for one native shape of the view, the error and the profile.
List<(String, String, Map<String, dynamic>)> _flowEvents(
  Map<String, dynamic> view,
  Map<String, dynamic> error,
  Map<String, dynamic> profile,
) => [
  ('appear', 'flow_view_did_appear', {'view': view}),
  ('disappear', 'flow_view_did_disappear', {'view': view}),
  (
    'custom action',
    'flow_view_did_perform_action',
    {
      'view': view,
      'action': {
        'type': 'custom',
        'value': 'custom-action',
        'arguments': {'a': 1},
      },
    },
  ),
  (
    'system back',
    'flow_view_did_perform_action',
    {
      'view': view,
      'action': {'type': 'system_back'},
    },
  ),
  (
    'unknown action type',
    'flow_view_did_perform_action',
    {
      'view': view,
      'action': {'type': 'future_type', 'value': 'future-value'},
    },
  ),
  ('legacy system back', 'paywall_view_did_perform_system_back_action', {'view': view}),
  ('select product', 'flow_view_did_select_product', {'view': view, 'product_id': 'base:sub'}),
  ('start purchase', 'flow_view_did_start_purchase', {'view': view, 'product': _product}),
  (
    'finish purchase, success',
    'flow_view_did_finish_purchase',
    {
      'view': view,
      'product': _product,
      'purchased_result': {'type': 'success', 'profile': profile},
    },
  ),
  (
    'finish purchase, cancelled',
    'flow_view_did_finish_purchase',
    {
      'view': view,
      'product': _product,
      'purchased_result': {'type': 'user_cancelled'},
    },
  ),
  ('fail purchase', 'flow_view_did_fail_purchase', {'view': view, 'product': _product, 'error': error}),
  ('start restore', 'flow_view_did_start_restore', {'view': view}),
  ('finish restore', 'flow_view_did_finish_restore', {'view': view, 'profile': profile}),
  ('fail restore', 'flow_view_did_fail_restore', {'view': view, 'error': error}),
  ('receive error', 'flow_view_did_receive_error', {'view': view, 'error': error}),
  ('fail loading products', 'flow_view_did_fail_loading_products', {'view': view, 'error': error}),
  ('web payment, no product and no error', 'flow_view_did_finish_web_payment_navigation', {'view': view}),
  ('web payment, error', 'flow_view_did_finish_web_payment_navigation', {'view': view, 'error': error}),
  (
    'analytics',
    'flow_view_did_receive_analytic_event',
    {
      'view': view,
      'name': 'screen',
      'params': {
        'n': 1,
        'f': 1.5,
        's': 'x',
        'nested': {
          'a': [1, 2],
        },
      },
    },
  ),
];

/// The view as iOS encodes it: `locale` only when set.
const _iosView = {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id', 'locale': 'en'};

/// The view as Android encodes it: no `locale` when it is not set.
const _androidView = {'id': 'view-2', 'placement_id': 'placement-id', 'variation_id': 'variation-id'};

/// An error as iOS encodes it, always with `detail`.
const _iosError = {'adapty_code': 4105, 'message': 'the script failed', 'detail': 'AdaptyUIError.jsException'};

/// An error as Android encodes it, without `detail`.
const _androidError = {'adapty_code': 1000, 'message': 'no products'};

const _product = {
  'vendor_product_id': 'com.app.yearly',
  'adapty_product_id': 'adapty-yearly',
  'access_level_id': 'premium',
  'product_type': 'annual',
  'paywall_product_index': 0,
  'paywall_variation_id': 'paywall-variation-id',
  'paywall_ab_test_name': 'ab-test',
  'paywall_name': 'Paywall',
  'localized_description': 'Premium for a year',
  'localized_title': 'Premium',
  'price': {'amount': 119.88, 'currency_code': 'EUR', 'currency_symbol': '€', 'localized_string': '119,88 €'},
};

/// A profile as iOS encodes it: empty maps and absent custom attributes are left out.
const _iosProfile = {
  'profile_id': 'profile-id',
  'segment_hash': 'segment-hash',
  'is_test_user': false,
  'timestamp': 1700000000,
};

/// A profile as Android encodes it, with an access level and the backend's date format.
const _androidProfile = {
  'profile_id': 'profile-id',
  'paid_access_levels': {
    'premium': {
      'id': 'premium',
      'is_active': true,
      'vendor_product_id': 'sub:base',
      'store': 'play_store',
      'activated_at': '2024-07-31T12:00:00.000000+0000',
      'is_lifetime': false,
      'is_refund': false,
      'will_renew': true,
      'is_in_grace_period': false,
    },
  },
  'subscriptions': <String, dynamic>{},
  'non_subscriptions': <String, dynamic>{},
  'custom_attributes': <String, dynamic>{},
  'is_test_user': false,
  'segment_hash': 'not implemented',
  'timestamp': -1,
};

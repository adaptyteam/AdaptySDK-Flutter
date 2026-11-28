import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

// No observer mode resolver is ever set in this file: the setter takes no null, so a resolver
// set by one test would stay for the rest of the file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];

  Future<void> sendEvent(String method, Map<String, dynamic> arguments) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, jsonEncode(arguments))),
      (_) {},
    );
    await pumpEventQueue();
  }

  setUp(() {
    calls.clear();
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return jsonEncode({'success': true});
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('without a resolver an observer-mode purchase is logged as a warning', () async {
    final logs = <String>[];

    // A complete event, with a view and a product that both decode.
    await runZoned(
      () => sendEvent('flow_view_observer_did_initiate_purchase', {
        'event_id': 'e1',
        'view': {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
        'product': _iosProduct(),
      }),
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => logs.add(line)),
    );

    expect(calls.where((call) => call.method.startsWith('observer_')), isEmpty);
    expect(logs.where((line) => line.contains('WARN:') || line.contains('ERROR:')), [
      allOf(contains('WARN:'), contains("the flow's purchase will not complete"), contains('setObserverModeResolver')),
    ]);
  });

  test('without a resolver an observer-mode restore is logged as a warning', () async {
    final logs = <String>[];

    // A complete event, with a view that decodes.
    await runZoned(
      () => sendEvent('flow_view_observer_did_initiate_restore', {
        'event_id': 'e1',
        'view': {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
      }),
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => logs.add(line)),
    );

    expect(calls.where((call) => call.method.startsWith('observer_')), isEmpty);
    expect(logs.where((line) => line.contains('WARN:') || line.contains('ERROR:')), [
      allOf(contains('WARN:'), contains("the flow's restore will not complete"), contains('setObserverModeResolver')),
    ]);
  });
}

Map<String, dynamic> _eur(num amount, String localizedString) => {
  'amount': amount,
  'currency_code': 'EUR',
  'currency_symbol': '€',
  'localized_string': localizedString,
};

const _year = {'unit': 'year', 'number_of_units': 1};

/// A yearly subscription as the iOS SDK reports it.
Map<String, dynamic> _iosProduct() => {
  'vendor_product_id': 'com.app.yearly',
  'flow_product_id': 'p1',
  'adapty_product_id': 'adapty-yearly',
  'access_level_id': 'premium',
  'product_type': 'annual',
  'paywall_product_index': 0,
  'paywall_variation_id': 'variation-id',
  'paywall_ab_test_name': 'ab-test',
  'paywall_name': 'Paywall',
  'localized_description': 'Premium for a year',
  'localized_title': 'Premium',
  'is_family_shareable': false,
  'region_code': 'DE',
  'price': _eur(119.88, '119,88 €'),
  'subscription': {'group_identifier': '21345678', 'period': _year, 'localized_period': '1 year'},
};

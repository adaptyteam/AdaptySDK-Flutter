import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

const _errorLine = 'ERROR: Error in Adapty._handleIncomingMethodCall: Bad state: the observer failed';

/// Records the events it gets; throws on each of them when [throws] is set.
class _Observer extends AdaptyUIFlowsEventsObserver {
  _Observer({this.throws = false});

  final bool throws;
  final events = <String>[];

  void _record(String event) {
    events.add(event);
    if (throws) throw StateError('the observer failed');
  }

  @override
  void flowViewDidAppear(AdaptyUIFlowView view) => _record('appear');

  @override
  void flowViewDidPerformAction(AdaptyUIFlowView view, AdaptyUIAction action) => _record('action');

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) =>
      _record('finish purchase');

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) => _record('finish restore');

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) => _record('error');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  final printed = <String>[];
  final usedIds = <String>{};

  Map<String, dynamic> viewJson(String viewId) => {
    'id': viewId,
    'placement_id': 'placement-id',
    'variation_id': 'variation-id',
  };

  /// Delivers the event in a guarded zone that records what the SDK prints and returns what escaped it uncaught.
  Future<List<Object>> sendEvent(String method, Map<String, dynamic> arguments) async {
    usedIds.add((arguments['view'] as Map<String, dynamic>)['id'] as String);
    final caught = <Object>[];
    await runZonedGuarded(
      () async {
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
          _channel.name,
          const StandardMethodCodec().encodeMethodCall(MethodCall(method, jsonEncode(arguments))),
          (_) {},
        );
        await pumpEventQueue();
      },
      (error, _) => caught.add(error),
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => printed.add(line)),
    );
    return caught;
  }

  void register(AdaptyUIFlowsEventsObserver observer, String viewId) {
    usedIds.add(viewId);
    AdaptyUI().registerFlowEventsListener(observer, viewId);
  }

  Iterable<String> errorLines() => printed.where((line) => line.contains(_errorLine));

  final product = {
    'vendor_product_id': 'com.app.yearly',
    'adapty_product_id': 'adapty-yearly',
    'access_level_id': 'premium',
    'product_type': 'annual',
    'paywall_product_index': 0,
    'paywall_variation_id': 'variation-id',
    'paywall_ab_test_name': 'ab-test',
    'paywall_name': 'Paywall',
    'localized_description': 'Premium for a year',
    'localized_title': 'Premium',
    'price': {'amount': 119.88, 'currency_code': 'EUR', 'currency_symbol': '€', 'localized_string': '119,88 €'},
  };

  setUp(() {
    calls.clear();
    printed.clear();
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return jsonEncode({'success': true});
    });
  });

  tearDown(() {
    AdaptyUI().setFlowsEventsObserver(null);
    for (final id in usedIds) {
      AdaptyUI().unregisterFlowEventsListener(id);
    }
    usedIds.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('a widget that throws on appear, an action and a finished purchase does not keep the events from the observer',
      () async {
    final widget = _Observer(throws: true);
    final observer = _Observer();
    AdaptyUI().setFlowsEventsObserver(observer);
    register(widget, 'flutter_native_60');

    final caught = [
      ...await sendEvent('flow_view_did_appear', {'view': viewJson('flutter_native_60')}),
      ...await sendEvent('flow_view_did_perform_action', {
        'view': viewJson('flutter_native_60'),
        'action': {'type': 'custom', 'value': 'next'},
      }),
      ...await sendEvent('flow_view_did_finish_purchase', {
        'view': viewJson('flutter_native_60'),
        'product': product,
        'purchased_result': {'type': 'user_cancelled'},
      }),
    ];

    expect(widget.events, ['appear', 'action', 'finish purchase']);
    expect(observer.events, ['appear', 'action', 'finish purchase']);
    expect(errorLines(), hasLength(3));
    expect(caught, isEmpty);
  });

  test('an observer that throws is logged once and nothing escapes uncaught', () async {
    final observer = _Observer(throws: true);
    AdaptyUI().setFlowsEventsObserver(observer);

    final caught = await sendEvent('flow_view_did_appear', {'view': viewJson('modal-view')});

    expect(observer.events, ['appear']);
    expect(errorLines(), hasLength(1));
    expect(caught, isEmpty);
    expect(calls, isEmpty);
  });

  test('an observer that throws on an early embedded error is logged once, and the widget still gets the error',
      () async {
    final observer = _Observer(throws: true);
    final widget = _Observer();
    AdaptyUI().setFlowsEventsObserver(observer);

    final caught = await sendEvent('flow_view_did_receive_error', {
      'view': viewJson('flutter_native_61'),
      'error': {'adapty_code': 20, 'message': 'Adapty was not initialized'},
      'id': 'flow_view_did_receive_error',
    });
    register(widget, 'flutter_native_61');

    expect(observer.events, ['error']);
    expect(errorLines(), hasLength(1));
    expect(caught, isEmpty);
    expect(widget.events, ['error']);
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

String _noResolverWarning(String action) =>
    "WARN: Observer mode is on but no AdaptyUIObserverModeResolver is set; the flow's $action will not complete. "
    'Set one with AdaptyUI().setObserverModeResolver().';

const _answerMethods = [
  'observer_purchase_did_start',
  'observer_purchase_did_finish',
  'observer_restore_did_start',
  'observer_restore_did_finish',
];

/// Keeps the callbacks it gets, so that a test can call them.
class _Resolver extends AdaptyUIObserverModeResolver {
  void Function()? onStartPurchase;
  void Function()? onFinishPurchase;
  void Function()? onStartRestore;
  void Function()? onFinishRestore;

  @override
  void observerModeDidInitiatePurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    void Function() onStartPurchase,
    void Function() onFinishPurchase,
  ) {
    this.onStartPurchase = onStartPurchase;
    this.onFinishPurchase = onFinishPurchase;
  }

  @override
  void observerModeDidInitiateRestore(
    AdaptyUIFlowView view,
    void Function() onStartRestore,
    void Function() onFinishRestore,
  ) {
    this.onStartRestore = onStartRestore;
    this.onFinishRestore = onFinishRestore;
  }
}

final _product = {
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

const _view = {'id': 'view-id', 'placement_id': 'placement-id', 'variation_id': 'variation-id'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  final printed = <String>[];

  /// Delivers the event in a guarded zone that records what the SDK prints, and returns what escaped it uncaught.
  Future<List<Object>> deliver(Future<void> Function() body) async {
    final caught = <Object>[];
    await runZonedGuarded(
      () async {
        await body();
        await pumpEventQueue();
      },
      (error, _) => caught.add(error),
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => printed.add(line)),
    );
    return caught;
  }

  Future<void> sendEvent(String method, Map<String, dynamic> arguments) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        _channel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, jsonEncode(arguments))),
        (_) {},
      );

  Future<void> initiatePurchase(String eventId) => sendEvent('flow_view_observer_did_initiate_purchase', {
    'view': _view,
    'product': _product,
    'event_id': eventId,
  });

  Future<void> initiateRestore(String eventId) => sendEvent('flow_view_observer_did_initiate_restore', {
    'view': _view,
    'event_id': eventId,
  });

  Iterable<MethodCall> answers() => calls.where((call) => _answerMethods.contains(call.method));

  void mockNative(Map<String, dynamic> reply) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return jsonEncode(reply);
    });
  }

  // A resolver can't be unset, so the events without one are delivered before any test sets one.
  late List<String> noResolverPurchasePrinted;
  late List<String> noResolverRestorePrinted;
  late List<String> noResolverAnswers;
  late List<Object> noResolverCaught;
  setUpAll(() async {
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    mockNative({'success': true});
    noResolverCaught = [...await deliver(() => initiatePurchase('purchase-without-resolver'))];
    noResolverPurchasePrinted = List.of(printed);
    printed.clear();
    noResolverCaught.addAll(await deliver(() => initiateRestore('restore-without-resolver')));
    noResolverRestorePrinted = List.of(printed);
    noResolverAnswers = answers().map((call) => call.method).toList();
  });

  setUp(() {
    calls.clear();
    printed.clear();
    Adapty().setupAfterHotRestart();
    mockNative({'success': true});
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('a flow purchase without a resolver is logged as a warning and nothing is sent', () {
    expect(noResolverPurchasePrinted.where((line) => line.contains(_noResolverWarning('purchase'))), hasLength(1));
    expect(noResolverAnswers, isEmpty);
    expect(noResolverCaught, isEmpty);
  });

  test('a flow restore without a resolver is logged as a warning and nothing is sent', () {
    expect(noResolverRestorePrinted.where((line) => line.contains(_noResolverWarning('restore'))), hasLength(1));
    expect(noResolverAnswers, isEmpty);
    expect(noResolverCaught, isEmpty);
  });

  test('each callback of a resolver sends its own answer with the event_id of its request', () async {
    final resolver = _Resolver();
    AdaptyUI().setObserverModeResolver(resolver);

    await deliver(() => initiatePurchase('purchase-event'));
    await deliver(() => initiateRestore('restore-event'));
    resolver.onStartPurchase!();
    resolver.onFinishPurchase!();
    resolver.onStartRestore!();
    resolver.onFinishRestore!();
    await pumpEventQueue();

    expect(answers().map((call) => [call.method, jsonDecode(call.arguments as String)]), [
      ['observer_purchase_did_start', {'event_id': 'purchase-event'}],
      ['observer_purchase_did_finish', {'event_id': 'purchase-event'}],
      ['observer_restore_did_start', {'event_id': 'restore-event'}],
      ['observer_restore_did_finish', {'event_id': 'restore-event'}],
    ]);
    expect(printed.where((line) => line.contains('WARN: Observer mode is on')), isEmpty);
  });

  test('a native error on a start or finish answer is logged once each, and an app that waits still gets it', () async {
    final resolver = _Resolver();
    AdaptyUI().setObserverModeResolver(resolver);
    mockNative({
      'error': {'adapty_code': 3001, 'message': 'the request is not found'},
    });
    await deliver(() => initiatePurchase('failing-event'));

    Object? awaited;
    final caught = await deliver(() async {
      resolver.onStartPurchase!();
      try {
        await Future<void>(() => resolver.onFinishPurchase!());
      } catch (e) {
        awaited = e;
      }
    });

    expect(caught, isEmpty);
    expect(printed.where((line) => line.contains('ERROR: Error in Adapty.observer_purchase_did_start(): ')), hasLength(1));
    expect(printed.where((line) => line.contains('ERROR: Error in Adapty.observer_purchase_did_finish(): ')), hasLength(1));
    expect(awaited, isA<AdaptyError>().having((e) => e.code, 'code', AdaptyErrorCode.wrongParam));
  });
}

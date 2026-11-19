import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

/// Whether the resolver throws; each test sets it before the event.
bool _throwing = false;

class _Resolver extends AdaptyUIObserverModeResolver {
  final purchases = <(AdaptyUIFlowView, AdaptyPaywallProduct)>[];
  void Function()? onStartPurchase;

  @override
  void observerModeDidInitiatePurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    void Function() onStartPurchase,
    void Function() onFinishPurchase,
  ) {
    purchases.add((view, product));
    this.onStartPurchase = onStartPurchase;
    if (_throwing) throw StateError('resolver boom');
  }

  @override
  void observerModeDidInitiateRestore(
    AdaptyUIFlowView view,
    void Function() onStartRestore,
    void Function() onFinishRestore,
  ) {}
}

final _resolver = _Resolver();

final _purchase = {
  'event_id': 'e1',
  'view': {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
  'product': _iosProduct(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  late Object? Function(MethodCall call) respond;

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
    _resolver.purchases.clear();
    _resolver.onStartPurchase = null;
    _throwing = false;
    respond = (_) => jsonEncode({'success': null});
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return respond(call);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('a throwing resolver sends neither start nor finish', () async {
    AdaptyUI().setObserverModeResolver(_resolver);
    _throwing = true;
    final logs = <String>[];

    await runZoned(
      () => sendEvent('flow_view_observer_did_initiate_purchase', _purchase),
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => logs.add(line)),
    );

    expect(_resolver.purchases, hasLength(1));
    final (view, product) = _resolver.purchases.single;
    expect(view.id, 'view-1');
    expect(product.vendorProductId, 'com.app.yearly');
    expect(calls.where((call) => call.method.startsWith('observer_')), isEmpty);
    expect(logs.where((line) => line.contains('ERROR:') && line.contains('resolver boom')), hasLength(1));
  });

  test('a failing start call surfaces as an uncaught error', () async {
    AdaptyUI().setObserverModeResolver(_resolver);
    respond = (call) => call.method == 'observer_purchase_did_start'
        ? jsonEncode({
            'error': {'adapty_code': 2002, 'message': 'the start call failed'},
          })
        : jsonEncode({'success': null});

    await sendEvent('flow_view_observer_did_initiate_purchase', _purchase);
    final onStartPurchase = _resolver.onStartPurchase!;

    final caught = <Object>[];
    await runZonedGuarded(() async {
      onStartPurchase();
      await pumpEventQueue();
    }, (error, _) => caught.add(error));

    expect(calls.map((call) => call.method), ['observer_purchase_did_start']);
    expect(caught, [isA<AdaptyError>().having((e) => e.code, 'code', 2002)]);
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

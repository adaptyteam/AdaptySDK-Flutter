/// The contract of [Adapty.didReceivePromotedPurchaseStream]: a subscriber takes the
/// purchase over, and with none the SDK completes it itself. The decision is made per
/// event, so these tests drive it by subscribing and cancelling around delivery.
///
/// Nothing here asserts "no error escaped" explicitly: every case runs in the test's own
/// zone, and `package:test` already fails a test on an unhandled asynchronous error.
/// Wrapping the bodies in `runZonedGuarded` would swallow exactly the failures these tests
/// exist to catch — case 6 is the one place it is used, and only to keep a *subscriber's*
/// deliberate throw away from the test.
import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

/// Spelled out rather than taken from `IncomingMethod`: this is a contract test for the
/// name the native side actually sends, and the constant would follow a rename instead of
/// catching it.
const _promotedPurchaseEvent = 'did_receive_promoted_purchase';

const _product = {
  'vendor_product_id': 'promoted.product',
  'localized_description': 'Promoted product',
  'localized_title': 'Promoted',
  'is_family_shareable': false,
  'price': {
    'amount': 9.99,
    'currency_code': 'USD',
    'currency_symbol': r'$',
    'localized_string': r'$9.99',
  },
  // Opaque and round-tripped: its presence in the outgoing request is what proves the SDK
  // hands back the product it received rather than one it rebuilt.
  'payload_data': 'opaque-payload',
};

final _userCancelled = jsonEncode({
  'success': {'type': 'user_cancelled'},
});

final _failure = jsonEncode({
  'error': {'message': 'Boom', 'adapty_code': 2},
});

Future<void> _deliverPromotedPurchase() {
  final message = const StandardMethodCodec().encodeMethodCall(
    MethodCall(_promotedPurchaseEvent, jsonEncode({'product': _product})),
  );

  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    _channel.name,
    message,
    (_) {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> outgoing;
  late String response;

  /// `Adapty()` is a process-wide singleton whose stream controller is never reset, so a
  /// subscription left behind would suppress the default in every later test in this file.
  StreamSubscription<AdaptyPromotedProduct> listen(
    void Function(AdaptyPromotedProduct) onData,
  ) {
    final subscription = Adapty().didReceivePromotedPurchaseStream.listen(onData);
    addTearDown(subscription.cancel);
    return subscription;
  }

  /// Captures what the SDK logs. [AdaptyLogger] writes through `print`, which is
  /// `Zone.current.print`. A zone with only a `print` specification is not an error zone,
  /// so an escaping error still reaches the test and still fails it.
  Future<List<String>> capturingLogs(Future<void> Function() body) async {
    final logs = <String>[];
    await runZoned(
      body,
      zoneSpecification: ZoneSpecification(print: (_, __, ___, line) => logs.add(line)),
    );
    return logs;
  }

  setUp(() {
    outgoing = [];
    response = _userCancelled;
    // The SDK default, restated so the suite does not depend on what ran before it: `warn`
    // prints at this level, `verbose` does not.
    AdaptyLogger.logLevel = AdaptyLogLevel.info;
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      outgoing.add(call);
      return response;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    // setUp installed an incoming handler on a channel shared by the whole isolate.
    _channel.setMethodCallHandler(null);
  });

  test('a promoted purchase with no listener is completed by the SDK', () async {
    await _deliverPromotedPurchase();
    await pumpEventQueue();

    expect(outgoing, hasLength(1));
    expect(outgoing.single.method, 'make_promoted_purchase');

    final request = jsonDecode(outgoing.single.arguments as String) as Map<String, dynamic>;
    final product = request['product'] as Map<String, dynamic>;
    expect(product['vendor_product_id'], 'promoted.product');
    expect(product['payload_data'], 'opaque-payload');
  });

  test('completing a promoted purchase by default writes nothing to the log', () async {
    final logs = await capturingLogs(() async {
      await _deliverPromotedPurchase();
      await pumpEventQueue();
    });

    expect(outgoing, hasLength(1));
    expect(logs, isEmpty);
  });

  test('a promoted purchase with a listener goes to the app, not to the SDK', () async {
    final received = <AdaptyPromotedProduct>[];
    listen(received.add);

    await _deliverPromotedPurchase();
    await pumpEventQueue();

    expect(received, hasLength(1));
    expect(received.single.vendorProductId, 'promoted.product');
    expect(outgoing, isEmpty);
  });

  test('the default stays suppressed while any listener remains', () async {
    final received = <AdaptyPromotedProduct>[];
    final leaving = listen((_) {});
    listen(received.add);

    await leaving.cancel();

    await _deliverPromotedPurchase();
    await pumpEventQueue();

    expect(received, hasLength(1));
    expect(outgoing, isEmpty);
  });

  test('the default comes back after the app cancels its subscription', () async {
    final subscription = listen((_) {});
    await subscription.cancel();

    await _deliverPromotedPurchase();
    await pumpEventQueue();

    expect(outgoing, hasLength(1));
    expect(outgoing.single.method, 'make_promoted_purchase');
  });

  test('a listener that throws is not compensated for by the SDK', () async {
    final listenerErrors = <Object>[];
    // The subscription captures the zone it was created in, so the throw is reported there
    // instead of failing this test.
    runZonedGuarded(
      () => listen((_) => throw StateError('listener boom')),
      (error, _) => listenerErrors.add(error),
    );

    await _deliverPromotedPurchase();
    await pumpEventQueue();

    expect(listenerErrors, hasLength(1));
    expect(listenerErrors.single, isA<StateError>());
    expect(outgoing, isEmpty);
  });

  test('a failed automatic purchase is logged as a warning and not retried', () async {
    response = _failure;

    final logs = await capturingLogs(() async {
      await _deliverPromotedPurchase();
      await pumpEventQueue();
    });

    expect(outgoing, hasLength(1));
    expect(logs, hasLength(1));
    expect(logs.single, contains('WARN'));
    expect(logs.single, contains('Failed to complete the promoted purchase automatically'));
  });

  test('a promoted purchase the user cancels is not reported as a failure', () async {
    final logs = await capturingLogs(() async {
      await _deliverPromotedPurchase();
      await pumpEventQueue();
    });

    expect(outgoing, hasLength(1));
    expect(logs, isEmpty);
  });

  test('every promoted purchase event is completed on its own', () async {
    await _deliverPromotedPurchase();
    await _deliverPromotedPurchase();
    await pumpEventQueue();

    expect(outgoing, hasLength(2));
    expect(outgoing.every((call) => call.method == 'make_promoted_purchase'), isTrue);
  });
}

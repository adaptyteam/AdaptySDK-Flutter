/// The contract of [Adapty.didReceivePromotedPurchaseStream]: a subscriber takes the
/// purchase over, and with none the SDK completes it itself. The decision is made per
/// event, so these tests drive it by subscribing and cancelling around delivery.
///
/// Nothing here asserts "no error escaped" explicitly: every case runs in the test's own
/// zone, and `package:test` already fails a test on an unhandled asynchronous error.
/// Wrapping the bodies in `runZonedGuarded` would swallow exactly the failures these tests
/// exist to catch — it is used only where a *subscriber* throws on purpose, to keep that
/// throw away from the test.
///
/// `tearDown` re-checks the outgoing calls after a real delay. Without it every "the SDK
/// must not purchase" assertion fails open: a purchase fired a few milliseconds late would
/// pass here and then land in the next test's recorder.
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
  'is_family_shareable': true,
  'region_code': 'US',
  'price': {
    'amount': 9.99,
    'currency_code': 'USD',
    'currency_symbol': r'$',
    'localized_string': r'$9.99',
  },
  'subscription': {
    'period': {'unit': 'year', 'number_of_units': 1},
    'offer': {
      'offer_identifier': {'id': 'winback-30', 'type': 'win_back'},
      'phases': <dynamic>[],
    },
  },
  // Opaque and round-tripped: its presence in the outgoing request is what proves the SDK
  // hands back the product it received rather than one it rebuilt.
  'payload_data': 'opaque-payload',
};

final _success = jsonEncode({
  'success': {
    'type': 'success',
    'profile': {
      'profile_id': 'profile-id',
      'segment_hash': 'segment-hash',
      'timestamp': 1,
      'is_test_user': false,
    },
  },
});

final _userCancelled = jsonEncode({
  'success': {'type': 'user_cancelled'},
});

final _pending = jsonEncode({
  'success': {'type': 'pending'},
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

  Map<String, dynamic> lastRequest() => jsonDecode(outgoing.last.arguments as String) as Map<String, dynamic>;

  setUp(() {
    outgoing = [];
    response = _success;
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

  tearDown(() async {
    final settled = outgoing.length;
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      outgoing,
      hasLength(settled),
      reason: 'the SDK called native after the test body finished; such a call would otherwise be '
          'recorded against the next test',
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    // setUp installed an incoming handler on a channel shared by the whole isolate.
    _channel.setMethodCallHandler(null);
  });

  test('a promoted purchase with no listener is completed by the SDK', () async {
    await _deliverPromotedPurchase();
    await pumpEventQueue();

    expect(outgoing, hasLength(1));
    expect(outgoing.single.method, 'make_promoted_purchase');

    final request = lastRequest();
    // The request carries the product and nothing else; an extra argument would mean the
    // SDK invented something the native side never asked for.
    expect(request.keys, ['product']);

    final product = request['product'] as Map<String, dynamic>;
    expect(product['vendor_product_id'], 'promoted.product');
    expect(product['payload_data'], 'opaque-payload');

    // A promoted product bought from a promotional offer loses the discount if the offer
    // identifier does not survive the round trip.
    final offer = ((product['subscription'] as Map<String, dynamic>)['offer'] as Map<String, dynamic>);
    expect(offer['offer_identifier'], {'id': 'winback-30', 'type': 'win_back'});
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

    final logs = await capturingLogs(() async {
      await _deliverPromotedPurchase();
      await pumpEventQueue();
    });

    expect(outgoing, isEmpty);
    // Handing the event to the app is not an event worth narrating.
    expect(logs, isEmpty);
    expect(received, hasLength(1));

    final product = received.single;
    expect(product.vendorProductId, 'promoted.product');
    expect(product.localizedTitle, 'Promoted');
    expect(product.localizedDescription, 'Promoted product');
    expect(product.isFamilyShareable, isTrue);
    expect(product.regionCode, 'US');
    expect(product.price.amount, 9.99);
    expect(product.subscription?.offer?.identifier.id, 'winback-30');

    // The app can only complete the purchase with what it was handed, so the opaque payload
    // has to survive delivery as well as the default path.
    await Adapty().makePromotedPurchase(product: product);

    expect(outgoing, hasLength(1));
    expect((lastRequest()['product'] as Map<String, dynamic>)['payload_data'], 'opaque-payload');
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

  test('cancelling one subscription twice does not release another', () async {
    final received = <AdaptyPromotedProduct>[];
    final leaving = listen((_) {});
    listen(received.add);

    await leaving.cancel();
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

  test('a listener whose future rejects is not compensated for by the SDK', () async {
    // The documented usage is an async listener that awaits makePromotedPurchase, so this
    // is the failure shape an app hits in practice.
    final listenerErrors = <Object>[];
    runZonedGuarded(
      () => listen((_) async => throw StateError('async listener boom')),
      (error, _) => listenerErrors.add(error),
    );

    await _deliverPromotedPurchase();
    await pumpEventQueue();

    expect(listenerErrors, hasLength(1));
    expect(outgoing, isEmpty);
  });

  test('a listener that throws does not stop delivery to the others', () async {
    final received = <AdaptyPromotedProduct>[];
    runZonedGuarded(
      () => listen((_) => throw StateError('listener boom')),
      (_, __) {},
    );
    listen(received.add);

    await _deliverPromotedPurchase();
    await pumpEventQueue();

    expect(received, hasLength(1));
    expect(outgoing, isEmpty);
  });

  test('a listener subscribed while an event is in flight waits for the next one', () async {
    final late = <AdaptyPromotedProduct>[];
    listen((_) => listen(late.add));

    await _deliverPromotedPurchase();
    await pumpEventQueue();

    expect(late, isEmpty);
    expect(outgoing, isEmpty);

    await _deliverPromotedPurchase();
    await pumpEventQueue();

    expect(late, hasLength(1));
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
    // Without the reason the line cannot be acted on.
    expect(logs.single, contains('Boom'));
  });

  test('a promoted purchase the user cancels is not reported as a failure', () async {
    response = _userCancelled;

    final logs = await capturingLogs(() async {
      await _deliverPromotedPurchase();
      await pumpEventQueue();
    });

    expect(outgoing, hasLength(1));
    expect(logs, isEmpty);
  });

  test('a promoted purchase left pending is not reported as a failure', () async {
    response = _pending;

    final logs = await capturingLogs(() async {
      await _deliverPromotedPurchase();
      await pumpEventQueue();
    });

    expect(outgoing, hasLength(1));
    expect(logs, isEmpty);
  });

  test('a successful automatic purchase is not reported as a failure', () async {
    response = _success;

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

import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

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
};

Future<void> _deliverPromotedPurchase() {
  final message = const StandardMethodCodec().encodeMethodCall(
    MethodCall('did_receive_promoted_purchase', jsonEncode({'product': _product})),
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

  setUp(() {
    outgoing = [];
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      outgoing.add(call);
      return jsonEncode({
        'success': {'type': 'user_cancelled'},
      });
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('a promoted purchase with no listener is completed by the SDK', () async {
    await _deliverPromotedPurchase();
    await Future<void>.delayed(Duration.zero);

    expect(outgoing, hasLength(1));
    expect(outgoing.single.method, 'make_promoted_purchase');

    final request = jsonDecode(outgoing.single.arguments as String) as Map<String, dynamic>;
    final product = request['product'] as Map<String, dynamic>;
    expect(product['vendor_product_id'], 'promoted.product');
  });

  test('a promoted purchase with a listener goes to the app, not to the SDK', () async {
    final received = <AdaptyPromotedProduct>[];
    final subscription = Adapty().didReceivePromotedPurchaseStream.listen(received.add);
    addTearDown(subscription.cancel);

    await _deliverPromotedPurchase();
    await Future<void>.delayed(Duration.zero);

    expect(received, hasLength(1));
    expect(received.single.vendorProductId, 'promoted.product');
    expect(outgoing, isEmpty);
  });

  test('the default comes back after the app cancels its subscription', () async {
    final subscription = Adapty().didReceivePromotedPurchaseStream.listen((_) {});
    await subscription.cancel();

    await _deliverPromotedPurchase();
    await Future<void>.delayed(Duration.zero);

    expect(outgoing, hasLength(1));
    expect(outgoing.single.method, 'make_promoted_purchase');
  });
}

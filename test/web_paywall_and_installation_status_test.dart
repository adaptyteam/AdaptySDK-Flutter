/// What a web paywall call does without something to open, what it hands back from the native side, and how an
/// installation status the SDK does not know reaches the app.
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_paywall_product.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_transport.dart';
import 'support/test_runtime.dart';

const _product = {
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

Matcher _adaptyError(int code, String message) =>
    isA<AdaptyError>().having((e) => e.code, 'code', code).having((e) => e.message, 'message', message);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTransport transport;

  setUp(() {
    transport = FakeTransport();
    installTestRuntime(transport: transport);
  });

  group('without a paywall and a product', () {
    final wrongParam = _adaptyError(AdaptyErrorCode.wrongParam, 'Either paywall or product parameter must be provided');

    test('createWebPaywallUrl fails with a wrong parameter and asks the native side nothing', () async {
      await expectLater(Adapty().createWebPaywallUrl(), throwsA(wrongParam));

      expect(transport.calls, isEmpty);
    });

    test('openWebPaywall fails with a wrong parameter and asks the native side nothing', () async {
      await expectLater(Adapty().openWebPaywall(), throwsA(wrongParam));

      expect(transport.calls, isEmpty);
    });
  });

  test('createWebPaywallUrl gives the app the URL exactly as the native side wrote it', () async {
    const url = 'https://example.com/Web-Paywall?Id=AbC';
    transport.reply('create_web_paywall_url', url);

    final result = await Adapty().createWebPaywallUrl(product: AdaptyPaywallProductJSONBuilder.fromJsonValue(_product));

    expect(transport.calls.single.$1, 'create_web_paywall_url');
    expect(result, url);
  });

  test('an installation status the SDK does not know fails as an internal error of the plugin', () async {
    transport.reply('get_current_installation_status', {'status': 'future_status'});

    await expectLater(
      Adapty().getCurrentInstallationStatus(),
      throwsA(_adaptyError(AdaptyErrorCode.internalPluginError, 'Unknown installation status: future_status')),
    );
    expect(transport.calls.single.$1, 'get_current_installation_status');
  });
}

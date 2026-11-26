/// The product a purchase sends to the native side: a paywall product goes back to
/// `make_purchase`, `open_web_paywall` and `create_web_paywall_url` with every field it arrived
/// with, and a promoted product goes back to `make_promoted_purchase` with the fields the native
/// side reads. Each string field has a value of its own, so a field read into the property next
/// to it, or an entry dropped from the request, fails a test.
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

/// Every call the SDK made to the native side in the current test, in order.
final _calls = <MethodCall>[];

/// The reply of the mocked native side per method; a method not listed answers `{"success": true}`.
final _replies = <String, Map<String, dynamic>>{};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _calls.clear();
    _replies.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      _calls.add(call);
      return jsonEncode(_replies[call.method] ?? {'success': true});
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('a paywall product from iOS decodes each field into its own property', () async {
    final product = (await _paywallProducts([_iosProduct])).single;

    expect(product.vendorProductId, 'com.app.yearly');
    expect(product.flowProductId, 'flow-product-yearly');
    expect(product.accessLevelId, 'premium');
    expect(product.productType, 'annual');
    expect(product.paywallVariationId, 'paywall-variation-id');
    expect(product.paywallABTestName, 'paywall-ab-test');
    expect(product.paywallName, 'Paywall name');
    expect(product.localizedDescription, 'Premium for a year');
    expect(product.localizedTitle, 'Premium');
    expect(product.regionCode, 'DE');
    expect(product.isFamilyShareable, isTrue);
    expect(product.paywallProductIndex, 2);
    expect(product.price.amount, 119.88);
    expect(product.price.localizedString, '119,88 €');
  });

  test('makePurchase sends a paywall product from iOS back with every field it arrived with', () async {
    final product = (await _paywallProducts([_iosProduct])).single;
    _replies['make_purchase'] = {
      'success': {'type': 'user_cancelled'},
    };

    await Adapty().makePurchase(product: product);

    expect(_request('make_purchase')['product'], _iosProduct);
  });

  test('makePurchase sends a paywall product from Android back with every field it arrived with', () async {
    final product = (await _paywallProducts([_androidProduct])).single;
    _replies['make_purchase'] = {
      'success': {'type': 'user_cancelled'},
    };

    await Adapty().makePurchase(product: product);

    // Android sends no `is_family_shareable`; the product goes back with its default.
    expect(_request('make_purchase')['product'], {..._androidProduct, 'is_family_shareable': false});
  });

  test('openWebPaywall and createWebPaywallUrl send a paywall product as makePurchase does', () async {
    final product = (await _paywallProducts([_iosProduct])).single;
    _replies['create_web_paywall_url'] = {'success': 'https://example.com/paywall'};

    await Adapty().openWebPaywall(product: product);
    await Adapty().createWebPaywallUrl(product: product);

    expect(_request('open_web_paywall')['product'], _iosProduct);
    expect(_request('create_web_paywall_url')['product'], _iosProduct);
  });

  test('makePromotedPurchase sends the purchase intent and the vendor product id', () async {
    await _makePromotedPurchase(_promotedProduct);

    expect(_request('make_promoted_purchase')['product'], {
      'purchase_intent_id': 'purchase-intent-id',
      'vendor_product_id': 'com.app.lifetime',
    });
  });

  test('makePromotedPurchase sends back a payload the promoted product arrived with', () async {
    // Neither native SDK of this version sends a payload with a promoted product; the request
    // still carries one back if it arrives.
    await _makePromotedPurchase({..._promotedProduct, 'payload_data': 'promoted-payload'});

    expect(_request('make_promoted_purchase')['product'], {
      'purchase_intent_id': 'purchase-intent-id',
      'vendor_product_id': 'com.app.lifetime',
      'payload_data': 'promoted-payload',
    });
  });
}

/// Delivers [product] as an incoming promoted purchase and buys it with `makePromotedPurchase`.
Future<void> _makePromotedPurchase(Map<String, dynamic> product) async {
  final received = <AdaptyPromotedProduct>[];
  final subscription = Adapty().didReceivePromotedPurchaseStream.listen(received.add);
  addTearDown(subscription.cancel);
  // Installs the incoming method call handler without going through the native side.
  Adapty().setupAfterHotRestart();
  // The incoming handler sits on a channel shared by the whole isolate.
  addTearDown(() => _channel.setMethodCallHandler(null));
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    _channel.name,
    const StandardMethodCodec().encodeMethodCall(
      MethodCall('did_receive_promoted_purchase', jsonEncode({'product': product})),
    ),
    (_) {},
  );
  await pumpEventQueue();
  _replies['make_promoted_purchase'] = {
    'success': {'type': 'user_cancelled'},
  };

  await Adapty().makePromotedPurchase(product: received.single);
}

/// The arguments of the single call made to [method].
Map<String, dynamic> _request(String method) =>
    _calls.where((call) => call.method == method).map((call) => jsonDecode(call.arguments as String)).single;

/// Fetches a flow with one paywall and no products, through the mocked `get_flow`.
Future<AdaptyFlow> _getFlow() {
  _replies['get_flow'] = {
    'success': {
      'placement': {
        'developer_id': 'placement-id',
        'audience_name': 'Audience',
        'revision': 1,
        'ab_test_name': 'ab-test',
        'placement_audience_version_id': 'placement-audience-version-id',
      },
      'flow_id': 'flow-id',
      'flow_name': 'Flow',
      'variation_id': 'variation-id',
      'remote_configs': <dynamic>[],
      'variations': [
        {
          'paywall_id': 'paywall-id',
          'paywall_name': 'Paywall',
          'variation_id': 'variation-id',
          'products': <dynamic>[],
        },
      ],
      'response_created_at': 0,
    },
  };
  return Adapty().getFlow(placementId: 'placement-id');
}

/// Decodes [products] as the reply of `get_paywall_products`.
Future<List<AdaptyPaywallProduct>> _paywallProducts(List<Map<String, dynamic>> products) async {
  final flow = await _getFlow();
  _replies['get_paywall_products'] = {'success': products};
  return Adapty().getPaywallProducts(flow: flow);
}

const _price = {'amount': 119.88, 'currency_code': 'EUR', 'currency_symbol': '€', 'localized_string': '119,88 €'};

/// A product that is not a subscription, with every field iOS can send.
const _iosProduct = <String, dynamic>{
  'vendor_product_id': 'com.app.yearly',
  'flow_product_id': 'flow-product-yearly',
  'adapty_product_id': 'adapty-product-yearly',
  'paywall_variation_id': 'paywall-variation-id',
  'paywall_ab_test_name': 'paywall-ab-test',
  'paywall_name': 'Paywall name',
  'paywall_product_index': 2,
  'access_level_id': 'premium',
  'product_type': 'annual',
  'localized_description': 'Premium for a year',
  'localized_title': 'Premium',
  'region_code': 'DE',
  'is_family_shareable': true,
  'price': _price,
  'web_purchase_url': 'https://example.com/purchase',
};

/// A product that is not a subscription, as Android sends it: with the payload it needs back and
/// the web purchase URL, without `is_family_shareable` and `region_code`.
const _androidProduct = <String, dynamic>{
  'vendor_product_id': 'com.app.yearly',
  'flow_product_id': 'flow-product-yearly',
  'adapty_product_id': 'adapty-product-yearly',
  'paywall_variation_id': 'paywall-variation-id',
  'paywall_ab_test_name': 'paywall-ab-test',
  'paywall_name': 'Paywall name',
  'paywall_product_index': 2,
  'access_level_id': 'premium',
  'product_type': 'annual',
  'localized_description': 'Premium for a year',
  'localized_title': 'Premium',
  'price': _price,
  'web_purchase_url': 'https://example.com/purchase',
  'payload_data': 'android-payload',
};

/// A promoted product that is not a subscription, as iOS sends it: without a payload.
const _promotedProduct = <String, dynamic>{
  'purchase_intent_id': 'purchase-intent-id',
  'vendor_product_id': 'com.app.lifetime',
  'localized_description': 'Premium for life',
  'localized_title': 'Lifetime',
  'is_family_shareable': false,
  'region_code': 'DE',
  'price': _price,
};

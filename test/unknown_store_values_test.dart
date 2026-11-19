/// Store values this version has no constant for, as a newer native SDK could send them: what
/// the decoders turn them into today, and what goes back to the native side. Next to each
/// fallback, a known value decodes as itself, so a key the decoder stops reading cannot pass as
/// the fallback.
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

  test('an unknown offer type decodes as introductory and goes back as introductory', () async {
    final products = await _paywallProducts([
      _iosProduct(
        offer: {
          'offer_identifier': {'id': 'future-offer-id', 'type': 'future_offer'},
          'phases': <dynamic>[],
        },
      ),
    ]);
    final product = products.single;

    expect(product.subscription!.offer!.identifier.type, AdaptySubscriptionOfferType.introductory);

    _replies['make_purchase'] = {
      'success': {'type': 'user_cancelled'},
    };
    await Adapty().makePurchase(product: product);

    expect(_request('make_purchase')['product']['subscription']['offer']['offer_identifier'], {
      'id': 'future-offer-id',
      'type': 'introductory',
    });
  });

  test('a known offer type decodes as itself and goes back to makePurchase as it arrived', () async {
    final products = await _paywallProducts([
      _iosProduct(offer: _offer('intro-offer', 'introductory')),
      _iosProduct(offer: _offer('promo-offer', 'promotional')),
      _iosProduct(offer: _offer('winback-offer', 'win_back')),
      _iosProduct(offer: _offer('code-offer', 'code')),
    ]);

    expect(products.map((product) => product.subscription!.offer!.identifier.type), [
      AdaptySubscriptionOfferType.introductory,
      AdaptySubscriptionOfferType.promotional,
      AdaptySubscriptionOfferType.winBack,
      AdaptySubscriptionOfferType.code,
    ]);

    _replies['make_purchase'] = {
      'success': {'type': 'user_cancelled'},
    };
    for (final product in products) {
      await Adapty().makePurchase(product: product);
    }

    expect(_sentOfferIdentifiers('make_purchase'), [
      {'id': 'intro-offer', 'type': 'introductory'},
      {'id': 'promo-offer', 'type': 'promotional'},
      {'id': 'winback-offer', 'type': 'win_back'},
      {'id': 'code-offer', 'type': 'code'},
    ]);
  });

  test('a known offer type goes back to the web paywall as it arrived', () async {
    final products = await _paywallProducts([
      _iosProduct(offer: _offer('intro-offer', 'introductory')),
      _iosProduct(offer: _offer('promo-offer', 'promotional')),
      _iosProduct(offer: _offer('winback-offer', 'win_back')),
      _iosProduct(offer: _offer('code-offer', 'code')),
    ]);
    _replies['create_web_paywall_url'] = {'success': 'https://example.com/paywall'};

    for (final product in products) {
      await Adapty().openWebPaywall(product: product);
      await Adapty().createWebPaywallUrl(product: product);
    }

    const sent = [
      {'id': 'intro-offer', 'type': 'introductory'},
      {'id': 'promo-offer', 'type': 'promotional'},
      {'id': 'winback-offer', 'type': 'win_back'},
      {'id': 'code-offer', 'type': 'code'},
    ];
    expect(_sentOfferIdentifiers('open_web_paywall'), sent);
    expect(_sentOfferIdentifiers('create_web_paywall_url'), sent);
  });

  test('a known offer type goes back to makePromotedPurchase as it arrived', () async {
    final products = await _promotedProducts([
      _promotedProduct(offer: _offer('intro-offer', 'introductory')),
      _promotedProduct(offer: _offer('promo-offer', 'promotional')),
      _promotedProduct(offer: _offer('winback-offer', 'win_back')),
      _promotedProduct(offer: _offer('code-offer', 'code')),
    ]);

    for (final product in products) {
      await Adapty().makePromotedPurchase(product: product);
    }

    expect(_sentOfferIdentifiers('make_promoted_purchase'), [
      {'id': 'intro-offer', 'type': 'introductory'},
      {'id': 'promo-offer', 'type': 'promotional'},
      {'id': 'winback-offer', 'type': 'win_back'},
      {'id': 'code-offer', 'type': 'code'},
    ]);
  });

  test('an unknown payment mode decodes as unknown', () async {
    final products = await _paywallProducts([_iosProduct(offer: _introductoryOffer(paymentMode: 'future_mode'))]);

    expect(products.single.subscription!.offer!.phases.single.paymentMode, AdaptyPaymentMode.unknown);
  });

  test('a known payment mode decodes as itself', () async {
    final products = await _paywallProducts([_iosProduct(offer: _introductoryOffer(paymentMode: 'pay_as_you_go'))]);

    expect(products.single.subscription!.offer!.phases.single.paymentMode, AdaptyPaymentMode.payAsYouGo);
  });

  test('an unknown period unit decodes as unknown', () async {
    final products = await _paywallProducts([
      _iosProduct(period: {'unit': 'decade', 'number_of_units': 1}),
    ]);

    final period = products.single.subscription!.period;
    expect(period.unit, AdaptyPeriodUnit.unknown);
    expect(period.numberOfUnits, 1);
  });

  test('an unknown renewal type decodes as autorenewable', () async {
    final products = await _paywallProducts([_androidProduct(renewalType: 'future_renewal')]);

    expect(products.single.subscription!.renewalType, AdaptyRenewalType.autorenewable);
  });

  test('a known renewal type decodes as itself', () async {
    final products = await _paywallProducts([_androidProduct(renewalType: 'prepaid')]);

    expect(products.single.subscription!.renewalType, AdaptyRenewalType.prepaid);
  });
}

/// The decoded arguments of the only call made to [method].
Map<String, dynamic> _request(String method) =>
    _calls.where((call) => call.method == method).map((call) => jsonDecode(call.arguments as String)).single;

/// The `offer_identifier` of the product in every call made to [method], in order.
List<dynamic> _sentOfferIdentifiers(String method) => _calls
    .where((call) => call.method == method)
    .map((call) => jsonDecode(call.arguments as String)['product']['subscription']['offer']['offer_identifier'])
    .toList();

/// Delivers each of [products] as a promoted purchase from the App Store, the way the native side
/// does, and returns them as an app listening to the promoted purchase stream receives them.
Future<List<AdaptyPromotedProduct>> _promotedProducts(List<Map<String, dynamic>> products) async {
  _replies['make_promoted_purchase'] = {
    'success': {'type': 'user_cancelled'},
  };
  // Installs the incoming method call handler without going through the native side.
  Adapty().setupAfterHotRestart();
  // The incoming handler sits on a channel shared by the whole isolate.
  addTearDown(() => _channel.setMethodCallHandler(null));

  final received = <AdaptyPromotedProduct>[];
  final subscription = Adapty().didReceivePromotedPurchaseStream.listen(received.add);
  addTearDown(subscription.cancel);

  for (final product in products) {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('did_receive_promoted_purchase', jsonEncode({'product': product})),
      ),
      (_) {},
    );
  }
  await pumpEventQueue();

  expect(received, hasLength(products.length));
  return received;
}

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

/// A price in euros.
Map<String, dynamic> _eur(num amount, String localizedString) => {
  'amount': amount,
  'currency_code': 'EUR',
  'currency_symbol': '€',
  'localized_string': localizedString,
};

const _year = {'unit': 'year', 'number_of_units': 1};

/// An introductory offer with a single phase of [paymentMode].
Map<String, dynamic> _introductoryOffer({required String paymentMode}) => {
  'offer_identifier': {'id': 'intro-offer', 'type': 'introductory'},
  'phases': [
    {
      'price': _eur(0, '0,00 €'),
      'number_of_periods': 1,
      'payment_mode': paymentMode,
      'subscription_period': {'unit': 'week', 'number_of_units': 1},
    },
  ],
};

/// An offer with no phases, identified by [id] and [type].
Map<String, dynamic> _offer(String id, String type) => {
  'offer_identifier': {'id': id, 'type': type},
  'phases': <dynamic>[],
};

/// A yearly subscription bought from the App Store promotion, carrying [offer].
Map<String, dynamic> _promotedProduct({required Map<String, dynamic> offer}) => {
  'vendor_product_id': 'com.app.yearly',
  'localized_description': 'Premium for a year',
  'localized_title': 'Premium',
  'is_family_shareable': false,
  'region_code': 'DE',
  'price': _eur(119.88, '119,88 €'),
  'subscription': {'group_identifier': '21345678', 'period': _year, 'localized_period': '1 year', 'offer': offer},
};

/// A yearly subscription as the iOS SDK reports it, with [period] and [offer] replaceable to carry
/// a value under test. iOS always sends pricing terms; leaving them out, as here, builds a
/// defensive payload.
Map<String, dynamic> _iosProduct({Map<String, dynamic> period = _year, Map<String, dynamic>? offer}) => {
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
  'subscription': {
    'group_identifier': '21345678',
    'period': period,
    'localized_period': '1 year',
    if (offer != null) 'offer': offer,
  },
};

/// A yearly subscription as the Android SDK reports it: a base plan, no pricing terms. Only
/// Android sends a renewal type; iOS leaves the key out.
Map<String, dynamic> _androidProduct({required String renewalType}) => {
  'vendor_product_id': 'yearly.premium',
  'adapty_product_id': 'adapty-yearly',
  'access_level_id': 'premium',
  'product_type': 'annual',
  'paywall_product_index': 1,
  'paywall_variation_id': 'variation-id',
  'paywall_ab_test_name': 'ab-test',
  'paywall_name': 'Paywall',
  'localized_description': 'Premium for a year',
  'localized_title': 'Premium',
  'price': _eur(119.88, '€119.88'),
  'subscription': {
    'base_plan_id': 'yearly-base',
    'renewal_type': renewalType,
    'period': _year,
    'localized_period': '1 year',
  },
  'payload_data': 'opaque-payload',
};

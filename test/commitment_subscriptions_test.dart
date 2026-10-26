/// Billing plans (commitment subscriptions) across the channel, with payloads shaped like the
/// iOS SDK's. Payloads the iOS SDK does not send are marked as defensive where they are built.
///
/// No test depends on the host platform: none of the keys under test is gated on the device
/// OS, and the fixtures leave out the Android-only product reference keys, which are.
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

  group('billing plan', _billingPlanTests);
  group('product pricing terms', _productPricingTermsTests);
  group('purchase requests', _purchaseRequestTests);
}

void _billingPlanTests() {
  test('the known plans carry their wire values', () {
    expect(AdaptySubscriptionBillingPlan.upFront.value, 'up_front');
    expect(AdaptySubscriptionBillingPlan.monthly.value, 'monthly');
  });

  test('plans compare by value, so a plan unknown to this version is kept and matches itself only', () {
    // Built at run time, as the decoders build them: a const would be the very same instance.
    final monthly = AdaptySubscriptionBillingPlan(['mon', 'thly'].join());
    final futurePlan = AdaptySubscriptionBillingPlan(['future', 'plan'].join('_'));

    expect(monthly, AdaptySubscriptionBillingPlan.monthly);
    expect(monthly.hashCode, AdaptySubscriptionBillingPlan.monthly.hashCode);
    expect({AdaptySubscriptionBillingPlan.monthly}, contains(monthly));
    expect(futurePlan.value, 'future_plan');
    expect(futurePlan, AdaptySubscriptionBillingPlan(['future', 'plan'].join('_')));
    expect(futurePlan, isNot(AdaptySubscriptionBillingPlan.upFront));
    expect(futurePlan, isNot(AdaptySubscriptionBillingPlan.monthly));
    expect(futurePlan.toString(), 'AdaptySubscriptionBillingPlan(future_plan)');
  });
}

void _productPricingTermsTests() {
  test('a product with a monthly plan decodes every field of its pricing terms', () async {
    final products = await _paywallProducts([_iosProduct(pricingTerms: _monthlyTerms())]);

    // Declared with the exported names: dropping an export from the package fails to compile here.
    final product = products.single;
    final AdaptySubscriptionPricingTerms terms = product.subscription!.pricingTerms!;
    final AdaptySubscriptionBillingPlan billingPlan = terms.billingPlan;
    final AdaptySubscriptionCommitmentInfo commitment = terms.commitmentInfo;
    expect(billingPlan, AdaptySubscriptionBillingPlan.monthly);
    expect(terms.billingPrice.amount, 9.99);
    expect(terms.billingPrice.currencyCode, 'EUR');
    expect(terms.billingPrice.currencySymbol, '€');
    expect(terms.billingPrice.localizedString, '9,99 €');
    expect(terms.billingPeriod.unit, AdaptyPeriodUnit.month);
    expect(terms.billingPeriod.numberOfUnits, 1);
    expect(commitment.price.amount, 119.88);
    expect(commitment.price.currencyCode, 'EUR');
    expect(commitment.price.currencySymbol, '€');
    expect(commitment.price.localizedString, '119,88 €');
    expect(commitment.period.unit, AdaptyPeriodUnit.year);
    expect(commitment.period.numberOfUnits, 1);
    // With a monthly plan the product's own price and period are the commitment totals.
    expect(product.price.amount, 119.88);
    expect(product.subscription!.period.unit, AdaptyPeriodUnit.year);
  });

  test('a product billed up front decodes up_front terms equal to its own price and period', () async {
    final products = await _paywallProducts([_iosProduct(pricingTerms: _upFrontTerms())]);

    final terms = products.single.subscription!.pricingTerms!;
    expect(terms.billingPlan, AdaptySubscriptionBillingPlan.upFront);
    expect(terms.billingPrice.amount, 119.88);
    expect(terms.billingPeriod.unit, AdaptyPeriodUnit.year);
    expect(terms.billingPeriod.numberOfUnits, 1);
    expect(terms.commitmentInfo.price.amount, 119.88);
    expect(terms.commitmentInfo.period.unit, AdaptyPeriodUnit.year);
  });

  test('a billing plan unknown to this version decodes with its value unchanged', () async {
    final products = await _paywallProducts([_iosProduct(pricingTerms: _futurePlanTerms())]);

    final terms = products.single.subscription!.pricingTerms!;
    expect(terms.billingPlan.value, 'Future_plan');
    expect(terms.billingPlan, const AdaptySubscriptionBillingPlan('Future_plan'));
    expect(terms.billingPrice.amount, 40);
    expect(terms.billingPrice.localizedString, '40,00 €');
    expect(terms.billingPeriod.numberOfUnits, 4);
    expect(terms.commitmentInfo.price.amount, 120);
  });

  test('pricingTerms is null when a subscription has none, as on Android', () async {
    final products = await _paywallProducts([
      // Defensive: iOS gives every subscription pricing terms.
      _iosProduct(),
      _androidProduct(offer: _introductoryOffer),
      _nonSubscriptionProduct(),
    ]);

    expect(products, hasLength(3));
    expect(products[0].subscription, isNotNull);
    expect(products[0].subscription!.pricingTerms, isNull);
    expect(products[1].subscription!.basePlanId, 'yearly-base');
    expect(products[1].subscription!.pricingTerms, isNull);
    expect(products[2].subscription, isNull);
  });

  test('incomplete pricing terms fail getPaywallProducts with an internal plugin error', () async {
    final incomplete = <String, Map<String, dynamic>>{
      'billing_plan_id': _monthlyTerms()..remove('billing_plan_id'),
      'billing_price': _monthlyTerms()..remove('billing_price'),
      'billing_period': _monthlyTerms()..remove('billing_period'),
      'commitment_info': _monthlyTerms()..remove('commitment_info'),
      'commitment_info.price': _monthlyTerms()..['commitment_info'] = {'period': _year},
      'commitment_info.period': _monthlyTerms()..['commitment_info'] = {'price': _eur(119.88, '119,88 €')},
    };

    for (final entry in incomplete.entries) {
      await expectLater(
        _paywallProducts([_iosProduct(pricingTerms: entry.value)]),
        throwsA(isA<AdaptyError>().having((e) => e.code, 'code', AdaptyErrorCode.internalPluginError)),
        reason: 'pricing terms without ${entry.key}',
      );
    }
  });
}

void _purchaseRequestTests() {
  setUp(() {
    _replies['make_purchase'] = {
      'success': {'type': 'user_cancelled'},
    };
    _replies['create_web_paywall_url'] = {'success': 'https://example.com/paywall'};
  });

  test('makePurchase sends back only the billing plan id and the offer identifier', () async {
    final products = await _paywallProducts([_iosProduct(pricingTerms: _monthlyTerms(), offer: _promotionalOffer)]);

    await Adapty().makePurchase(product: products.single);

    expect(_request('make_purchase')['product']['subscription'], {
      'pricing_terms': {'billing_plan_id': 'monthly'},
      'offer': {
        'offer_identifier': {'id': 'promo_m', 'type': 'promotional'},
      },
    });
  });

  test('makePurchase sends back the billing plan alone, whatever its value, when there is no offer', () async {
    final products = await _paywallProducts([
      _iosProduct(pricingTerms: _upFrontTerms()),
      _iosProduct(pricingTerms: _futurePlanTerms()),
    ]);

    for (final product in products) {
      await Adapty().makePurchase(product: product);
    }

    expect(_requests('make_purchase').map((request) => request['product']['subscription']), [
      {
        'pricing_terms': {'billing_plan_id': 'up_front'},
      },
      {
        'pricing_terms': {'billing_plan_id': 'Future_plan'},
      },
    ]);
  });

  test('a product without pricing terms sends its offer alone, or no subscription at all, as before', () async {
    final products = await _paywallProducts([
      _androidProduct(offer: _introductoryOffer),
      _androidProduct(),
      // Defensive: iOS gives every subscription pricing terms.
      _iosProduct(),
      _nonSubscriptionProduct(),
    ]);

    for (final product in products) {
      await Adapty().makePurchase(product: product);
    }

    final sent = _requests('make_purchase').map((request) => request['product'] as Map<String, dynamic>).toList();
    expect(sent, hasLength(4));
    expect(sent[0]['subscription'], {
      'offer': {
        'offer_identifier': {'id': 'intro-offer', 'type': 'introductory'},
      },
    });
    expect(sent[0]['payload_data'], 'opaque-payload');
    expect(sent[1], isNot(contains('subscription')));
    expect(sent[2], isNot(contains('subscription')));
    expect(sent[3], isNot(contains('subscription')));
  });

  test('openWebPaywall and createWebPaywallUrl send the billing plan of a product as makePurchase does', () async {
    final products = await _paywallProducts([_iosProduct(pricingTerms: _monthlyTerms(), offer: _promotionalOffer)]);

    await Adapty().openWebPaywall(product: products.single);
    await Adapty().createWebPaywallUrl(product: products.single);

    const subscription = {
      'pricing_terms': {'billing_plan_id': 'monthly'},
      'offer': {
        'offer_identifier': {'id': 'promo_m', 'type': 'promotional'},
      },
    };
    expect(_request('open_web_paywall')['product']['subscription'], subscription);
    expect(_request('create_web_paywall_url')['product']['subscription'], subscription);
  });

  test('a billing plan the device cannot buy fails makePurchase with billingPlanUnavailable', () async {
    final products = await _paywallProducts([_iosProduct(pricingTerms: _monthlyTerms())]);
    _replies['make_purchase'] = {
      'error': {'adapty_code': 1060, 'message': 'Billing plan unavailable'},
    };

    expect(AdaptyErrorCode.billingPlanUnavailable, 1060);
    await expectLater(
      Adapty().makePurchase(product: products.single),
      throwsA(isA<AdaptyError>().having((e) => e.code, 'code', AdaptyErrorCode.billingPlanUnavailable)),
    );
  });
}

// ---------------------------------------------------------------------------------------------
// Requests and fixtures. The wire shapes are those the iOS SDK sends; prices are in EUR because
// commitment plans are not offered in the US storefront.
// ---------------------------------------------------------------------------------------------

/// The decoded arguments of every call made to [method], in order.
List<Map<String, dynamic>> _requests(String method) => _calls
    .where((call) => call.method == method)
    .map((call) => jsonDecode(call.arguments as String) as Map<String, dynamic>)
    .toList();

/// The decoded arguments of the only call made to [method].
Map<String, dynamic> _request(String method) => _requests(method).single;

/// Fetches a flow whose single paywall references [products], through the mocked `get_flow`.
Future<AdaptyFlow> _getFlow({List<Map<String, dynamic>> products = const []}) {
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
        {'paywall_id': 'paywall-id', 'paywall_name': 'Paywall', 'variation_id': 'variation-id', 'products': products},
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

/// A price as iOS sends it. A whole [amount] goes over the wire as a JSON integer.
Map<String, dynamic> _eur(num amount, String localizedString) => {
  'amount': amount,
  'currency_code': 'EUR',
  'currency_symbol': '€',
  'localized_string': localizedString,
};

const _year = {'unit': 'year', 'number_of_units': 1};
const _month = {'unit': 'month', 'number_of_units': 1};

/// A yearly product on iOS 26.4 or later in a storefront that offers the monthly plan: 12
/// installments of 9.99.
Map<String, dynamic> _monthlyTerms() => {
  'billing_plan_id': 'monthly',
  'billing_price': _eur(9.99, '9,99 €'),
  'billing_period': _month,
  'commitment_info': {'price': _eur(119.88, '119,88 €'), 'period': _year},
};

/// What iOS reports for every other subscription: the product's own price and period.
Map<String, dynamic> _upFrontTerms() => {
  'billing_plan_id': 'up_front',
  'billing_price': _eur(119.88, '119,88 €'),
  'billing_period': _year,
  'commitment_info': {'price': _eur(119.88, '119,88 €'), 'period': _year},
};

/// Defensive: a plan this version has no constant for, in mixed case so that any normalisation
/// shows, with whole amounts (3 payments of 40 over a year).
Map<String, dynamic> _futurePlanTerms() => {
  'billing_plan_id': 'Future_plan',
  'billing_price': _eur(40, '40,00 €'),
  'billing_period': {'unit': 'month', 'number_of_units': 4},
  'commitment_info': {'price': _eur(120, '120,00 €'), 'period': _year},
};

const _introductoryOffer = {
  'offer_identifier': {'id': 'intro-offer', 'type': 'introductory'},
  'phases': <dynamic>[],
};

const _promotionalOffer = {
  'offer_identifier': {'id': 'promo_m', 'type': 'promotional'},
  'phases': <dynamic>[],
};

/// A yearly subscription as the iOS SDK reports it. iOS always sends [pricingTerms]; leaving
/// them out builds a defensive payload.
Map<String, dynamic> _iosProduct({Map<String, dynamic>? pricingTerms, Map<String, dynamic>? offer}) => {
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
    'period': _year,
    'localized_period': '1 year',
    if (pricingTerms != null) 'pricing_terms': pricingTerms,
    if (offer != null) 'offer': offer,
  },
};

/// A yearly subscription as the Android SDK reports it: a base plan, no pricing terms.
Map<String, dynamic> _androidProduct({Map<String, dynamic>? offer}) => {
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
    'renewal_type': 'autorenewable',
    'period': _year,
    'localized_period': '1 year',
    if (offer != null) 'offer': offer,
  },
  'payload_data': 'opaque-payload',
};

Map<String, dynamic> _nonSubscriptionProduct() => {
  'vendor_product_id': 'com.app.coins',
  'adapty_product_id': 'adapty-coins',
  'access_level_id': 'premium',
  'product_type': 'consumable',
  'paywall_product_index': 2,
  'paywall_variation_id': 'variation-id',
  'paywall_ab_test_name': 'ab-test',
  'paywall_name': 'Paywall',
  'localized_description': '100 coins',
  'localized_title': 'Coins',
  'price': _eur(0.99, '0,99 €'),
};

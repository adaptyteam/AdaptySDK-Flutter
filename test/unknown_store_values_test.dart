/// Store values this version has no constant for, as a newer native SDK could send them: what
/// the decoders turn them into today, and what goes back to the native side.
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

  test('an unknown payment mode decodes as unknown', () async {
    final products = await _paywallProducts([
      _iosProduct(
        offer: {
          'offer_identifier': {'id': 'intro-offer', 'type': 'introductory'},
          'phases': [
            {
              'price': _eur(0, '0,00 €'),
              'number_of_periods': 1,
              'payment_mode': 'future_mode',
              'subscription_period': {'unit': 'week', 'number_of_units': 1},
            },
          ],
        },
      ),
    ]);

    expect(products.single.subscription!.offer!.phases.single.paymentMode, AdaptyPaymentMode.unknown);
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
    final products = await _paywallProducts([_iosProduct(renewalType: 'future_renewal')]);

    expect(products.single.subscription!.renewalType, AdaptyRenewalType.autorenewable);
  });
}

/// The decoded arguments of the only call made to [method].
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

/// A price as iOS sends it.
Map<String, dynamic> _eur(num amount, String localizedString) => {
  'amount': amount,
  'currency_code': 'EUR',
  'currency_symbol': '€',
  'localized_string': localizedString,
};

const _year = {'unit': 'year', 'number_of_units': 1};

/// A yearly subscription as the iOS SDK reports it, with [period], [offer] and [renewalType]
/// replaceable to carry a value under test.
Map<String, dynamic> _iosProduct({
  Map<String, dynamic> period = _year,
  Map<String, dynamic>? offer,
  String? renewalType,
}) => {
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
    if (renewalType != null) 'renewal_type': renewalType,
  },
};

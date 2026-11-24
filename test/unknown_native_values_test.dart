// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package
import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

/// An offer whose type a newer native SDK sends and this version doesn't know.
const _futureOffer = {
  'offer_identifier': {'id': 'future-offer', 'type': 'future_offer_type'},
  'phases': <dynamic>[],
};

const _view = {'id': 'view-id', 'placement_id': 'placement-id', 'variation_id': 'variation-id'};

Map<String, dynamic> _price() => {
  'amount': 119.88,
  'currency_code': 'EUR',
  'currency_symbol': '€',
  'localized_string': '€119.88',
};

Map<String, dynamic> _product({Map<String, dynamic> offer = _futureOffer}) => {
  'vendor_product_id': 'yearly.premium',
  'adapty_product_id': 'adapty-yearly',
  'access_level_id': 'premium',
  'product_type': 'annual',
  'paywall_product_index': 0,
  'paywall_variation_id': 'variation-id',
  'paywall_ab_test_name': 'ab-test',
  'paywall_name': 'Paywall',
  'localized_description': 'Premium for a year',
  'localized_title': 'Premium',
  'price': _price(),
  'subscription': {
    'base_plan_id': 'yearly-base',
    'renewal_type': 'autorenewable',
    'period': {'unit': 'year', 'number_of_units': 1},
    'localized_period': '1 year',
    'offer': offer,
  },
  'payload_data': 'opaque-payload',
};

final _flow = {
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
    {'paywall_id': 'paywall-id', 'paywall_name': 'Paywall', 'variation_id': 'variation-id', 'products': <dynamic>[]},
  ],
  'response_created_at': 0,
};

class _FlowObserver extends AdaptyUIFlowsEventsObserver {
  final purchases = <AdaptyPurchaseResult>[];

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) =>
      purchases.add(purchaseResult);

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) {}
}

class _OnboardingObserver extends AdaptyUIOnboardingsEventsObserver {
  final received = <AdaptyOnboardingsStateUpdatedParams>[];

  @override
  void onboardingViewOnStateUpdatedAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String elementId,
    AdaptyOnboardingsStateUpdatedParams params,
  ) =>
      received.add(params);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  final replies = <String, Object>{};
  final printed = <String>[];

  /// Runs [body] in a guarded zone that records what the SDK prints, and returns what escaped it uncaught.
  Future<List<Object>> capture(Future<void> Function() body) async {
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

  /// The offer identifier the only call to [method] sent back with its product.
  Map<String, dynamic> sentOfferIdentifier(String method) {
    final request = calls.singleWhere((call) => call.method == method);
    final arguments = jsonDecode(request.arguments as String) as Map<String, dynamic>;
    return arguments['product']['subscription']['offer']['offer_identifier'] as Map<String, dynamic>;
  }

  Iterable<String> warnings(String text) => printed.where((line) => line.contains('WARN: $text'));

  Future<AdaptyPaywallProduct> paywallProduct({Map<String, dynamic> offer = _futureOffer}) async {
    replies['get_flow'] = {'success': _flow};
    replies['get_paywall_products'] = {
      'success': [_product(offer: offer)],
    };
    final flow = await Adapty().getFlow(placementId: 'placement-id');
    return (await Adapty().getPaywallProducts(flow: flow)).single;
  }

  setUp(() {
    calls.clear();
    replies.clear();
    printed.clear();
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return jsonEncode(replies[call.method] ?? {'success': true});
    });
  });

  tearDown(() {
    AdaptyUI().setFlowsEventsObserver(null);
    AdaptyUI().setOnboardingsEventsObserver(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('an installation status this version does not know reads as not determined, with a warning', () async {
    replies['get_current_installation_status'] = {
      'success': {'status': 'future_status'},
    };

    Object? status;
    await capture(() async {
      try {
        status = await Adapty().getCurrentInstallationStatus();
      } catch (e) {
        status = e;
      }
    });

    expect(status, isA<AdaptyInstallationStatusNotDetermined>());
    expect(warnings('Adapty received an installation status this SDK version doesn\'t know, "future_status"'), hasLength(1));
  });

  test('a purchase result this version does not know reads as pending, with a warning', () async {
    final product = await paywallProduct();
    replies['make_purchase'] = {
      'success': {'type': 'future_result'},
    };

    Object? result;
    await capture(() async {
      try {
        result = await Adapty().makePurchase(product: product);
      } catch (e) {
        result = e;
      }
    });

    expect(result, isA<AdaptyPurchaseResultPending>());
    expect(warnings('Adapty received a purchase result type this SDK version doesn\'t know, "future_result"'), hasLength(1));
  });

  test('a flow purchase with a result this version does not know is delivered as pending', () async {
    final observer = _FlowObserver();
    AdaptyUI().setFlowsEventsObserver(observer);

    final caught = await capture(
      () => sendEvent('flow_view_did_finish_purchase', {
        'view': _view,
        'product': _product(),
        'purchased_result': {'type': 'future_result'},
      }),
    );

    expect(observer.purchases, hasLength(1));
    expect(observer.purchases.single, isA<AdaptyPurchaseResultPending>());
    expect(caught, isEmpty);
  });

  test('an offer without an id goes back with a null id and its type as it arrived', () async {
    final product = await paywallProduct(
      offer: {
        'offer_identifier': {'type': 'future_offer_type'},
        'phases': <dynamic>[],
      },
    );
    replies['make_purchase'] = {
      'success': {'type': 'user_cancelled'},
    };

    await Adapty().makePurchase(product: product);

    expect(sentOfferIdentifier('make_purchase'), {'id': null, 'type': 'future_offer_type'});
  });

  test('an onboarding element this version does not know is dropped, with a warning that names its type', () async {
    final observer = _OnboardingObserver();
    AdaptyUI().setOnboardingsEventsObserver(observer);

    final caught = await capture(
      () => sendEvent('onboarding_on_state_updated_action', {
        'view': _view,
        'meta': {'onboarding_id': 'onboarding-id', 'screen_cid': 'screen-id', 'screen_index': 0, 'total_screens': 1},
        'action': {'element_id': 'element-id', 'element_type': 'future_element', 'value': <String, dynamic>{}},
      }),
    );

    expect(observer.received, isEmpty);
    expect(
      warnings('Adapty dropped an onboarding state update: this SDK version doesn\'t know its element type "future_element".'),
      hasLength(1),
    );
    expect(printed.where((line) => line.contains('ERROR:')), isEmpty);
    expect(caught, isEmpty);
  });
}

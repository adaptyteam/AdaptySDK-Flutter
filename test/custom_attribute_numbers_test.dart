/// The numbers among the custom attributes of a profile reach the app as a [double] on both platforms.
///
/// A custom attribute is a string or a number set with `setCustomDoubleAttribute`. The native SDK on Android writes a
/// whole number as `30.0`, the one on iOS as `30`, which decodes in Dart as an `int`. Every way a profile reaches the
/// app is checked with the iOS form; the strings and the fractional numbers come as they were sent.
import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_paywall_product.dart';
import 'package:adapty_flutter/src/models/adapty_promoted_product.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_transport.dart';
import 'support/test_runtime.dart';

Map<String, dynamic> _profile(Map<String, dynamic> customAttributes) => {
  'profile_id': 'profile-1',
  'segment_hash': 'segment-hash',
  'timestamp': 1,
  'is_test_user': false,
  'custom_attributes': customAttributes,
};

const _view = {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'};

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

const _promotedProduct = {
  'vendor_product_id': 'promoted.product',
  'localized_description': 'Promoted product',
  'localized_title': 'Promoted',
  'price': {'amount': 9.99, 'currency_code': 'USD', 'currency_symbol': r'$', 'localized_string': r'$9.99'},
};

class _FlowObserver extends AdaptyUIFlowsEventsObserver {
  final profiles = StreamController<AdaptyProfile>();

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) => profiles.add((purchaseResult as AdaptyPurchaseResultSuccess).profile);

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) => profiles.add(profile);

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) {}
}

Future<AdaptyProfile> _flowEvent(FakeTransport fake, String event, Map<String, dynamic> payload) async {
  final observer = _FlowObserver();
  AdaptyUI().setFlowsEventsObserver(observer);
  await fake.deliver(event, {'view': _view, ...payload});
  return observer.profiles.stream.first;
}

/// The ways a profile reaches the app: each one gets the native side to send [profile] and returns what the app got.
final _sources = <(String, Future<AdaptyProfile> Function(FakeTransport fake, Map<String, dynamic> profile))>[
  (
    'getProfile',
    (fake, profile) {
      fake.reply('get_profile', profile);
      return Adapty().getProfile();
    },
  ),
  (
    'restorePurchases',
    (fake, profile) {
      fake.reply('restore_purchases', profile);
      return Adapty().restorePurchases();
    },
  ),
  (
    'makePurchase',
    (fake, profile) async {
      fake.reply('make_purchase', {'type': 'success', 'profile': profile});
      final result = await Adapty().makePurchase(product: AdaptyPaywallProductJSONBuilder.fromJsonValue(_product));
      return (result as AdaptyPurchaseResultSuccess).profile;
    },
  ),
  (
    'makePromotedPurchase',
    (fake, profile) async {
      fake.reply('make_promoted_purchase', {'type': 'success', 'profile': profile});
      final result = await Adapty().makePromotedPurchase(
        product: AdaptyPromotedProductJSONBuilder.fromJsonValue(_promotedProduct),
      );
      return (result as AdaptyPurchaseResultSuccess).profile;
    },
  ),
  (
    'didUpdateProfileStream',
    (fake, profile) async {
      final next = Adapty().didUpdateProfileStream.first;
      await fake.deliver('did_load_latest_profile', {'profile': profile});
      return next;
    },
  ),
  (
    'a purchase finished in a flow',
    (fake, profile) => _flowEvent(fake, 'flow_view_did_finish_purchase', {
      'product': _product,
      'purchased_result': {'type': 'success', 'profile': profile},
    }),
  ),
  (
    'a restore finished in a flow',
    (fake, profile) => _flowEvent(fake, 'flow_view_did_finish_restore', {'profile': profile}),
  ),
];

Future<Map<String, dynamic>> _customAttributesFromGetProfile(Map<String, dynamic> customAttributes) async {
  final fake = FakeTransport()..reply('get_profile', _profile(customAttributes));
  installTestRuntime(transport: fake);
  return (await Adapty().getProfile()).customAttributes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a whole number in the custom attributes, sent as iOS sends it, comes as a double', () {
    for (final (source, receive) in _sources) {
      test('through $source', () async {
        final fake = FakeTransport();
        installTestRuntime(transport: fake);

        final profile = await receive(fake, _profile({'age': 30}));

        expect(profile.customAttributes['age'], isA<double>());
        expect(profile.customAttributes['age'], 30.0);
      });
    }
  });

  group('custom attributes that come as they were sent', () {
    test('a whole number sent as Android sends it comes as a double', () async {
      final attributes = await _customAttributesFromGetProfile({'age': 30.0});

      expect(attributes['age'], isA<double>());
      expect(attributes['age'], 30.0);
    });

    test('a fractional number comes as the same double', () async {
      final attributes = await _customAttributesFromGetProfile({'score': 1.5});

      expect(attributes['score'], isA<double>());
      expect(attributes['score'], 1.5);
    });

    test('a string comes as the same string, also one that reads as a number', () async {
      final attributes = await _customAttributesFromGetProfile({'nickname': 'neo', 'zip': '30'});

      expect(attributes, {'nickname': 'neo', 'zip': '30'});
      expect(attributes['zip'], isA<String>());
    });

    test('an attribute without a value, as iOS sends it, comes as null under its key', () async {
      final attributes = await _customAttributesFromGetProfile({'age': null, 'nickname': 'neo'});

      expect(attributes, {'age': null, 'nickname': 'neo'});
    });

    test('a profile sent without custom attributes has none', () async {
      final fake = FakeTransport()..reply('get_profile', _profile({})..remove('custom_attributes'));
      installTestRuntime(transport: fake);

      final profile = await Adapty().getProfile();

      expect(profile.customAttributes, isEmpty);
    });
  });
}

/// The contract copy of this repository, loaded with its overlays: its entries, the platforms of its
/// methods and events, and a few payloads the SDK really sends.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/contract_schema.dart';

const ios = ContractPlatform.ios;
const android = ContractPlatform.android;
const both = {ios, android};

final ContractSchema schema = ContractSchema.load('.');

List<String> _brief(ValidationReport report) => [
  for (final v in report.violations) '${v.instancePath} ${v.keyword} ${v.schemaPointer}',
];

/// A product as the SDK sends it in a purchase, with the key both natives read and the schema lacks.
Map<String, Object?> _product({bool payloadData = true}) => {
  'vendor_product_id': 'com.example.monthly',
  'adapty_product_id': 'adapty-product-1',
  'access_level_id': 'premium',
  'product_type': 'monthly',
  'paywall_product_index': 0,
  'paywall_variation_id': 'variation-1',
  'paywall_ab_test_name': 'test',
  'paywall_name': 'paywall',
  'flow_product_id': 'flow-product-1',
  if (payloadData) 'payload_data': 'e30=',
};

void main() {
  test('the contract has a request for every method and an entry for every event', () {
    expect(schema.requestMethods, hasLength(48));
    expect(schema.requestMethods, containsAll(['activate', 'get_flow', 'make_purchase', 'get_log_level']));
    expect(schema.eventIds, hasLength(29));
    expect(schema.eventIds, containsAll(['did_load_latest_profile', 'onboarding_on_state_updated_action']));
  });

  test('every request has its response', () {
    for (final method in schema.requestMethods) {
      expect(schema.responseEntry(method).name, schema.requestEntry(method).name.replaceFirst('.Request', '.Response'));
    }
    expect(schema.requestEntry('get_flow').name, 'GetFlow.Request');
    expect(schema.responseEntry('get_flow').mode, ValidationMode.responseOpen);
    expect(schema.eventEntry('did_load_latest_profile').name, 'Event.DidLoadLatestProfile');
  });

  test('methods and events of one platform come from the overlay, the rest belong to both', () {
    expect(schema.methodPlatforms['make_promoted_purchase'], {ios});
    expect(schema.methodPlatforms['present_code_redemption_sheet'], {ios});
    expect(schema.methodPlatforms['get_flow'], both);
    expect(schema.methodPlatforms.keys, unorderedEquals(schema.requestMethods));
    expect(schema.eventPlatforms['did_receive_promoted_purchase'], {ios});
    expect(schema.eventPlatforms['did_load_latest_profile'], both);
    expect(schema.eventPlatforms.keys, unorderedEquals(schema.eventIds));
  });

  test('a flow request as the SDK sends it is valid on both platforms', () {
    for (final platform in both) {
      final report = schema.validateRequest('get_flow', {
        'placement_id': 'placement-1',
        'fetch_policy': {'type': 'reload_revalidating_cache_data'},
        'load_timeout': 5.0,
      }, platform: platform);
      expect(report.violations, isEmpty, reason: report.describe());
    }
  });

  test('a locale in a flow request is a key the contract does not have', () {
    for (final platform in both) {
      final report = schema.validateRequest('get_flow', {'placement_id': 'p', 'locale': 'en'}, platform: platform);
      expect(_brief(report), [r'/locale additionalProperties #/$requests/GetFlow.Request']);
    }
  });

  test('the payload data of a product is required on Android only', () {
    expect(schema.validateRequest('make_purchase', {'product': _product()}, platform: android).violations, isEmpty);
    expect(
      schema.validateRequest('make_purchase', {'product': _product(payloadData: false)}, platform: ios).violations,
      isEmpty,
    );
    expect(
      _brief(schema.validateRequest('make_purchase', {'product': _product(payloadData: false)}, platform: android)),
      [r'/product required #/$defs/AdaptyPaywallProduct.Request'],
    );
  });

  test('an introductory offer may go back without its id on iOS only', () {
    final product = {
      ..._product(),
      'subscription': {
        'offer': {
          'offer_identifier': {'type': 'introductory', 'id': null},
        },
      },
    };
    expect(schema.validateRequest('make_purchase', {'product': product}, platform: ios).violations, isEmpty);
    expect(_brief(schema.validateRequest('make_purchase', {'product': product}, platform: android)), [
      r'/product/subscription/offer/offer_identifier oneOf #/$defs/AdaptySubscriptionOffer.Identifier/oneOf',
    ]);
  });

  test('an Android-only parameter of a purchase is reported on iOS', () {
    final report = schema.validateRequest('make_purchase', {
      'product': _product(),
      'parameters': {'is_offer_personalized': true},
    }, platform: ios);
    expect(_brief(report), [r'/parameters platform_field #/$requests/MakePurchase.Request/properties/parameters']);
  });

  test('an unknown event id or method is an argument error', () {
    expect(() => schema.requestEntry('get_flows'), throwsArgumentError);
    expect(() => schema.eventEntry('flow_view_did_appear_twice'), throwsArgumentError);
  });
}

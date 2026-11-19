/// Payloads derived from a valid one that the contract must reject: only ones invalid by
/// construction, each rejected at the node it was derived for.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/contract_schema.dart';
import '../../tool/contract/src/negative_variants.dart';
import '../../tool/contract/src/overlays.dart';
import '../support/contract/temp_schema.dart';

const ios = ContractPlatform.ios;
const android = ContractPlatform.android;

List<String> _brief(List<NegativeVariant> variants) => [for (final v in variants) '$v'];

/// Every variant is rejected, with a violation about its expected node.
void _expectRejected(SchemaEntry entry, List<NegativeVariant> variants, ContractPlatform platform) {
  expect(variants, isNotEmpty);
  for (final variant in variants) {
    final report = entry.schema.validate(entry, variant.instance, platform: platform);
    expect(report.isValid, isFalse, reason: 'accepted: $variant');
    expect(
      report.violations.any((v) => v.pointsAt(variant.expectedPointer)),
      isTrue,
      reason: '$variant\n${report.describe()}',
    );
  }
}

const _echoPointer = r'#/$requests/Echo.Request';

void main() {
  group('a request', () {
    late final schema = tempSchema(
      requests: r'''
Echo.Request:
  type: object
  required: [method, name, flow]
  properties:
    method: { const: "echo" }
    name: { type: string }
    count: { type: integer }
    level: { type: string, enum: [low, high] }
    flow: { $ref: "#/$defs/Flow" }
    tags: { type: object, additionalProperties: { type: string } }''',
      defs: '''
Flow:
  type: object
  required: [id]
  properties:
    id: { type: string }''',
    );
    final payload = {
      'name': 'n',
      'count': 1,
      'level': 'low',
      'flow': {'id': 'f'},
      'tags': {'a': 'x'},
    };

    test('gives each kind of variant at the node it breaks', () {
      expect(_brief(negativeVariants(schema.requestEntry('echo'), payload, ios)), [
        'remove_required /name -> $_echoPointer',
        'remove_required /flow -> $_echoPointer',
        'extra_key (payload) -> $_echoPointer',
        'swap_type /name -> $_echoPointer/properties/name',
        'swap_type /count -> $_echoPointer/properties/count',
        'swap_type /level -> $_echoPointer/properties/level',
        'foreign_enum /level -> $_echoPointer/properties/level',
        'swap_type /flow -> $_echoPointer/properties/flow',
        'remove_required /flow/id -> $_echoPointer/properties/flow',
        'extra_key /flow -> $_echoPointer/properties/flow',
        r'swap_type /flow/id -> #/$defs/Flow/properties/id',
        'swap_type /tags -> $_echoPointer/properties/tags',
        'swap_type /tags/a -> $_echoPointer/properties/tags/additionalProperties',
      ]);
    });

    test('every variant is rejected at its node', () {
      final entry = schema.requestEntry('echo');
      _expectRejected(entry, negativeVariants(entry, payload, ios), ios);
    });

    test('the method of a request is never changed', () {
      for (final variant in negativeVariants(schema.requestEntry('echo'), payload, ios)) {
        expect(variant.instancePath, isNot(startsWith('/method')));
        expect((variant.instance as Map).containsKey('method'), isFalse);
      }
    });

    test('an integer is swapped for another kind of value, not for a number without a fraction', () {
      final swapped = negativeVariants(
        schema.requestEntry('echo'),
        payload,
        ios,
      ).firstWhere((v) => v.instancePath == '/count' && v.kind == MutantKind.swapType);
      expect((swapped.instance as Map)['count'], isA<String>());
    });

    test('kinds limits what is derived', () {
      final variants = negativeVariants(schema.requestEntry('echo'), payload, ios, kinds: {MutantKind.removeRequired});
      expect(variants.map((v) => v.kind).toSet(), {MutantKind.removeRequired});
      expect(variants, hasLength(3));
    });

    test('a payload typed with Object? keys gives the same variants', () {
      final loose = <Object?, Object?>{
        for (final MapEntry(:key, :value) in payload.entries) key: value is Map ? <dynamic, dynamic>{...value} : value,
      };
      expect(
        _brief(negativeVariants(schema.requestEntry('echo'), loose, ios)),
        _brief(negativeVariants(schema.requestEntry('echo'), payload, ios)),
      );
    });

    test('a payload the contract rejects is an argument error', () {
      expect(() => negativeVariants(schema.requestEntry('echo'), {'name': 'n'}, ios), throwsArgumentError);
    });
  });

  group('combinators', () {
    late final schema = tempSchema(
      requests: r'''
Echo.Request:
  type: object
  required: [method]
  properties:
    method: { const: "echo" }
    value:
      oneOf:
        - type: string
        - type: number
    filter:
      anyOf:
        - enum: [generic, billing]
        - type: string
    code:
      oneOf:
        - const: x
        - type: string
          pattern: "^y"
    policy: { $ref: "#/$defs/Policy" }''',
      defs: '''
Policy:
  type: object
  oneOf:
    - required: [type]
      properties:
        type: { enum: [reload] }
    - required: [type, max_age]
      properties:
        type: { const: cache }
        max_age: { type: number }''',
    );
    final payload = {
      'value': 's',
      'filter': 'generic',
      'code': 'x',
      'policy': {'type': 'cache', 'max_age': 1},
    };

    test('a value of oneOf [string, number] is swapped for a boolean', () {
      final swapped = negativeVariants(
        schema.requestEntry('echo'),
        payload,
        ios,
      ).where((v) => v.instancePath == '/value').toList();
      expect(swapped.map((v) => v.kind), [MutantKind.swapType]);
      expect((swapped.single.instance as Map)['value'], isA<bool>());
    });

    test('no unknown constant where a branch takes any string or a pattern', () {
      final variants = negativeVariants(schema.requestEntry('echo'), payload, ios);
      expect(variants.where((v) => v.kind == MutantKind.foreignEnum).map((v) => v.instancePath), ['/policy/type']);
    });

    test('everything under a combinator is expected at the node of the combinator', () {
      final variants = negativeVariants(
        schema.requestEntry('echo'),
        payload,
        ios,
      ).where((v) => v.instancePath.startsWith('/policy/'));
      expect(_brief(variants.toList()), [
        'remove_required /policy/type -> $_echoPointer/properties/policy',
        'remove_required /policy/max_age -> $_echoPointer/properties/policy',
        'swap_type /policy/type -> $_echoPointer/properties/policy',
        'foreign_enum /policy/type -> $_echoPointer/properties/policy',
        'swap_type /policy/max_age -> $_echoPointer/properties/policy',
      ]);
    });

    test('every variant is rejected at its node', () {
      final entry = schema.requestEntry('echo');
      _expectRejected(entry, negativeVariants(entry, payload, ios), ios);
    });

    test('a key of the parent is a field, a key a branch requires belongs to the combinator', () {
      final openWebPaywall = tempSchema(
        requests: '''
OpenWebPaywall.Request:
  type: object
  required: [method]
  oneOf:
    - required: [product]
    - required: [paywall]
  properties:
    method: { const: "open_web_paywall" }
    product: { type: object }
    paywall: { type: object }''',
      );
      final entry = openWebPaywall.requestEntry('open_web_paywall');
      final variants = negativeVariants(entry, {'product': <String, Object?>{}}, ios);
      expect(_brief(variants), [
        r'remove_required /product -> #/$requests/OpenWebPaywall.Request',
        r'extra_key (payload) -> #/$requests/OpenWebPaywall.Request',
        r'swap_type /product -> #/$requests/OpenWebPaywall.Request/properties/product',
      ]);
      _expectRejected(entry, variants, ios);
    });

    test('a key required by a parent without properties is removed on that parent', () {
      final stateUpdated = tempSchema(
        events: '''
State.Updated:
  type: object
  required: [id, action]
  properties:
    id: { const: "state_updated" }
    action:
      type: object
      required: [element_id, element_type, value]
      oneOf:
        - properties:
            element_id: { type: string }
            element_type: { const: select }
            value: { type: string }
        - properties:
            element_id: { type: string }
            element_type: { const: input }
            value: { type: number }''',
      );
      final entry = stateUpdated.eventEntry('state_updated');
      final variants = negativeVariants(entry, {
        'id': 'state_updated',
        'action': {'element_id': 'e', 'element_type': 'select', 'value': 'v'},
      }, ios);
      const action = r'#/$events/State.Updated/properties/action';
      final removed = variants.firstWhere((v) => v.instancePath == '/action/element_type');
      expect(removed.kind, MutantKind.removeRequired);
      expect(removed.expectedPointer, action);
      final report = stateUpdated.validate(entry, removed.instance, platform: ios);
      expect(report.violations.where((v) => v.keyword == 'required').single.schemaPointer, action);
      _expectRejected(entry, variants, ios);
    });
  });

  group('platforms and overlays', () {
    PlatformFieldRow row(String pointer, ContractPlatform platform) =>
        PlatformFieldRow(pointer: pointer, platforms: {platform}, source: 'test');
    late final schema = tempSchema(
      requests: r'''
Echo.Request:
  type: object
  required: [method]
  properties:
    method: { const: "echo" }
    product: { $ref: "#/$defs/Product" }''',
      defs: '''
Product:
  type: object
  required: [id, shareable]
  properties:
    id: { type: string }
    shareable: { type: boolean }
    token: { type: string }''',
      overlays: ContractOverlays(
        platformRequired: [row(r'#/$defs/Product/properties/token', android)],
        lenientRequired: const [
          PointerNoteRow(pointer: r'#/$defs/Product/properties/shareable', reason: 'r', source: 's', finding: 'f'),
        ],
      ),
    );
    final product = {'id': 'p', 'shareable': true, 'token': 't'};

    test('a key required on one platform is removed on that platform only', () {
      List<String> removed(ContractPlatform platform) => [
        for (final v in negativeVariants(schema.requestEntry('echo'), {'product': product}, platform))
          if (v.kind == MutantKind.removeRequired) v.instancePath,
      ];
      expect(removed(android), ['/product/id', '/product/shareable', '/product/token']);
      expect(removed(ios), ['/product/id', '/product/shareable']);
    });

    test('a response keeps its lenient keys and gets no unknown keys', () {
      final entry = schema.entryAt(r'#/$defs/Product', ValidationMode.responseOpen);
      final variants = negativeVariants(entry, product, ios);
      expect(variants.where((v) => v.kind == MutantKind.extraKey), isEmpty);
      expect(variants.where((v) => v.kind == MutantKind.removeRequired).map((v) => v.instancePath), ['/id']);
      _expectRejected(entry, variants, ios);
    });
  });

  group('nodes without variants', () {
    test('a value node with nothing to break has no variants', () {
      final schema = tempSchema(
        requests: '''
Echo.Request:
  type: object
  required: [method]
  properties:
    method: { const: "echo" }
    note: { description: "anything" }
    name: { type: string }''',
      );
      expect(nodesWithoutNegativeVariants(schema), [r'#/$requests/Echo.Request/properties/note']);
      expect(
        negativeVariants(schema.requestEntry('echo'), {'note': 1}, ios).where((v) => v.instancePath == '/note'),
        isEmpty,
      );
    });

    test('the nodes of the contract without variants are exactly the listed ones', () {
      final schema = ContractSchema.load('.');
      expect(
        nodesWithoutNegativeVariants(schema),
        unorderedEquals(schema.overlays.noNegativeVariants.map((r) => r.pointer)),
        reason:
            'a node without variants needs a row in no_negative_variants.yaml after triage; a listed node that '
            'has variants now leaves the list',
      );
    });
  });

  group('payloads of the contract', () {
    late final schema = ContractSchema.load('.');

    test('every variant of a flow request is rejected at its node', () {
      final entry = schema.requestEntry('get_flow');
      final payload = {
        'placement_id': 'placement-1',
        'fetch_policy': {'type': 'return_cache_data_if_not_expired_else_load', 'max_age': 60},
        'load_timeout': 5,
      };
      for (final platform in ContractPlatform.values) {
        _expectRejected(entry, negativeVariants(entry, payload, platform), platform);
      }
    });

    test('every variant of a purchase on Android is rejected at its node', () {
      final entry = schema.requestEntry('make_purchase');
      final payload = {
        'product': {
          'vendor_product_id': 'com.example.monthly',
          'adapty_product_id': 'adapty-product-1',
          'access_level_id': 'premium',
          'product_type': 'monthly',
          'paywall_product_index': 0,
          'paywall_variation_id': 'variation-1',
          'paywall_ab_test_name': 'test',
          'paywall_name': 'paywall',
          'flow_product_id': 'flow-product-1',
          'payload_data': 'e30=',
          'subscription': {
            'offer': {
              'offer_identifier': {'type': 'introductory', 'id': 'intro-1'},
            },
          },
        },
        'parameters': {
          'is_offer_personalized': true,
          'subscription_update_params': {'old_sub_vendor_product_id': 'old', 'replacement_mode': 'deferred'},
        },
      };
      final variants = negativeVariants(entry, payload, android);
      expect(variants.where((v) => v.kind == MutantKind.extraKey), hasLength(7));
      _expectRejected(entry, variants, android);
    });
  });
}

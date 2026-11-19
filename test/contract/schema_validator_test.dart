/// The validator of the contract schema, on small schemas written here: one group per keyword and
/// per rule of the closed request world and of the platform overlays.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/contract_schema.dart';
import '../../tool/contract/src/overlays.dart';
import '../support/contract/temp_schema.dart';

const ios = ContractPlatform.ios;
const android = ContractPlatform.android;

/// Each violation as `<instance path> <keyword> <schema pointer>`.
List<String> _brief(ValidationReport report) => [
  for (final v in report.violations) '${v.instancePath} ${v.keyword} ${v.schemaPointer}',
];

/// A request entry `Echo.Request` for the method `echo` with the given properties block (indented
/// by four spaces) and the given required list.
String _echo(String properties, {String required = '[method]', String extra = ''}) =>
    '''
Echo.Request:
  type: object
  required: $required
  properties:
    method: { const: "echo" }
$properties
$extra''';

Matcher _shapeError(String message) => throwsA(isA<ContractShapeError>().having((e) => e.message, 'message', message));

void main() {
  group('type', () {
    late final schema = tempSchema(
      requests: _echo('''
    s: { type: string }
    i: { type: integer }
    n: { type: number }
    b: { type: boolean }
    a: { type: array }
    o: { type: object }'''),
    );

    test('a value of the declared type passes', () {
      final report = schema.validateRequest('echo', {
        's': 'x',
        'i': 3,
        'n': 1.5,
        'b': true,
        'a': <Object?>[],
        'o': <String, Object?>{},
      }, platform: ios);
      expect(report.violations, isEmpty);
    });

    test('an integer is a number without a fraction, whatever the JSON decoder made of it', () {
      expect(schema.validateRequest('echo', {'i': 3.0, 'n': 3}, platform: ios).violations, isEmpty);
      expect(_brief(schema.validateRequest('echo', {'i': 3.5}, platform: ios)), [
        r'/i type #/$requests/Echo.Request/properties/i',
      ]);
      expect(_brief(schema.validateRequest('echo', {'i': '3'}, platform: ios)), [
        r'/i type #/$requests/Echo.Request/properties/i',
      ]);
    });

    test('null is not a value of any declared type', () {
      expect(_brief(schema.validateRequest('echo', {'s': null, 'o': null}, platform: ios)), [
        r'/s type #/$requests/Echo.Request/properties/s',
        r'/o type #/$requests/Echo.Request/properties/o',
      ]);
    });
  });

  group('const, enum, pattern, minimum', () {
    late final schema = tempSchema(
      requests: _echo('''
    kind: { const: "a" }
    level: { type: string, enum: [low, high] }
    id: { type: string, pattern: "^[0-9]+\$" }
    count: { type: integer, minimum: 1 }'''),
    );

    test('values inside the constraints pass', () {
      final report = schema.validateRequest('echo', {
        'kind': 'a',
        'level': 'high',
        'id': '42',
        'count': 1,
      }, platform: ios);
      expect(report.violations, isEmpty);
    });

    test('each constraint reports its own keyword', () {
      final report = schema.validateRequest('echo', {
        'kind': 'b',
        'level': 'mid',
        'id': '4x',
        'count': 0,
      }, platform: ios);
      expect(_brief(report), [
        r'/kind const #/$requests/Echo.Request/properties/kind',
        r'/level enum #/$requests/Echo.Request/properties/level',
        r'/id pattern #/$requests/Echo.Request/properties/id',
        r'/count minimum #/$requests/Echo.Request/properties/count',
      ]);
    });
  });

  group('required and the method of a request', () {
    late final schema = tempSchema(requests: _echo('    name: { type: string }', required: '[method, name]'));

    test('the method comes from the call, not from the arguments', () {
      expect(schema.validateRequest('echo', {'name': 'x'}, platform: ios).violations, isEmpty);
    });

    test('a missing required key is reported on the object', () {
      final report = schema.validateRequest('echo', {}, platform: ios);
      expect(_brief(report), [r' required #/$requests/Echo.Request']);
      expect(report.violations.single.detail, contains('"name"'));
    });

    test('a request entry is found by its method, not by its name', () {
      expect(schema.requestEntry('echo').name, 'Echo.Request');
      expect(() => schema.requestEntry('Echo.Request'), throwsArgumentError);
    });
  });

  group(r'$ref', () {
    late final schema = tempSchema(
      requests: _echo(r'''
    when: { $ref: "#/$defs/Date", description: "local time", default: "2020-01-01", nullable: false }
    image: { $ref: "#/$assets/Image" }'''),
      defs: '''
Date: { type: string, pattern: "^[0-9]{4}-" }''',
      assets: '''
Image:
  type: object
  required: [id]
  properties:
    id: { type: string, contentEncoding: base64, format: byte, example: "AA==" }''',
    );

    test(r'a $ref into $defs or $assets is followed, with annotations beside it', () {
      expect(
        schema.validateRequest('echo', {
          'when': '2026-11-19',
          'image': {'id': 'AA=='},
        }, platform: ios).violations,
        isEmpty,
      );
    });

    test(r'a violation behind a $ref names the target and the node it came through', () {
      final report = schema.validateRequest('echo', {'when': 5}, platform: ios);
      expect(_brief(report), [r'/when type #/$defs/Date']);
      expect(report.violations.single.via, [r'#/$requests/Echo.Request/properties/when']);
    });

    test(r'an unresolvable $ref is a shape error of the schema', () {
      expect(
        () => tempSchema(requests: _echo(r'    x: { $ref: "#/$defs/Missing" }')),
        _shapeError(r"unresolvable $ref '#/$defs/Missing' at #/$requests/Echo.Request/properties/x"),
      );
    });
  });

  group('items and additionalProperties', () {
    late final schema = tempSchema(
      requests: _echo('''
    tags: { type: array, items: { type: string } }
    attributes:
      type: object
      additionalProperties: { type: integer }'''),
    );

    test('every item is checked against items', () {
      expect(
        _brief(
          schema.validateRequest('echo', {
            'tags': ['a', 1],
          }, platform: ios),
        ),
        [r'/tags/1 type #/$requests/Echo.Request/properties/tags/items'],
      );
    });

    test('a dictionary accepts any key and checks every value', () {
      expect(
        schema.validateRequest('echo', {
          'attributes': {'any': 1, 'other': 2},
        }, platform: ios).violations,
        isEmpty,
      );
      expect(
        _brief(
          schema.validateRequest('echo', {
            'attributes': {'any': 'x'},
          }, platform: ios),
        ),
        [r'/attributes/any type #/$requests/Echo.Request/properties/attributes/additionalProperties'],
      );
    });

    test('propertyNames with annotations only does not restrict the keys', () {
      final withNames = tempSchema(
        requests: _echo('''
    params:
      type: object
      propertyNames: { description: "a product id" }
      additionalProperties: { type: boolean }'''),
      );
      expect(
        withNames.validateRequest('echo', {
          'params': {'any id': true},
        }, platform: ios).violations,
        isEmpty,
      );
    });
  });

  group('the closed request world', () {
    late final schema = tempSchema(
      requests: _echo(r'''
    flow: { $ref: "#/$defs/Flow" }'''),
      defs: '''
Flow:
  type: object
  required: [id]
  properties:
    id: { type: string }''',
    );

    test('an unknown key of a request is reported at the outermost node of its object', () {
      expect(_brief(schema.validateRequest('echo', {'locale': 'en'}, platform: ios)), [
        r'/locale additionalProperties #/$requests/Echo.Request',
      ]);
      expect(
        _brief(
          schema.validateRequest('echo', {
            'flow': {'id': 'f', 'name': 'n'},
          }, platform: ios),
        ),
        [r'/flow/name additionalProperties #/$requests/Echo.Request/properties/flow'],
      );
    });

    test('an unknown key of a response is allowed', () {
      final flow = schema.entryAt(r'#/$defs/Flow', ValidationMode.responseOpen);
      expect(schema.validate(flow, {'id': 'f', 'name': 'n'}, platform: ios).violations, isEmpty);
    });

    test('an object without declared properties is open', () {
      final open = tempSchema(requests: _echo('    payload: { type: object }'));
      expect(
        open.validateRequest('echo', {
          'payload': {'anything': 1},
        }, platform: ios).violations,
        isEmpty,
      );
    });

    test('a property named type is a property, not the keyword', () {
      final typed = tempSchema(
        requests: _echo('''
    policy:
      type: object
      properties:
        type: { const: reload }'''),
      );
      expect(
        typed.validateRequest('echo', {
          'policy': {'type': 'reload'},
        }, platform: ios).violations,
        isEmpty,
      );
      expect(
        _brief(
          typed.validateRequest('echo', {
            'policy': {'type': 'cache'},
          }, platform: ios),
        ),
        [r'/policy/type const #/$requests/Echo.Request/properties/policy/properties/type'],
      );
    });
  });

  group('oneOf and anyOf', () {
    // A parent with properties and branches with their own properties.
    late final setFallback = tempSchema(
      requests: '''
SetFallback.Request:
  type: object
  required: [method]
  properties:
    method: { const: "set_fallback" }
  oneOf:
    - required: [asset_id]
      properties:
        asset_id: { type: string }
    - required: [path]
      properties:
        path: { type: string }''',
    );

    test('the keys of the matched branch are allowed in a request', () {
      expect(setFallback.validateRequest('set_fallback', {'asset_id': 'a'}, platform: ios).violations, isEmpty);
      expect(setFallback.validateRequest('set_fallback', {'path': 'p'}, platform: ios).violations, isEmpty);
    });

    test('a key only a branch that did not match declares is not allowed', () {
      expect(_brief(setFallback.validateRequest('set_fallback', {'asset_id': 'a', 'path': 5}, platform: ios)), [
        r'/path additionalProperties #/$requests/SetFallback.Request',
      ]);
    });

    test('no matching branch is one violation that names the nearest branch', () {
      final report = setFallback.validateRequest('set_fallback', {'asset_id': 5}, platform: ios);
      expect(_brief(report), [r' oneOf #/$requests/SetFallback.Request/oneOf']);
      expect(report.violations.single.detail, contains('nearest branch 0'));
      expect(report.violations.single.detail, contains(r'/asset_id: type at #/$requests/SetFallback.Request/oneOf/0'));
    });

    // A parent with properties and branches with required only.
    late final openWebPaywall = tempSchema(
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

    test('branches with required only: one of the keys passes, both match two branches', () {
      expect(
        openWebPaywall.validateRequest('open_web_paywall', {'product': <String, Object?>{}}, platform: ios).violations,
        isEmpty,
      );
      final report = openWebPaywall.validateRequest('open_web_paywall', {
        'product': <String, Object?>{},
        'paywall': <String, Object?>{},
      }, platform: ios);
      expect(_brief(report), [r' oneOf #/$requests/OpenWebPaywall.Request/oneOf']);
      expect(report.violations.single.detail, contains('branches 0, 1 all match'));
    });

    // A parent with required and no properties, all properties in the branches.
    late final stateUpdated = tempSchema(
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
            value:
              type: object
              required: [type, value]
              oneOf:
                - properties:
                    type: { enum: [text, email] }
                    value: { type: string }
                - properties:
                    type: { const: number }
                    value: { type: number }''',
    );

    test('a required key of a parent without properties is reported on that parent', () {
      final report = stateUpdated.validateEvent('state_updated', {
        'id': 'state_updated',
        'action': {'element_id': 'e', 'value': 'v'},
      }, platform: ios);
      expect(_brief(report), contains(r'/action required #/$events/State.Updated/properties/action'));
    });

    test('nested branches choose by their constants', () {
      expect(
        stateUpdated.validateEvent('state_updated', {
          'id': 'state_updated',
          'action': {
            'element_id': 'e',
            'element_type': 'input',
            'value': {'type': 'number', 'value': 3},
          },
        }, platform: ios).violations,
        isEmpty,
      );
    });

    late final overlapping = tempSchema(
      events: '''
Analytics:
  type: object
  required: [id, name]
  properties:
    id: { const: "analytics" }
    name:
      oneOf:
        - type: string
        - enum: [started, finished]''',
    );
    const nameNode = r'#/$events/Analytics/properties/name';

    test('a value matching two branches breaks oneOf', () {
      expect(_brief(overlapping.validateEvent('analytics', {'id': 'analytics', 'name': 'started'}, platform: ios)), [
        '/name oneOf $nameNode/oneOf',
      ]);
    });

    test('a schema fix reads overlapping branches as anyOf', () {
      final fixed = ContractSchema.fromYaml(
        overlapping.text,
        overlays: const ContractOverlays(
          schemaFixes: [
            SchemaFixRow(
              pointer: nameNode,
              kind: SchemaFixKind.oneOfToAnyOf,
              reason: 'branches overlap',
              source: 'test',
              finding: 'test',
            ),
          ],
        ),
      );
      expect(
        fixed.validateEvent('analytics', {'id': 'analytics', 'name': 'started'}, platform: ios).violations,
        isEmpty,
      );
      expect(_brief(fixed.validateEvent('analytics', {'id': 'analytics', 'name': 5}, platform: ios)), [
        '/name anyOf $nameNode/oneOf',
      ]);
    });

    test('anyOf passes with any number of matching branches', () {
      final any = tempSchema(
        requests: _echo('''
    filter:
      anyOf:
        - enum: [generic, billing]
        - type: string'''),
      );
      expect(any.validateRequest('echo', {'filter': 'billing'}, platform: ios).violations, isEmpty);
      expect(_brief(any.validateRequest('echo', {'filter': 1}, platform: ios)), [
        r'/filter anyOf #/$requests/Echo.Request/properties/filter/anyOf',
      ]);
    });
  });

  group('pointers of violations', () {
    late final schema = tempSchema(
      requests: _echo(r'''
    flow: { $ref: "#/$defs/Flow" }'''),
      defs: r'''
Flow:
  type: object
  properties:
    policy: { $ref: "#/$defs/Policy" }
Policy:
  type: object
  oneOf:
    - properties:
        type: { const: reload }
    - properties:
        type: { const: cache }
        max_age: { type: number }''',
    );

    test(r'a violation points at its keyword node and at the nearest $ref node only', () {
      final report = schema.validateRequest('echo', {
        'flow': {
          'policy': {'type': 'never'},
        },
      }, platform: ios);
      final violation = report.violations.single;
      expect(violation.schemaPointer, r'#/$defs/Policy/oneOf');
      expect(violation.pointsAt(r'#/$defs/Policy/oneOf'), isTrue);
      expect(violation.pointsAt(r'#/$defs/Policy'), isTrue, reason: 'the node of a combinator without /oneOf');
      expect(violation.pointsAt(r'#/$defs/Flow/properties/policy'), isTrue, reason: 'the nearest node with a ref');
      expect(violation.pointsAt(r'#/$requests/Echo.Request/properties/flow'), isFalse, reason: 'a farther node');
      expect(violation.pointsAt(r'#/$requests/Echo.Request'), isFalse, reason: 'an ancestor');
    });

    test('an unknown key under a ref is reported at the property that holds the object', () {
      final report = schema.validateRequest('echo', {
        'flow': {
          'policy': {'type': 'reload'},
          'extra': 1,
        },
      }, platform: ios);
      expect(_brief(report), [r'/flow/extra additionalProperties #/$requests/Echo.Request/properties/flow']);
    });
  });

  group('platform overlays', () {
    final requests = _echo(r'''
    token: { type: string }
    paddings: { type: boolean }
    params: { $ref: "#/$defs/Params" }
    offer: { $ref: "#/$defs/Offer" }''');
    final defs = r'''
Params:
  type: object
  properties:
    update: { $ref: "#/$defs/Update" }
    personalized: { type: boolean }
Update:
  type: object
  properties:
    mode: { type: string }
Offer:
  type: object
  oneOf:
    - required: [type]
      properties:
        id: { type: string }
        type: { const: introductory }
    - required: [type]
      properties:
        id: { type: string }
        type: { const: code }
Product:
  type: object
  required: [id, shareable]
  properties:
    id: { type: string }
    shareable: { type: boolean }
    group: { type: string }''';
    PlatformFieldRow row(String pointer, ContractPlatform platform) =>
        PlatformFieldRow(pointer: pointer, platforms: {platform}, source: 'test');

    late final schema = tempSchema(
      requests: requests,
      defs: defs,
      overlays: ContractOverlays(
        platformFields: [
          row(r'#/$requests/Echo.Request/properties/paddings', android),
          row(r'#/$requests/Echo.Request/properties/params', android),
          row(r'#/$defs/Params/properties/personalized', android),
          row(r'#/$defs/Update', android),
          row(r'#/$defs/Offer/oneOf/1', ios),
        ],
        platformRequired: [
          row(r'#/$defs/Product/properties/shareable', ios),
          row(r'#/$defs/Product/properties/group', ios),
          row(r'#/$defs/Offer/oneOf/0/properties/id', android),
        ],
      ),
    );

    test('a field of the other platform in a request is one platform_field violation', () {
      expect(_brief(schema.validateRequest('echo', {'paddings': true}, platform: ios)), [
        r'/paddings platform_field #/$requests/Echo.Request/properties/paddings',
      ]);
      expect(schema.validateRequest('echo', {'paddings': true}, platform: android).violations, isEmpty);
    });

    test('the fields nested in a field of the other platform add no violations', () {
      final report = schema.validateRequest('echo', {
        'params': {
          'personalized': true,
          'update': {'mode': 'm'},
        },
      }, platform: ios);
      expect(_brief(report), [r'/params platform_field #/$requests/Echo.Request/properties/params']);
    });

    test(r'a $defs entry of the other platform is reported when a ref enters it', () {
      final viaDef = tempSchema(
        requests: _echo(r'    update: { $ref: "#/$defs/Update" }'),
        defs: defs,
        overlays: ContractOverlays(platformFields: [row(r'#/$defs/Update', android)]),
      );
      expect(_brief(viaDef.validateRequest('echo', {'update': <String, Object?>{}}, platform: ios)), [
        r'/update platform_field #/$defs/Update',
      ]);
    });

    test('a branch of the other platform is reported after it matched', () {
      final report = schema.validateRequest('echo', {
        'offer': {'type': 'code', 'id': 'c'},
      }, platform: android);
      expect(_brief(report), [r'/offer platform_field #/$defs/Offer/oneOf/1']);
      expect(
        schema.validateRequest('echo', {
          'offer': {'type': 'code'},
        }, platform: ios).violations,
        isEmpty,
      );
    });

    test('a field of the other platform in a response is allowed', () {
      final params = schema.entryAt(r'#/$defs/Params', ValidationMode.responseOpen);
      expect(schema.validate(params, {'personalized': true}, platform: ios).violations, isEmpty);
    });

    test('a field required on one platform is required there only', () {
      final product = schema.entryAt(r'#/$defs/Product', ValidationMode.responseOpen);
      expect(_brief(schema.validate(product, {'id': 'p', 'group': 'g'}, platform: ios)), [
        r' required #/$defs/Product',
      ]);
      expect(schema.validate(product, {'id': 'p'}, platform: android).violations, isEmpty);
    });

    test('a field outside required is required on the platform its row names', () {
      final product = schema.entryAt(r'#/$defs/Product', ValidationMode.responseOpen);
      final report = schema.validate(product, {'id': 'p', 'shareable': true}, platform: ios);
      expect(_brief(report), [r' required #/$defs/Product']);
      expect(report.violations.single.detail, contains('"group"'));
    });

    test('platform requirements apply inside the branch that declares them', () {
      expect(
        _brief(
          schema.validateRequest('echo', {
            'offer': {'type': 'introductory'},
          }, platform: android),
        ),
        [r'/offer oneOf #/$defs/Offer/oneOf'],
      );
      expect(
        schema.validateRequest('echo', {
          'offer': {'type': 'introductory'},
        }, platform: ios).violations,
        isEmpty,
      );
    });

    test('a row covered by a field of the same platform is not applied', () {
      final covered = tempSchema(
        requests: requests,
        defs: defs,
        overlays: const ContractOverlays(
          platformFields: [
            PlatformFieldRow(
              pointer: r'#/$defs/Params/properties/personalized',
              platforms: {android},
              source: 'test',
              coveredBy: r'#/$requests/Echo.Request/properties/params',
            ),
          ],
        ),
      );
      expect(
        covered.validateRequest('echo', {
          'params': {'personalized': true},
        }, platform: ios).violations,
        isEmpty,
      );
    });
  });

  group('other overlays', () {
    final defs = '''
Product:
  type: object
  required: [id, shareable]
  properties:
    id: { type: string }
    shareable: { type: boolean }
    note: { type: string }
Attributes:
  type: object
  additionalProperties: { type: string }''';

    test('a lenient required field may be missing in a response, not in a request', () {
      final schema = tempSchema(
        requests: _echo(r'    product: { $ref: "#/$defs/Product" }'),
        defs: defs,
        overlays: const ContractOverlays(
          lenientRequired: [
            PointerNoteRow(pointer: r'#/$defs/Product/properties/shareable', reason: 'r', source: 's', finding: 'f'),
          ],
        ),
      );
      final product = schema.entryAt(r'#/$defs/Product', ValidationMode.responseOpen);
      expect(schema.validate(product, {'id': 'p'}, platform: ios).violations, isEmpty);
      expect(
        _brief(
          schema.validateRequest('echo', {
            'product': {'id': 'p'},
          }, platform: ios),
        ),
        [r'/product required #/$defs/Product'],
      );
    });

    test('null is allowed only where a nullable row says so', () {
      final schema = tempSchema(
        requests: _echo(r'''
    product: { $ref: "#/$defs/Product" }
    attributes: { $ref: "#/$defs/Attributes" }'''),
        defs: defs,
        overlays: const ContractOverlays(
          nullable: [
            PointerNoteRow(pointer: r'#/$defs/Attributes/additionalProperties', reason: 'r', source: 's', finding: 'f'),
          ],
        ),
      );
      expect(
        schema.validateRequest('echo', {
          'attributes': {'removed': null},
        }, platform: ios).violations,
        isEmpty,
      );
      expect(
        _brief(
          schema.validateRequest('echo', {
            'product': {'id': 'p', 'shareable': true, 'note': null},
          }, platform: ios),
        ),
        [r'/product/note type #/$defs/Product/properties/note'],
      );
    });

    test('a schema fix adds a property the schema lacks, with its schema and platforms', () {
      final schema = tempSchema(
        requests: _echo(r'    product: { $ref: "#/$defs/Product" }'),
        defs: defs,
        overlays: const ContractOverlays(
          schemaFixes: [
            SchemaFixRow(
              pointer: r'#/$defs/Product/properties/flow_product_id',
              kind: SchemaFixKind.addProperty,
              schema: {'type': 'string'},
              platforms: {ios},
              reason: 'r',
              source: 's',
              finding: 'f',
            ),
          ],
        ),
      );
      final product = {'id': 'p', 'shareable': true, 'flow_product_id': 'fp'};
      expect(schema.validateRequest('echo', {'product': product}, platform: ios).violations, isEmpty);
      expect(
        _brief(
          schema.validateRequest('echo', {
            'product': {...product, 'flow_product_id': 1},
          }, platform: ios),
        ),
        [r'/product/flow_product_id type #/$defs/Product/properties/flow_product_id'],
      );
      expect(_brief(schema.validateRequest('echo', {'product': product}, platform: android)), [
        r'/product/flow_product_id additionalProperties #/$requests/Echo.Request/properties/product',
      ]);
    });
  });

  group('the shape of the schema', () {
    test('an unsupported keyword is a shape error with its node', () {
      expect(
        () => tempSchema(defs: 'X: { allOf: [] }'),
        _shapeError(r"unsupported schema keyword 'allOf' at #/$defs/X"),
      );
    });

    test('nullable: true is a shape error; nullable: false is an annotation', () {
      expect(
        () => tempSchema(defs: 'X: { type: string, nullable: true }'),
        _shapeError(r"unsupported schema keyword 'nullable: true' at #/$defs/X"),
      );
      expect(tempSchema(defs: 'X: { type: string, nullable: false, title: t }').requestMethods, isEmpty);
    });

    test('propertyNames with a constraint is a shape error', () {
      expect(
        () => tempSchema(defs: 'X: { type: object, propertyNames: { pattern: "^a" } }'),
        _shapeError(r"unsupported schema keyword 'pattern' at #/$defs/X/propertyNames"),
      );
    });

    test('an unsupported keyword in an added property is a shape error', () {
      expect(
        () => tempSchema(
          defs: 'X: { type: object, properties: {} }',
          overlays: const ContractOverlays(
            schemaFixes: [
              SchemaFixRow(
                pointer: r'#/$defs/X/properties/y',
                kind: SchemaFixKind.addProperty,
                schema: {'maxLength': 3},
                reason: 'r',
                source: 's',
                finding: 'f',
              ),
            ],
          ),
        ),
        _shapeError(r"unsupported schema keyword 'maxLength' at #/$defs/X/properties/y"),
      );
    });
  });

  group('the report', () {
    late final schema = tempSchema(requests: _echo('    name: { type: string }', required: '[method, name]'));

    test('names the entry, the mode, the platform and each violation', () {
      final report = schema.validateRequest('echo', {'name': 1, 'extra': true}, platform: android);
      expect(report.isValid, isFalse);
      expect(report.mode, ValidationMode.requestClosed);
      expect(
        report.describe(),
        'Echo.Request (request-closed, android): 2 violations\n'
        r'  /name: type at #/$requests/Echo.Request/properties/name (expected string, got integer)'
        '\n'
        r'  /extra: additionalProperties at #/$requests/Echo.Request (unexpected key "extra")',
      );
    });

    test('a valid payload reads as valid', () {
      final report = schema.validateRequest('echo', {'name': 'n'}, platform: ios);
      expect(report.isValid, isTrue);
      expect(report.describe(), 'Echo.Request (request-closed, ios): valid');
    });
  });
}

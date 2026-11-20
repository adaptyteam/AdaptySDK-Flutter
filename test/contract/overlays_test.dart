/// The overlays of the contract stay tied to the schema copy: every platform marker of the schema
/// has its row and every row its marker, and every fix of the schema is still needed.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/contract_schema.dart';
import '../../tool/contract/src/overlays.dart';
import '../support/contract/temp_schema.dart';

const ios = ContractPlatform.ios;
const android = ContractPlatform.android;

final ContractSchema schema = ContractSchema.load('.');
ContractOverlays get overlays => schema.overlays;

/// The rows of the platform overlays in the form the markers produce.
Set<MarkedRow> _platformRows({required bool withFinding}) => {
  for (final row in overlays.platformMethods)
    if (!withFinding) MarkedRow('platform_methods', row.name, row.platforms),
  for (final row in overlays.platformRequired)
    if ((row.finding != null) == withFinding) MarkedRow('platform_required', row.pointer, row.platforms),
  for (final row in overlays.platformFields)
    if ((row.finding != null) == withFinding) MarkedRow('platform_fields', row.pointer, row.platforms),
};

String _lines(Iterable<Object> rows) => rows.map((r) => '  $r').join('\n');

void main() {
  group('the marker scanner', () {
    final text = tempSchemaText(
      requests: r'''
Echo.Request: #request # Android Only
  type: object
  properties:
    method: { const: "echo" }
Ping.Request:
  type: object
  description: "iOS Only. Requires iOS 16+"
  required:
    - method
    - token # iOS only
  properties:
    method: { const: "ping" }
    token: { type: string }
    paddings: { type: boolean, description: 'android only' }
    style:
      {
        type: string,
        description: "Android Only",
      }
    offer:
      oneOf:
        - required: [type] # iOS Only
          properties:
            type: { const: code }
        - properties:
            id: { type: string } # Required for Android
            note: { type: string, description: "unknown or Android-only ids" }''',
      defs: r'''
Update: #request # Android Only
  type: object''',
    );

    test('finds every form, case-insensitively and with or without quotes', () {
      final markers = scanPlatformMarkers(text);
      expect(
        [for (final m in markers) '${m.platform.name} ${m.target.name}${m.requiredFor ? ' for' : ''} ${m.pointer}'],
        [
          r'android entry #/$requests/Echo.Request',
          r'ios entry #/$requests/Ping.Request',
          r'ios requiredItem #/$requests/Ping.Request/properties/token',
          r'android property #/$requests/Ping.Request/properties/paddings',
          r'android property #/$requests/Ping.Request/properties/style',
          r'ios branch #/$requests/Ping.Request/properties/offer/oneOf/0',
          r'android property for #/$requests/Ping.Request/properties/offer/oneOf/1/properties/id',
          r'android definition #/$defs/Update',
        ],
      );
    });

    test('turns markers into one row per node of the right overlay', () {
      expect(rowsForMarkers(text), [
        const MarkedRow('platform_methods', 'echo', {android}),
        const MarkedRow('platform_methods', 'ping', {ios}),
        const MarkedRow('platform_required', r'#/$requests/Ping.Request/properties/token', {ios}),
        const MarkedRow('platform_fields', r'#/$requests/Ping.Request/properties/paddings', {android}),
        const MarkedRow('platform_fields', r'#/$requests/Ping.Request/properties/style', {android}),
        const MarkedRow('platform_fields', r'#/$requests/Ping.Request/properties/offer/oneOf/0', {ios}),
        const MarkedRow('platform_required', r'#/$requests/Ping.Request/properties/offer/oneOf/1/properties/id', {
          android,
        }),
        const MarkedRow('platform_fields', r'#/$defs/Update', {android}),
      ]);
    });

    test('a property marked on its line and in required is one platform_required row', () {
      final twice = tempSchemaText(
        defs: '''
Product:
  type: object
  required:
    - shareable # iOS Only
  properties:
    shareable: { type: boolean, description: "iOS Only" } # iOS Only''',
      );
      expect(scanPlatformMarkers(twice), hasLength(3));
      expect(rowsForMarkers(twice), [
        const MarkedRow('platform_required', r'#/$defs/Product/properties/shareable', {ios}),
      ]);
    });

    test('a hyphen between the platform and only still makes a marker', () {
      final hyphenated = tempSchemaText(
        defs: '''
Product:
  type: object
  properties:
    token: { type: string, description: "iOS-only" }
    plan: { type: string } # Android-Only''',
      );
      expect(
        [for (final m in scanPlatformMarkers(hyphenated)) '${m.platform.name} ${m.pointer}'],
        [r'ios #/$defs/Product/properties/token', r'android #/$defs/Product/properties/plan'],
      );
    });

    test('a line naming a platform next to only or required that is no marker is a lookalike', () {
      expect(findMarkerLookalikes(text).map((l) => l.text), [
        'note: { type: string, description: "unknown or Android-only ids" }',
      ]);
      final prose = tempSchemaText(
        defs: '''
Product:
  description: "required for iOS builds; Android: required too"
  type: object
  properties:
    token: { type: string, description: "iOS only" }''',
      );
      expect(findMarkerLookalikes(prose), [
        (line: 10, text: 'description: "required for iOS builds; Android: required too"'),
      ]);
    });
  });

  group('the overlays of this repository', () {
    test('every line of the schema that looks like a platform marker and is not one is listed', () {
      final listed = {for (final row in overlays.markerLookalikes) row.lineText};
      final found = findMarkerLookalikes(schema.text);
      final unlisted = [
        for (final l in found)
          if (!listed.contains(l.text)) 'line ${l.line}: ${l.text}',
      ];
      expect(
        unlisted,
        isEmpty,
        reason:
            'a marker the scanner does not read leaves its field to both platforms; fix the scanner or list '
            'the line in marker_lookalikes.yaml after triage',
      );
      final gone = listed.difference({for (final l in found) l.text});
      expect(gone, isEmpty, reason: 'rows whose line is no longer a lookalike of the schema leave the list');
      for (final row in overlays.markerLookalikes) {
        expect(row.reason.trim(), isNotEmpty, reason: row.lineText);
      }
    });

    test('every platform marker of the schema has its row and every row its marker', () {
      final marked = rowsForMarkers(schema.text).toSet();
      final rows = _platformRows(withFinding: false);
      final missingRows = marked.difference(rows);
      final missingMarkers = rows.difference(marked);
      expect(missingRows, isEmpty, reason: 'markers without a row:\n${_lines(missingRows)}');
      expect(
        missingMarkers,
        isEmpty,
        reason: 'rows without a marker and without a finding:\n${_lines(missingMarkers)}',
      );
    });

    test('the schema has 46 platform markers on 35 nodes', () {
      expect(scanPlatformMarkers(schema.text), hasLength(46));
      expect(rowsForMarkers(schema.text), hasLength(35));
    });

    test('a row with a finding is one the schema has no marker for', () {
      final marked = {for (final row in rowsForMarkers(schema.text)) row.key};
      final withFinding = _platformRows(withFinding: true);
      expect(withFinding.map((r) => r.toString()), [
        r'platform_required #/$defs/AdaptyPaywallProduct.Request/properties/payload_data [android]',
        r'platform_required #/$requests/AdaptyUICreateOnboardingView.Request/properties/external_urls_presentation [ios]',
      ]);
      for (final row in withFinding) {
        expect(marked, isNot(contains(row.key)), reason: '$row has a marker; drop its finding');
      }
    });

    test('a row nested in a field of the same platform names that field in covered_by', () {
      final fields = [
        for (final row in overlays.platformFields)
          if (row.coveredBy == null) row,
      ];
      for (final row in [...overlays.platformRequired, ...overlays.platformFields]) {
        final outer = fields.where(
          (f) => row.pointer.startsWith('${f.pointer}/') && f.platforms.containsAll(row.platforms),
        );
        expect(row.coveredBy, outer.isEmpty ? isNull : outer.single.pointer, reason: row.pointer);
      }
    });

    test('every row names its source', () {
      final sources = <String, String>{
        for (final r in overlays.platformMethods) r.name: r.source,
        for (final r in [...overlays.platformRequired, ...overlays.platformFields]) r.pointer: r.source,
        for (final r in [...overlays.nullable, ...overlays.lenientRequired]) 'note ${r.pointer}': r.source,
        for (final r in overlays.schemaFixes) 'fix ${r.pointer}': r.source,
      };
      for (final MapEntry(:key, :value) in sources.entries) {
        expect(value.trim(), isNotEmpty, reason: key);
        expect(value, isNot(contains('TODO')), reason: key);
      }
    });

    test('the other platform of a platform_required row does not write the field or ignores it', () {
      // A fixture of the other platform is read without the field (ValidationMode.nativeFixture):
      // a row whose field the other native does write would push its fixtures to drop a real key.
      // A field of a request entry is read in no such mode, so the other native may read it as optional.
      for (final row in overlays.platformRequired) {
        if (row.coveredBy != null || _isRequestField(row.pointer)) continue;
        expect(row.source, matches(RegExp(r'not written|ignored|ignores')), reason: row.pointer);
      }
    });

    test('only a field of a request entry may stay optional on the other platform of a platform_required row', () {
      expect(
        _isRequestField(r'#/$requests/AdaptyUICreateOnboardingView.Request/properties/external_urls_presentation'),
        isTrue,
      );
      expect(_isRequestField(r'#/$requests/GetProfile.Response/oneOf/1/properties/success'), isFalse);
      expect(_isRequestField(r'#/$defs/AdaptyPaywallProduct.Request/properties/payload_data'), isFalse);
      expect(_isRequestField(r'#/$events/Event.DidLoadLatestProfile/properties/profile'), isFalse);
    });

    test('a key a schema fix adds on one platform is one the other native does not write', () {
      // A fixture of the other platform is read closed (ValidationMode.nativeFixture): a row that
      // lost its platforms would let that platform's fixtures carry a key its native never writes.
      for (final row in overlays.schemaFixes) {
        if (row.kind != SchemaFixKind.addProperty) continue;
        for (final platform in ContractPlatform.values) {
          final notWritten = RegExp('not written: ${platform.name}@').hasMatch(row.source);
          expect(
            row.platforms.contains(platform),
            !notWritten,
            reason: '${row.pointer}: ${platform.name} is ${notWritten ? '' : 'not '}named as not writing it',
          );
        }
      }
    });

    test('every pointer of an overlay is a node of the schema', () {
      for (final pointer in [
        for (final r in [...overlays.platformRequired, ...overlays.platformFields]) r.pointer,
        for (final r in [...overlays.nullable, ...overlays.lenientRequired]) r.pointer,
        for (final r in overlays.schemaFixes)
          if (r.kind == SchemaFixKind.oneOfToAnyOf) r.pointer,
      ]) {
        expect(schema.resolve(pointer), isA<Map<String, Object?>>(), reason: pointer);
      }
    });

    test('every method and event of platform_methods is in the schema', () {
      for (final row in overlays.platformMethods) {
        expect(row.isEvent ? schema.eventIds : schema.requestMethods, contains(row.name));
      }
    });

    test('every lenient required field is still required by the schema', () {
      for (final row in overlays.lenientRequired) {
        final segments = row.pointer.split('/');
        final object = schema.resolve(segments.sublist(0, segments.length - 2).join('/')) as Map<String, Object?>;
        expect(object['required'], contains(segments.last), reason: row.pointer);
      }
    });

    test('every schema fix is still needed by the schema copy', () {
      expect(overlays.schemaFixes, isNotEmpty);
      for (final row in overlays.schemaFixes) {
        switch (row.kind) {
          case SchemaFixKind.oneOfToAnyOf:
            expect(
              overlappingBranches(schema, row.pointer),
              isNotEmpty,
              reason: '${row.pointer}: branches no longer overlap',
            );
          case SchemaFixKind.addProperty:
            final segments = row.pointer.split('/');
            final object = schema.resolve(segments.sublist(0, segments.length - 2).join('/')) as Map<String, Object?>;
            expect(
              (object['properties'] as Map<String, Object?>).keys,
              isNot(contains(segments.last)),
              reason: '${row.pointer}: the schema has the property now',
            );
        }
      }
    });
  });

  group('overlapping branches', () {
    test('a value matching two branches is found among the constants of the branches', () {
      final overlapping = tempSchema(
        defs: '''
Name:
  oneOf:
    - type: string
    - enum: [started, finished]
Kind:
  oneOf:
    - const: a
    - const: b''',
      );
      expect(overlappingBranches(overlapping, r'#/$defs/Name'), ['started', 'finished']);
      expect(overlappingBranches(overlapping, r'#/$defs/Kind'), isEmpty);
    });
  });

  group('loading the overlay files', () {
    test('a row without a source is rejected', () {
      expect(
        () => ContractOverlays.parse(platformFields: "- pointer: '#/\$defs/X'\n  platforms: [ios]\n"),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('source'))),
      );
    });

    test('an unknown key in a row is rejected', () {
      expect(
        () => ContractOverlays.parse(
          nullable: "- pointer: '#/\$defs/X'\n  reason: r\n  source: s\n  finding: f\n  fix: oneOf_to_anyOf\n",
        ),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('fix'))),
      );
    });

    test('rows are read with their kinds and platforms', () {
      final parsed = ContractOverlays.parse(
        platformMethods: "- name: get_log_level\n  kind: method\n  platforms: [ios]\n  source: s\n",
        schemaFixes:
            "- pointer: '#/\$defs/X/properties/y'\n  kind: add_property\n  schema: { type: string }\n"
            "  platforms: [android]\n  reason: r\n  source: s\n  finding: f\n",
      );
      expect(parsed.platformMethods.single.isEvent, isFalse);
      expect(parsed.platformMethods.single.platforms, {ios});
      expect(parsed.schemaFixes.single.kind, SchemaFixKind.addProperty);
      expect(parsed.schemaFixes.single.schema, {'type': 'string'});
      expect(parsed.schemaFixes.single.platforms, {android});
    });

    test('a row adding a property names its platforms', () {
      expect(
        () => ContractOverlays.parse(
          schemaFixes:
              "- pointer: '#/\$defs/X/properties/y'\n  kind: add_property\n  schema: { type: string }\n"
              "  reason: r\n  source: s\n  finding: f\n",
        ),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('add_property needs platforms'))),
      );
    });

    test('a lenient row has no platforms to name', () {
      expect(
        () => ContractOverlays.parse(
          lenientRequired: "- pointer: '#/\$defs/X'\n  platforms: [ios]\n  reason: r\n  source: s\n  finding: f\n",
        ),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('platforms'))),
      );
    });

    test('a platform_required row is about both directions unless it names one', () {
      final parsed = ContractOverlays.parse(
        platformRequired:
            "- pointer: '#/\$defs/X/properties/a'\n  platforms: [ios]\n  source: s\n"
            "- pointer: '#/\$defs/X/properties/b'\n  platforms: [ios]\n  direction: response\n  source: s\n",
      );
      expect(parsed.platformRequired.map((r) => r.direction), [OverlayDirection.both, OverlayDirection.response]);
      expect(
        () => ContractOverlays.parse(
          platformRequired: "- pointer: '#/\$defs/X'\n  platforms: [ios]\n  direction: sideways\n  source: s\n",
        ),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('direction "sideways"'))),
      );
    });

    test('a platform_fields row has no direction to name', () {
      expect(
        () => ContractOverlays.parse(
          platformFields: "- pointer: '#/\$defs/X'\n  platforms: [ios]\n  direction: request\n  source: s\n",
        ),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('direction'))),
      );
    });

    test('a nullable row applies on both platforms unless it names them', () {
      final parsed = ContractOverlays.parse(
        nullable:
            "- pointer: '#/\$defs/X'\n  reason: r\n  source: s\n  finding: f\n"
            "- pointer: '#/\$defs/Y'\n  platforms: [ios]\n  reason: r\n  source: s\n  finding: f\n",
      );
      expect(parsed.nullable.map((r) => r.platforms), [
        {ios, android},
        {ios},
      ]);
    });
  });
}

/// Whether [pointer] is a field of a request entry, which no fixture of a native side is read against.
bool _isRequestField(String pointer) => RegExp(r'^#/\$requests/[^/]+\.Request/').hasMatch(pointer);

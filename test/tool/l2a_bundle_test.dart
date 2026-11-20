import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/contract_schema.dart';
import '../../tool/contract/src/contract_source.dart';
import '../../tool/contract/src/corpus.dart';
import '../../tool/contract/src/source_refs.dart';
import '../../integration_test_app/integration_test/support/l2a_types.dart';
import '../../tool/l2a/src/bundle.dart';

const _channelName = 'flutter.adapty.com/adapty';
const _expectationsPath = 'integration_test_app/l2a_expectations.yaml';
const _denylistPath = 'integration_test_app/l2a_denylist.yaml';
const _iosSource = 'ios@release/4.4.1 Sources.AdaptyPlugin/AdaptyJsonData/AdaptyPlugin+AdaptyJsonData.swift:44';
const _androidSource =
    'android@4.4.0 crossplatform/src/main/java/com/adapty/internal/crossplatform/AdaptyCallHandler.kt:696';

/// An expectations file with the defaults and the given [expectations] and [sensitivity] rows (YAML list items).
String _expectations({String expectations = '', String sensitivity = ''}) =>
    '''
probed: {}
defaults:
  not_activated:
    ios: {code: 2002, reason: the SDK is not activated, source: '$_iosSource'}
    android: {code: 20, reason: the SDK is not activated, source: '$_androidSource'}
  params:
    ios: {code: 2006, reason: the request does not decode, source: '$_iosSource'}
    android: {code: 2007, reason: the request does not decode, source: '$_androidSource'}
  event_answer:
    ios: {reason: an answer is matched by its event id, source: '$_iosSource'}
    android: {reason: an answer is matched by its event id, source: '$_androidSource'}
expectations:${expectations.isEmpty ? ' []' : '\n$expectations'}
sensitivity:${sensitivity.isEmpty ? ' []' : '\n$sensitivity'}
''';

const _denylist = '''
denied:
  - method: activate
    reason: activates the SDK
  - method: set_fallback
    reason: changes the state of the SDK
''';

/// A request fixture of [method] for both platforms, with [payload] and, for a negative one, [expect].
CorpusFixture requestFixture(String method, String caseName, Object? payload, {Map<String, Object?>? expect}) =>
    CorpusFixture(
      kind: CorpusKind.request,
      name: method,
      caseName: caseName,
      platform: null,
      path: 'contract/requests/$method/$caseName.json',
      provenance: const {'source': 'hand', 'native': 'both'},
      expect: expect,
      notes: 'synthetic',
      payload: payload,
    );

/// The problems [run] stops with; none when it does not stop.
List<String> problemsOf(void Function() run) {
  try {
    run();
  } on BundleProblems catch (e) {
    return e.problems;
  }
  return const [];
}

void main() {
  late ContractSchema schema;
  late Corpus corpus;
  late Set<String> refs;

  setUpAll(() {
    schema = ContractSchema.load('.');
    corpus = Corpus.load('.');
    refs = NativeRefs.of(ContractSource.load('.')).all;
  });

  L2aBundle? plainDiscovery;

  L2aBundle build({
    String expectations = '',
    String sensitivity = '',
    bool discover = true,
    Corpus? from,
    String channelName = _channelName,
    String denylist = _denylist,
  }) {
    final plain =
        expectations.isEmpty &&
        sensitivity.isEmpty &&
        discover &&
        from == null &&
        channelName == _channelName &&
        denylist == _denylist;
    if (plain && plainDiscovery != null) return plainDiscovery!;
    final bundle = buildBundle(
      schema: schema,
      corpus: from ?? corpus,
      sdkVersion: '9.9.9-test',
      channelName: channelName,
      denylist: Denylist.parse(denylist, path: _denylistPath),
      expectations: Expectations.parse(
        _expectations(expectations: expectations, sensitivity: sensitivity),
        path: _expectationsPath,
        refs: refs,
      ),
      discover: discover,
    );
    if (plain) plainDiscovery = bundle;
    return bundle;
  }

  BundleCase caseOf(L2aBundle bundle, ContractPlatform platform, String id) =>
      bundle.cases[platform]!.singleWhere((c) => c.id == id, orElse: () => fail('no case $id on ${platform.name}'));

  List<String> strictProblems({String expectations = '', String sensitivity = ''}) =>
      problemsOf(() => build(expectations: expectations, sensitivity: sensitivity, discover: false));

  /// A golden request of get_flow on iOS as a fixture of [caseName] with [payload], shared by both platforms when
  /// [platform] is null.
  CorpusFixture getFlowFixture(String caseName, Object? payload, {Map<String, Object?>? expect}) =>
      requestFixture('get_flow', caseName, payload, expect: expect);

  group('expected outcomes', () {
    test('a golden request of the SDK proper is expected to fail as not activated', () {
      final bundle = build();
      final ios = caseOf(bundle, ContractPlatform.ios, 'get_flow/default').expected;
      final android = caseOf(bundle, ContractPlatform.android, 'get_flow/default').expected;
      expect(ios, isA<ErrorOutcome>().having((o) => (o.code, o.messageClass), 'error', (2002, MessageClass.other)));
      expect(android, isA<ErrorOutcome>().having((o) => (o.code, o.messageClass), 'error', (20, MessageClass.other)));
    });

    test('an answer to an event is expected to succeed', () {
      final bundle = build();
      for (final platform in ContractPlatform.values) {
        expect(caseOf(bundle, platform, 'observer_purchase_did_start/default').expected, isA<SuccessOutcome>());
      }
    });

    test(
      'a broken payload of a method that decodes is expected to be refused with the params code of its platform',
      () {
        final bundle = build(
          sensitivity:
              '''
  - {method: get_flow, platform: ios, sensitivity: decodes, reason: checks its fields, source: '$_iosSource'}
  - {method: get_flow, platform: android, sensitivity: decodes, reason: checks its fields, source: '$_androidSource'}
''',
        );
        for (final (platform, code) in [(ContractPlatform.ios, 2006), (ContractPlatform.android, 2007)]) {
          expect(
            caseOf(bundle, platform, 'get_flow/default/remove_required/placement_id').expected,
            isA<ErrorOutcome>().having((o) => (o.code, o.messageClass), 'error', (code, MessageClass.params)),
            reason: platform.name,
          );
        }
      },
    );

    test('a recorded outcome replaces the default of a golden request', () {
      final bundle = build(
        expectations:
            '''
  - {method: is_activated, platform: ios, outcome: success, reason: answers before activation, source: '$_iosSource'}
''',
      );
      expect(caseOf(bundle, ContractPlatform.ios, 'is_activated/default').expected, isA<SuccessOutcome>());
      expect(caseOf(bundle, ContractPlatform.android, 'is_activated/default').expected, isA<ErrorOutcome>());
    });

    test('the record of a case wins over the record of its method, which holds for the other cases', () {
      final bundle = build(
        expectations:
            '''
  - method: get_flow
    platform: ios
    outcome: {error: {code: 1, class: other}}
    reason: a code for every case
    source: '$_iosSource'
  - method: get_flow
    platform: ios
    case: default
    outcome: success
    reason: a code for one case
    source: '$_iosSource'
''',
      );
      expect(caseOf(bundle, ContractPlatform.ios, 'get_flow/default').expected, isA<SuccessOutcome>());
      expect(
        caseOf(bundle, ContractPlatform.ios, 'get_flow/return_cache_data_else_load').expected,
        isA<ErrorOutcome>().having((o) => o.code, 'code', 1),
      );
    });

    test('a recorded outcome replaces the default for its broken payload', () {
      final bundle = build(
        expectations:
            '''
  - method: identify
    platform: android
    kind: remove_required
    path: /customer_user_id
    outcome: native_exception
    reason: the native identify takes a value that is never null
    source: '$_androidSource'
''',
        sensitivity:
            '''
  - {method: identify, platform: android, sensitivity: decodes, reason: checks its fields, source: '$_androidSource'}
''',
      );
      final variant = caseOf(bundle, ContractPlatform.android, 'identify/default/remove_required/customer_user_id');
      expect(variant.expected, isA<NativeExceptionOutcome>());
    });

    test('an insensitive pair observes every broken payload instead of expecting a refusal', () {
      final bundle = build(
        sensitivity:
            '''
  - {method: get_flow, platform: ios, sensitivity: insensitive, reason: accepts anything, source: '$_iosSource'}
  - method: get_flow
    platform: android
    sensitivity: decodes
    insensitive_fields: [{kind: swap_type, path: /placement_id}]
    reason: turns a number into a string
    source: '$_androidSource'
''',
      );
      final iosVariants = bundle.cases[ContractPlatform.ios]!.where((c) => c.method == 'get_flow' && c.variant != null);
      expect(iosVariants, isNotEmpty);
      expect(iosVariants.map((c) => c.expected), everyElement(isA<ObserveOutcome>()));
      expect(
        caseOf(bundle, ContractPlatform.android, 'get_flow/default/swap_type/placement_id').expected,
        isA<ObserveOutcome>(),
      );
      expect(
        caseOf(bundle, ContractPlatform.android, 'get_flow/default/remove_required/placement_id').expected,
        isA<ErrorOutcome>(),
      );
    });

    test('a denied method is skipped with its reason', () {
      final bundle = build();
      for (final platform in ContractPlatform.values) {
        final denied = bundle.cases[platform]!.where((c) => c.method == 'set_fallback');
        expect(denied, isNotEmpty);
        expect(
          denied.map((c) => c.expected),
          everyElement(isA<SkipOutcome>().having((o) => o.reason, 'reason', 'changes the state of the SDK')),
        );
      }
    });
  });

  group('broken payloads that activation hides', () {
    test('an unobservable pair expects every broken payload to fail as not activated', () {
      final bundle = build(
        sensitivity:
            '''
  - {method: identify, platform: android, sensitivity: unobservable, reason: checks activation first, source: '$_androidSource'}
''',
      );
      final variants = bundle.cases[ContractPlatform.android]!.where(
        (c) => c.method == 'identify' && c.variant != null,
      );
      expect(variants, isNotEmpty);
      expect(
        variants.map((c) => c.expected),
        everyElement(isA<ErrorOutcome>().having((o) => (o.code, o.messageClass), 'error', (20, MessageClass.other))),
      );
    });

    test('an unobservable field expects its broken payload to fail as not activated', () {
      final bundle = build(
        sensitivity:
            '''
  - method: get_flow
    platform: android
    sensitivity: decodes
    unobservable_fields: [{kind: swap_type, path: /placement_id}]
    reason: turns a number into a string and checks activation first
    source: '$_androidSource'
''',
      );
      expect(
        caseOf(bundle, ContractPlatform.android, 'get_flow/default/swap_type/placement_id').expected,
        isA<ErrorOutcome>().having((o) => (o.code, o.messageClass), 'error', (20, MessageClass.other)),
      );
      expect(
        caseOf(bundle, ContractPlatform.android, 'get_flow/default/remove_required/placement_id').expected,
        isA<ErrorOutcome>().having((o) => (o.code, o.messageClass), 'error', (2007, MessageClass.params)),
      );
    });

    test('an unobservable field that matches no broken payload stops the bundle', () {
      final problems = problemsOf(
        () => build(
          sensitivity:
              '''
  - method: get_flow
    platform: android
    sensitivity: decodes
    unobservable_fields: [{kind: swap_type, path: /placement_idd}]
    reason: checks activation first
    source: '$_androidSource'
''',
        ),
      );
      expect(problems, [
        allOf(startsWith('$_expectationsPath: sensitivity[0].unobservable_fields[0]'), contains('/placement_idd')),
      ]);
    });

    test('a field both insensitive and unobservable is refused', () {
      final problems = problemsOf(
        () => Expectations.parse(
          _expectations(
            sensitivity:
                '''
  - method: get_flow
    platform: android
    sensitivity: decodes
    insensitive_fields: [{kind: swap_type, path: /placement_id}]
    unobservable_fields: [{kind: swap_type, path: /placement_id}]
    reason: both
    source: '$_androidSource'
''',
          ),
          path: _expectationsPath,
          refs: refs,
        ),
      );
      expect(problems, contains(allOf(startsWith('$_expectationsPath: sensitivity[0]'), contains('/placement_id'))));
    });
  });

  group('strict mode', () {
    test('stops at a UI method without an expectation and names the expectations file', () {
      expect(
        strictProblems(),
        contains(allOf(startsWith(_expectationsPath), contains('adapty_ui_destroy_flow_view'), contains('ios'))),
      );
    });

    test('stops at a method and platform without a sensitivity', () {
      expect(
        strictProblems(),
        contains(allOf(startsWith(_expectationsPath), contains('sensitivity'), contains('get_flow'))),
      );
    });

    test('discovery observes what has no expectation instead of stopping', () {
      final bundle = build();
      expect(
        caseOf(bundle, ContractPlatform.ios, 'adapty_ui_destroy_flow_view/default').expected,
        isA<ObserveOutcome>(),
      );
      expect(
        caseOf(bundle, ContractPlatform.ios, 'get_flow/default/remove_required/placement_id').expected,
        isA<ObserveOutcome>(),
      );
    });
  });

  group('expectation records', () {
    Object? parseProblems(String expectations) {
      try {
        Expectations.parse(
          _expectations(expectations: expectations),
          path: _expectationsPath,
          refs: refs,
        );
      } on BundleProblems catch (e) {
        return e.problems;
      }
      return null;
    }

    test('a record without a source is refused', () {
      expect(
        parseProblems('''
  - {method: is_activated, platform: ios, outcome: success, reason: answers before activation}
'''),
        contains(allOf(startsWith(_expectationsPath), contains('source'))),
      );
    });

    test('a record with an empty source is refused', () {
      expect(
        parseProblems('''
  - {method: identify, platform: android, kind: remove_required, path: /customer_user_id, outcome: native_exception, reason: throws, source: ''}
'''),
        contains(allOf(startsWith(_expectationsPath), contains('source'))),
      );
    });
  });

  group('records that do not say enough', () {
    test('a record with a kind and no path is refused', () {
      final problems = problemsOf(
        () => Expectations.parse(
          _expectations(
            expectations:
                '''
  - {method: identify, platform: ios, kind: remove_required, outcome: native_exception, reason: throws, source: '$_iosSource'}
''',
          ),
          path: _expectationsPath,
          refs: refs,
        ),
      );
      expect(problems, contains(allOf(startsWith('$_expectationsPath: expectations[0]'), contains('kind and path'))));
    });

    test('a denied method that is not in the contract stops the bundle', () {
      final problems = problemsOf(
        () => build(
          denylist: '''
denied:
  - method: no_such_method
    reason: not a method
''',
        ),
      );
      expect(problems, contains(allOf(startsWith(_denylistPath), contains('no_such_method'))));
    });

    test('a golden request the contract refuses stops the bundle and names the fixture', () {
      final problems = problemsOf(
        () => build(
          from: Corpus(
            fixtures: [getFlowFixture('broken', const <String, Object?>{})],
            baseline: corpus.baseline,
            problems: const [],
          ),
        ),
      );
      expect(
        problems,
        contains(
          r'contract/requests/get_flow/broken.json on ios: (payload): required at #/$requests/GetFlow.Request '
          '(missing "placement_id")',
        ),
      );
    });
  });

  group('rows that match nothing', () {
    test('a method record that the record of every case overrides still counts as used', () {
      final problems = problemsOf(
        () => build(
          from: Corpus(
            fixtures: [
              getFlowFixture('only', const {'placement_id': 'placement-id'}),
            ],
            baseline: corpus.baseline,
            problems: const [],
          ),
          expectations:
              '''
  - {method: get_flow, platform: ios, outcome: success, reason: answers, source: '$_iosSource'}
  - {method: get_flow, platform: ios, case: only, outcome: success, reason: answers, source: '$_iosSource'}
''',
        ),
      );
      expect(problems, isEmpty);
    });

    test('an expectation whose path matches no broken payload stops the bundle in discovery too', () {
      final problems = problemsOf(
        () => build(
          expectations:
              '''
  - {method: identify, platform: android, kind: remove_required, path: /customer_user_idd, outcome: native_exception, reason: throws, source: '$_androidSource'}
''',
        ),
      );
      expect(problems, contains(allOf(startsWith('$_expectationsPath: expectations[0]'), contains('matches no case'))));
    });

    test('an expectation of a method the platform does not handle stops the bundle', () {
      final problems = problemsOf(
        () => build(
          expectations:
              '''
  - {method: make_promoted_purchase, platform: android, outcome: success, reason: answers, source: '$_androidSource'}
''',
        ),
      );
      expect(problems, contains(allOf(startsWith('$_expectationsPath: expectations[0]'), contains('matches no case'))));
    });

    test('a row of a denied method stops the bundle', () {
      final problems = problemsOf(
        () => build(
          expectations:
              '''
  - {method: set_fallback, platform: ios, outcome: success, reason: answers, source: '$_iosSource'}
''',
          sensitivity:
              '''
  - {method: set_fallback, platform: ios, sensitivity: decodes, reason: checks its fields, source: '$_iosSource'}
''',
        ),
      );
      expect(problems, contains(allOf(startsWith('$_expectationsPath: expectations[0]'), contains('denied'))));
      expect(problems, contains(allOf(startsWith('$_expectationsPath: sensitivity[0]'), contains('denied'))));
    });

    test('a sensitivity of a method without broken payloads stops the bundle', () {
      final problems = problemsOf(
        () => build(
          sensitivity:
              '''
  - {method: get_profile, platform: ios, sensitivity: decodes, reason: checks its fields, source: '$_iosSource'}
''',
        ),
      );
      expect(problems, contains(allOf(startsWith('$_expectationsPath: sensitivity[0]'), contains('matches no'))));
    });

    test('an insensitive field that matches no broken payload stops the bundle', () {
      final problems = problemsOf(
        () => build(
          sensitivity:
              '''
  - method: get_flow
    platform: android
    sensitivity: decodes
    insensitive_fields: [{kind: swap_type, path: /placement_id}, {kind: swap_type, path: /placement_idd}]
    reason: turns a number into a string
    source: '$_androidSource'
''',
        ),
      );
      expect(problems, [
        allOf(startsWith('$_expectationsPath: sensitivity[0].insensitive_fields[1]'), contains('/placement_idd')),
      ]);
    });
  });

  group('negative request fixtures', () {
    Corpus negatives(List<CorpusFixture> fixtures) =>
        Corpus(fixtures: fixtures, baseline: corpus.baseline, problems: const []);

    const decodesOnBoth =
        '''
  - {method: get_flow, platform: ios, sensitivity: decodes, reason: checks its fields, source: '$_iosSource'}
  - method: get_flow
    platform: android
    sensitivity: decodes
    insensitive_fields: [{kind: swap_type, path: /placement_id}]
    reason: turns a number into a string
    source: '$_androidSource'
''';

    final withoutPlacement = getFlowFixture(
      'without_placement_id',
      const <String, Object?>{},
      expect: const {
        'violation': {'keyword': 'required', 'pointer': r'#/$requests/GetFlow.Request'},
      },
    );
    final numberPlacement = getFlowFixture(
      'placement_id_number',
      const {'placement_id': 5},
      expect: const {
        'violation': {'keyword': 'type', 'pointer': r'#/$requests/GetFlow.Request/properties/placement_id'},
      },
    );

    test('a removed required field is a broken payload refused with the params code of the platform', () {
      final bundle = build(
        from: negatives([withoutPlacement, numberPlacement]),
        sensitivity: decodesOnBoth,
        discover: false,
      );
      for (final (platform, code) in [(ContractPlatform.ios, 2006), (ContractPlatform.android, 2007)]) {
        final negative = caseOf(bundle, platform, 'get_flow/without_placement_id');
        expect(
          (negative.variant, negative.instancePath, negative.arguments),
          ('remove_required', '/placement_id', '{}'),
        );
        expect(
          negative.expected,
          isA<ErrorOutcome>().having((o) => (o.code, o.messageClass), 'error', (code, MessageClass.params)),
        );
      }
    });

    test('a swapped type is observed at a field the platform does not check', () {
      final bundle = build(
        from: negatives([withoutPlacement, numberPlacement]),
        sensitivity: decodesOnBoth,
        discover: false,
      );
      expect(
        caseOf(bundle, ContractPlatform.ios, 'get_flow/placement_id_number'),
        isA<BundleCase>()
            .having((c) => (c.variant, c.instancePath), 'variant', ('swap_type', '/placement_id'))
            .having((c) => c.expected, 'expected', isA<ErrorOutcome>()),
      );
      expect(caseOf(bundle, ContractPlatform.android, 'get_flow/placement_id_number').expected, isA<ObserveOutcome>());
    });

    test('a negative fixture whose payload breaks something else than its expect stops the bundle', () {
      final mislabelled = getFlowFixture(
        'mislabelled',
        const <String, Object?>{},
        expect: const {
          'violation': {'keyword': 'type', 'pointer': r'#/$requests/GetFlow.Request/properties/placement_id'},
        },
      );
      expect(
        problemsOf(() => build(from: negatives([mislabelled]))),
        contains(allOf(startsWith('contract/requests/get_flow/mislabelled.json on ios'), contains('type'))),
      );
    });

    Map<String, Object?> violation(String keyword, String pointer) => {
      'violation': {'keyword': keyword, 'pointer': pointer},
    };

    test('a negative fixture whose violation is at another node stops the bundle', () {
      final elsewhere = getFlowFixture(
        'required_elsewhere',
        const <String, Object?>{},
        expect: violation('required', r'#/$requests/GetFlow.Request/properties/placement_id'),
      );
      expect(
        problemsOf(() => build(from: negatives([elsewhere]))),
        contains(startsWith('contract/requests/get_flow/required_elsewhere.json on ios: expect names required')),
      );
    });

    test('a negative fixture whose violation has another keyword at its node stops the bundle', () {
      final otherKeyword = getFlowFixture('other_keyword', const {
        'placement_id': 5,
      }, expect: violation('required', r'#/$requests/GetFlow.Request/properties/placement_id'));
      expect(
        problemsOf(() => build(from: negatives([otherKeyword]))),
        contains(startsWith('contract/requests/get_flow/other_keyword.json on ios: expect names required')),
      );
    });

    test('a negative fixture with a second violation besides its own stops the bundle', () {
      final twoViolations = getFlowFixture('two_violations', const {
        'placement_id': 5,
        'load_timeout': 'soon',
      }, expect: violation('type', r'#/$requests/GetFlow.Request/properties/placement_id'));
      expect(
        problemsOf(() => build(from: negatives([twoViolations]))),
        contains(allOf(startsWith('contract/requests/get_flow/two_violations.json on ios'), contains('load_timeout'))),
      );
    });

    test('a violation no kind of broken payload stands for is observed under its keyword', () {
      final unknownPolicy = getFlowFixture('unknown_policy', const {
        'placement_id': 'placement-id',
        'fetch_policy': {'type': 'unknown'},
      }, expect: violation('oneOf', r'#/$defs/AdaptyPlacementFetchPolicy/oneOf'));
      final bundle = build(
        from: negatives([unknownPolicy, numberPlacement]),
        sensitivity: decodesOnBoth,
        discover: false,
      );
      for (final platform in ContractPlatform.values) {
        expect(
          caseOf(bundle, platform, 'get_flow/unknown_policy'),
          isA<BundleCase>()
              .having((c) => c.variant, 'variant', 'oneOf')
              .having((c) => c.expected, 'expected', isA<ObserveOutcome>()),
        );
      }
    });

    test('a recorded outcome replaces the default of a negative fixture', () {
      final bundle = build(
        from: negatives([withoutPlacement, numberPlacement]),
        sensitivity: decodesOnBoth,
        expectations:
            '''
  - method: get_flow
    platform: android
    case: without_placement_id
    kind: remove_required
    path: /placement_id
    outcome: native_exception
    reason: throws on a missing value
    source: '$_androidSource'
''',
        discover: false,
      );
      expect(
        caseOf(bundle, ContractPlatform.android, 'get_flow/without_placement_id').expected,
        isA<NativeExceptionOutcome>(),
      );
      expect(caseOf(bundle, ContractPlatform.ios, 'get_flow/without_placement_id').expected, isA<ErrorOutcome>());
    });

    test('an unknown constant is a foreign enum value', () {
      final probeSchema = ContractSchema.fromYaml(r'''
$requests:
  Probe.Request:
    type: object
    required: [method, mode]
    properties:
      method: { const: "probe" }
      mode: { const: "fast" }
''');
      final bundle = buildBundle(
        schema: probeSchema,
        corpus: negatives([
          requestFixture('probe', 'slow_mode', const {
            'mode': 'slow',
          }, expect: violation('const', r'#/$requests/Probe.Request/properties/mode')),
        ]),
        sdkVersion: '9.9.9-test',
        channelName: _channelName,
        denylist: Denylist.parse('denied: []', path: _denylistPath),
        expectations: Expectations.parse(
          _expectations(
            sensitivity:
                '''
  - {method: probe, platform: ios, sensitivity: decodes, reason: checks its fields, source: '$_iosSource'}
  - {method: probe, platform: android, sensitivity: decodes, reason: checks its fields, source: '$_androidSource'}
''',
          ),
          path: _expectationsPath,
          refs: refs,
        ),
      );
      expect(
        caseOf(bundle, ContractPlatform.ios, 'probe/slow_mode'),
        isA<BundleCase>()
            .having((c) => (c.variant, c.instancePath), 'variant', ('foreign_enum', '/mode'))
            .having((c) => c.expected, 'expected', isA<ErrorOutcome>()),
      );
    });

    test('a negative fixture that removes several required keys stops the bundle', () {
      final withoutBoth = requestFixture(
        'flow_view_did_answer_permission',
        'without_event_id_and_status',
        const <String, Object?>{},
        expect: violation('required', r'#/$requests/FlowViewDidAnswerPermission.Request'),
      );
      expect(
        problemsOf(() => build(from: negatives([withoutBoth]))),
        contains(
          allOf(
            startsWith('contract/requests/flow_view_did_answer_permission/without_event_id_and_status.json on ios'),
            contains('one required key'),
          ),
        ),
      );
    });

    test('a negative fixture that names no violation stops the bundle', () {
      final unnamed = getFlowFixture('unnamed', const <String, Object?>{}, expect: const {'native': 'decodingFailed'});
      expect(
        problemsOf(() => build(from: negatives([unnamed]))),
        contains(allOf(startsWith('contract/requests/get_flow/unnamed.json'), contains('violation'))),
      );
    });
  });

  group('payloads', () {
    test('a golden request is the one of its own platform', () {
      final bundle = build();
      for (final platform in ContractPlatform.values) {
        final golden = corpus.fixture(CorpusKind.request, 'make_purchase', 'default', platform)!;
        expect(golden.platform, platform, reason: 'the corpus keeps make_purchase/default per platform');
        expect(jsonDecode(caseOf(bundle, platform, 'make_purchase/default').arguments), golden.payload);
      }
    });

    test('the SDK version placeholder is filled in', () {
      final arguments = caseOf(build(), ContractPlatform.ios, 'activate/full').arguments;
      expect(arguments, contains('"cross_platform_sdk_version":"9.9.9-test"'));
      expect(arguments, isNot(contains('<sdk-version>')));
    });

    test('a removed field is left out, not sent as null', () {
      final variant = caseOf(build(), ContractPlatform.ios, 'identify/default/remove_required/customer_user_id');
      expect((jsonDecode(variant.arguments) as Map<String, Object?>).containsKey('customer_user_id'), isFalse);
    });

    test('broken payloads remove the fields their own platform requires', () {
      final bundle = build();
      bool removesPayloadData(ContractPlatform platform) =>
          bundle.cases[platform]!.any((c) => c.id == 'make_purchase/default/remove_required/product/payload_data');
      expect(removesPayloadData(ContractPlatform.android), isTrue);
      expect(removesPayloadData(ContractPlatform.ios), isFalse);
    });

    test('no broken payload adds a key', () {
      final bundle = build();
      for (final platform in ContractPlatform.values) {
        expect(bundle.cases[platform]!.where((c) => c.variant == 'extra_key'), isEmpty);
        expect(bundle.cases[platform]!.where((c) => c.variant == 'remove_required'), isNotEmpty);
      }
    });

    test('a method one platform does not handle has no case on the other one', () {
      final promoted = corpus.fixture(CorpusKind.request, 'make_promoted_purchase', 'default', ContractPlatform.ios)!;
      final shared = CorpusFixture(
        kind: promoted.kind,
        name: promoted.name,
        caseName: promoted.caseName,
        platform: null,
        path: 'contract/requests/make_promoted_purchase/default.json',
        provenance: promoted.provenance,
        expect: null,
        notes: promoted.notes,
        payload: promoted.payload,
      );
      final bundle = build(
        from: Corpus(fixtures: [shared], baseline: corpus.baseline, problems: const []),
      );
      expect(bundle.cases[ContractPlatform.ios]!.map((c) => c.method), contains('make_promoted_purchase'));
      expect(bundle.cases[ContractPlatform.android]!, isEmpty);
    });
  });

  group('the generated library', () {
    test('is the same bytes whatever order the corpus is read in', () {
      final first = build().render();
      final reversed = build(
        from: Corpus(fixtures: corpus.fixtures.reversed.toList(), baseline: corpus.baseline, problems: const []),
      ).render();
      expect(reversed, first);
    });

    test('writes quotes, dollars, backslashes and line breaks of the arguments as a Dart literal', () {
      final bundle = L2aBundle(
        channelName: _channelName,
        discover: true,
        cases: {
          ContractPlatform.ios: [
            BundleCase(id: 'm/c', method: 'm', arguments: 'a\'b\$c\\d\ne', expected: const SuccessOutcome()),
          ],
          ContractPlatform.android: const [],
        },
      );
      expect(bundle.render(), contains(r"      arguments: 'a\'b\$c\\d\ne',"));
    });

    test('calls the channel the SDK declares', () {
      const source = "const String adaptyChannelName = 'example.test/channel';";
      expect(channelNameFrom(source), 'example.test/channel');
      expect(build(channelName: channelNameFrom(source)).render(), contains("'example.test/channel'"));
    });
  });

  group('the log of the probe', () {
    test('names each message class the way the expectations file does', () {
      for (final messageClass in L2aMessageClass.values) {
        final logged =
            (L2aError(2006, messageClass).toJson()! as Map<String, Object?>)['error']! as Map<String, Object?>;
        expect(MessageClass.parse(logged['class']! as String).name, messageClass.name);
      }
    });
  });

  group('native error messages', () {
    // Messages as the plugins answered them on a simulator and an emulator before activation.
    final table = <(ContractPlatform, String, String, MessageClass)>[
      (
        ContractPlatform.ios,
        'get_flow',
        'Request params of method:get_flow is invalid: The data couldn’t be read because it is missing.',
        MessageClass.params,
      ),
      (
        ContractPlatform.ios,
        'identify',
        'Request params of method:identify is invalid: The data couldn’t be read because it isn’t in the '
            'correct format.',
        MessageClass.params,
      ),
      (
        ContractPlatform.ios,
        'get_flow',
        'Request params of method:identify is invalid: The data couldn’t be read because it is missing.',
        MessageClass.other,
      ),
      (
        ContractPlatform.ios,
        'no_such_method',
        'Decoding failed: The operation couldn’t be completed. (AdaptyPlugin.AdaptyPluginInternalError error 0.)',
        MessageClass.unknownMethod,
      ),
      (
        ContractPlatform.ios,
        'get_profile',
        'Adapty SDK is not initialized. You need to activate the SDK before using its methods.',
        MessageClass.other,
      ),
      (ContractPlatform.android, 'get_flow', 'Error while parsing parameter', MessageClass.params),
      (ContractPlatform.android, 'no_such_method', 'Method no_such_method not found', MessageClass.unknownMethod),
      (ContractPlatform.android, 'get_flow', 'Method no_such_method not found', MessageClass.other),
      (ContractPlatform.android, 'get_profile', 'Adapty was not initialized', MessageClass.other),
    ];

    for (final (platform, method, message, expected) in table) {
      test('${platform.name} $method: "$message" is ${expected.wireName}', () {
        expect(messageClassOf(platform, method, message), expected);
      });
    }
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:adapty_flutter/src/constants/method.dart';
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

/// The refs of the natives of the contract record, which the sources of the synthetic expectations name: a source
/// is checked against the refs of the record, and the sources follow it when the record moves to another ref.
final _nativeRefs = NativeRefs.of(ContractSource.load('.'));
final _iosSource = '${_nativeRefs.ios} Sources.AdaptyPlugin/AdaptyJsonData/AdaptyPlugin+AdaptyJsonData.swift:44';
final _androidSource =
    '${_nativeRefs.android} crossplatform/src/main/java/com/adapty/internal/crossplatform/AdaptyCallHandler.kt:696';

/// The version of the crossplatform library of the contract record, as `probed.android` names it.
final _androidVersion = _nativeRefs.android.substring('android@'.length);

/// An expectations file with the defaults and the given [expectations] and [sensitivity] rows (YAML list items).
String _expectations({
  String expectations = '',
  String sensitivity = '',
  String probed = '{}',
  String afterProbe = '',
}) =>
    '''
probed: $probed
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
${afterProbe.isEmpty ? '' : 'after_probe:\n$afterProbe'}''';

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
  late PlatformViewCases views;
  late Set<String> sdkMethods;

  setUpAll(() {
    schema = ContractSchema.load('.');
    corpus = Corpus.load('.');
    refs = NativeRefs.of(ContractSource.load('.')).all;
    views = PlatformViewCases.load('.');
    sdkMethods = sdkMethodsFrom(File('lib/src/constants/method.dart').readAsStringSync());
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
      views: views,
      sdkMethods: sdkMethods,
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

    test('an insensitive pair expects of every broken payload what its golden case answers', () {
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
      for (final variant in iosVariants) {
        final golden = caseOf(bundle, ContractPlatform.ios, variant.id.split('/').take(2).join('/'));
        expect(variant.expected, isA<ErrorOutcome>().having((o) => o.code, 'code', 2002), reason: variant.id);
        expect(variant.expected.dart, golden.expected.dart, reason: variant.id);
        expect(variant.basis, Basis.insensitive, reason: variant.id);
      }
      final field = caseOf(bundle, ContractPlatform.android, 'get_flow/default/swap_type/placement_id');
      expect(field.expected.dart, caseOf(bundle, ContractPlatform.android, 'get_flow/default').expected.dart);
      expect(field.basis, Basis.insensitive);
      expect(
        caseOf(bundle, ContractPlatform.android, 'get_flow/default/remove_required/placement_id').expected,
        isA<ErrorOutcome>().having((o) => o.messageClass, 'class', MessageClass.params),
      );
    });

    test('an insensitive pair whose golden case is observed observes its broken payloads too', () {
      final bundle = build(
        sensitivity:
            '''
  - {method: adapty_ui_destroy_flow_view, platform: android, sensitivity: insensitive, reason: takes any id, source: '$_androidSource'}
''',
      );
      expect(
        caseOf(bundle, ContractPlatform.android, 'adapty_ui_destroy_flow_view/default').expected,
        isA<ObserveOutcome>(),
      );
      expect(
        caseOf(bundle, ContractPlatform.android, 'adapty_ui_destroy_flow_view/default/swap_type/id').expected,
        isA<ObserveOutcome>(),
      );
    });

    test('a record of a broken payload wins over the outcome of its insensitive golden case', () {
      final bundle = build(
        expectations:
            '''
  - method: get_flow
    platform: ios
    kind: swap_type
    path: /placement_id
    outcome: native_exception
    reason: throws
    source: '$_iosSource'
''',
        sensitivity:
            '''
  - {method: get_flow, platform: ios, sensitivity: insensitive, reason: accepts anything, source: '$_iosSource'}
''',
      );
      expect(
        caseOf(bundle, ContractPlatform.ios, 'get_flow/default/swap_type/placement_id').expected,
        isA<NativeExceptionOutcome>(),
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

    test('an unobservable method that lists fields is refused', () {
      final problems = problemsOf(
        () => Expectations.parse(
          _expectations(
            sensitivity:
                '''
  - method: identify
    platform: android
    sensitivity: unobservable
    unobservable_fields: [{kind: swap_type, path: /customer_user_id}]
    reason: checks activation first
    source: '$_androidSource'
''',
          ),
          path: _expectationsPath,
          refs: refs,
        ),
      );
      expect(problems, contains(allOf(startsWith('$_expectationsPath: sensitivity[0]'), contains('lists no fields'))));
    });

    test('an unobservable pair on iOS expects the iOS code of not activated', () {
      final bundle = build(
        sensitivity:
            '''
  - {method: identify, platform: ios, sensitivity: unobservable, reason: checks activation first, source: '$_iosSource'}
''',
      );
      expect(
        caseOf(bundle, ContractPlatform.ios, 'identify/default/swap_type/customer_user_id').expected,
        isA<ErrorOutcome>().having((o) => (o.code, o.messageClass), 'error', (2002, MessageClass.other)),
      );
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

  group('the basis of an expected outcome', () {
    Basis basisOf(L2aBundle bundle, ContractPlatform platform, String id) => caseOf(bundle, platform, id).basis;

    test('says whether a case expects a default, a record, a denial or nothing yet', () {
      final bundle = build(
        expectations:
            '''
  - {method: is_activated, platform: ios, outcome: success, reason: answers before activation, source: '$_iosSource'}
''',
      );
      expect(basisOf(bundle, ContractPlatform.ios, 'get_flow/default'), Basis.byDefault);
      expect(basisOf(bundle, ContractPlatform.ios, 'observer_purchase_did_start/default'), Basis.byDefault);
      expect(basisOf(bundle, ContractPlatform.ios, 'is_activated/default'), Basis.record);
      expect(basisOf(bundle, ContractPlatform.ios, 'set_fallback/default'), Basis.denied);
      expect(basisOf(bundle, ContractPlatform.ios, 'adapty_ui_destroy_flow_view/default'), Basis.undecided);
      expect(basisOf(bundle, ContractPlatform.ios, 'get_flow/default/remove_required/placement_id'), Basis.undecided);
    });

    test('says whether a broken payload is refused, taken, hidden by activation or recorded', () {
      final bundle = build(
        expectations:
            '''
  - method: identify
    platform: android
    kind: remove_required
    path: /customer_user_id
    outcome: native_exception
    reason: throws on a missing value
    source: '$_androidSource'
''',
        sensitivity:
            '''
  - method: get_flow
    platform: android
    sensitivity: decodes
    insensitive_fields: [{kind: foreign_enum, path: /fetch_policy/type}]
    unobservable_fields: [{kind: swap_type, path: /placement_id}]
    reason: decodes the arguments
    source: '$_androidSource'
  - {method: identify, platform: android, sensitivity: unobservable, reason: checks activation first, source: '$_androidSource'}
  - {method: adapty_ui_destroy_flow_view, platform: android, sensitivity: insensitive, reason: takes any id, source: '$_androidSource'}
''',
      );
      expect(basisOf(bundle, ContractPlatform.android, 'get_flow/default/remove_required/placement_id'), Basis.params);
      expect(
        basisOf(bundle, ContractPlatform.android, 'adapty_ui_destroy_flow_view/default/swap_type/id'),
        Basis.insensitive,
      );
      expect(
        basisOf(
          bundle,
          ContractPlatform.android,
          'get_flow/reload_revalidating_cache_data/foreign_enum/fetch_policy/type',
        ),
        Basis.insensitive,
      );
      expect(basisOf(bundle, ContractPlatform.android, 'get_flow/default/swap_type/placement_id'), Basis.unobservable);
      expect(
        basisOf(bundle, ContractPlatform.android, 'identify/default/swap_type/customer_user_id'),
        Basis.unobservable,
      );
      expect(
        basisOf(bundle, ContractPlatform.android, 'identify/default/remove_required/customer_user_id'),
        Basis.record,
      );
    });

    test('goes into the generated library next to the expected outcome', () {
      final bundle = build(
        sensitivity:
            '''
  - {method: identify, platform: android, sensitivity: unobservable, reason: checks activation first, source: '$_androidSource'}
''',
      );
      expect(
        bundle.render(),
        contains(
          "      expected: L2aError(20, L2aMessageClass.other),\n"
          "      basis: L2aBasis.unobservable,\n",
        ),
      );
    });
  });

  group('strict mode', () {
    test('stops at a UI method without an expectation and names the expectations file', () {
      expect(
        strictProblems(),
        contains('$_expectationsPath: no expectation for adapty_ui_destroy_flow_view on ios (case default)'),
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

    final decodesOnBoth =
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

    test('a swapped type at a field the platform does not check expects what a whole payload gets', () {
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
      final android = caseOf(bundle, ContractPlatform.android, 'get_flow/placement_id_number');
      expect(android.expected, isA<ErrorOutcome>().having((o) => o.code, 'the not activated code of Android', 20));
      expect(android.basis, Basis.insensitive);
    });

    test('a broken payload of a UI method the platform does not check stays observed without a record', () {
      final numberId = requestFixture(
        'adapty_ui_destroy_flow_view',
        'id_number',
        const {'id': 5},
        expect: const {
          'violation': {'keyword': 'type', 'pointer': r'#/$requests/AdaptyUIDestroyFlowView.Request/properties/id'},
        },
      );
      final bundle = build(
        from: negatives([numberId]),
        sensitivity:
            '''
  - {method: adapty_ui_destroy_flow_view, platform: android, sensitivity: insensitive, reason: takes any id, source: '$_androidSource'}
''',
      );
      final android = caseOf(bundle, ContractPlatform.android, 'adapty_ui_destroy_flow_view/id_number');
      expect(android.expected, isA<ObserveOutcome>());
      expect(android.basis, Basis.insensitive);
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
              .having((c) => c.expected, 'expected', isA<ObserveOutcome>())
              .having((c) => c.basis, 'basis', Basis.undecided),
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
        caseOf(bundle, ContractPlatform.android, 'get_flow/without_placement_id'),
        isA<BundleCase>()
            .having((c) => c.expected, 'expected', isA<NativeExceptionOutcome>())
            .having((c) => c.basis, 'basis', Basis.record),
      );
      expect(
        caseOf(bundle, ContractPlatform.ios, 'get_flow/without_placement_id'),
        isA<BundleCase>()
            .having((c) => c.expected, 'expected', isA<ErrorOutcome>())
            .having((c) => c.basis, 'basis', Basis.params),
      );
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
        views: views,
        sdkMethods: sdkMethods,
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
            BundleCase(
              id: 'm/c',
              method: 'm',
              arguments: 'a\'b\$c\\d\ne',
              expected: const SuccessOutcome(),
              basis: Basis.record,
            ),
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

  group('the basis in the log of the probe', () {
    test('has the names of the bundle', () {
      expect({for (final b in L2aBasis.values) b.name: b.wireName}, {for (final b in Basis.values) b.name: b.wireName});
    });
  });

  group('the methods the probe covers', () {
    test('are the requests the SDK declares', () {
      expect(sdkMethodsFrom(File('lib/src/constants/method.dart').readAsStringSync()), {
        for (final m in NativeMethod.values) m.wireName,
        for (final m in NativeEventResponse.values) m.wireName,
      });
    });

    test('are on each platform the requests of the contract the SDK sends there, each called or denied', () {
      final bundle = build();
      for (final platform in ContractPlatform.values) {
        final contract = {
          for (final MapEntry(:key, :value) in schema.methodPlatforms.entries)
            if (value.contains(platform) && sdkMethods.contains(key)) key,
        };
        expect(bundle.contractMethods[platform]!.toSet(), contract, reason: platform.name);
        expect({for (final c in bundle.cases[platform]!) c.method}, contract, reason: platform.name);
      }
      expect(bundle.render(), contains('const l2aContractMethods = <String, List<String>>{'));
    });
  });

  group('what the probe reports besides the cases', () {
    test('the generated library names the iOS SDK the expectations were recorded on', () {
      final bundle = buildBundle(
        views: views,
        sdkMethods: sdkMethods,
        schema: schema,
        corpus: corpus,
        sdkVersion: '9.9.9-test',
        channelName: _channelName,
        denylist: Denylist.parse(_denylist, path: _denylistPath),
        expectations: Expectations.parse(
          _expectations(probed: '{ios_sha: 0123abcd, android: $_androidVersion}'),
          path: _expectationsPath,
          refs: refs,
        ),
        discover: true,
      );
      expect(bundle.render(), contains("const l2aProbedIosSha = '0123abcd';"));
    });

    test('expectations recorded on another Android than the one of the contract stop the bundle', () {
      expect(
        () => Expectations.parse(
          _expectations(probed: '{ios_sha: 0123abcd, android: 9.9.9}'),
          path: _expectationsPath,
          refs: refs,
        ),
        throwsA(
          isA<BundleProblems>().having(
            (e) => e.problems,
            'problems',
            contains(allOf(contains('probed.android 9.9.9'), contains(_nativeRefs.android))),
          ),
        ),
      );
    });

    test('the creation params of the embedded views go into the bundle for each platform', () {
      final bundle = buildBundle(
        views: views,
        sdkMethods: sdkMethods,
        schema: schema,
        corpus: corpus,
        sdkVersion: '9.9.9-test',
        channelName: _channelName,
        denylist: Denylist.parse(_denylist, path: _denylistPath),
        expectations: Expectations.parse(_expectations(), path: _expectationsPath, refs: refs),
        discover: true,
      );
      for (final platform in ContractPlatform.values) {
        final flow = bundle.views[platform]!.singleWhere((v) => v.id == 'flow_platform_view/default');
        expect(flow.viewType, 'adaptyui_flow_platform_view');
        expect(jsonDecode(flow.params), views.fixture('flow_platform_view', 'default', platform)!.payload);
        final onboarding = bundle.views[platform]!.singleWhere((v) => v.id == 'onboarding_platform_view/default');
        expect(onboarding.viewType, 'adaptyui_onboarding_platform_view');
      }
      expect(bundle.render(), contains("    L2aViewCase(\n      id: 'flow_platform_view/default',\n"));
    });
  });

  group('calls after the probe', () {
    final afterProbe =
        '''
  - id: set_fallback/asset
    platform: ios
    method: set_fallback
    arguments: '{"asset_id":"assets/fallback.json"}'
    outcome: success
    reason: reads the fallback file of the app
    source: '$_iosSource'
  - id: unknown_method
    platform: android
    method: no_such_method
    arguments: '{}'
    outcome: {error: {code: 2006, class: unknown-method}}
    reason: no handler has the method
    source: '$_androidSource'
''';

    List<String> parseProblems(String rows) => problemsOf(
      () => Expectations.parse(
        _expectations(afterProbe: rows),
        path: _expectationsPath,
        refs: refs,
      ),
    );

    test('go into the bundle of their platform with their outcome, a denied method included', () {
      final bundle = buildBundle(
        views: views,
        sdkMethods: sdkMethods,
        schema: schema,
        corpus: corpus,
        sdkVersion: '9.9.9-test',
        channelName: _channelName,
        denylist: Denylist.parse(_denylist, path: _denylistPath),
        expectations: Expectations.parse(
          _expectations(afterProbe: afterProbe),
          path: _expectationsPath,
          refs: refs,
        ),
        discover: true,
      );
      final ios = bundle.afterProbe[ContractPlatform.ios]!.single;
      expect(
        (ios.id, ios.method, ios.arguments, ios.basis),
        ('set_fallback/asset', 'set_fallback', '{"asset_id":"assets/fallback.json"}', Basis.record),
      );
      expect(ios.expected, isA<SuccessOutcome>());
      final android = bundle.afterProbe[ContractPlatform.android]!.single;
      expect(
        android.expected,
        isA<ErrorOutcome>().having((o) => (o.code, o.messageClass), 'error', (2006, MessageClass.unknownMethod)),
      );
      expect(bundle.render(), contains("const l2aAfterProbe = <String, List<L2aCase>>{"));
      expect(bundle.render(), contains("      id: 'unknown_method',\n"));
    });

    test('keep the order of the file', () {
      final bundle = buildBundle(
        views: views,
        sdkMethods: sdkMethods,
        schema: schema,
        corpus: corpus,
        sdkVersion: '9.9.9-test',
        channelName: _channelName,
        denylist: Denylist.parse(_denylist, path: _denylistPath),
        expectations: Expectations.parse(
          _expectations(
            afterProbe:
                '''
  - {id: first, platform: ios, method: is_activated, arguments: '{}', outcome: success, reason: answers, source: '$_iosSource'}
  - {id: second, platform: ios, method: set_log_level, arguments: '{"value":"verbose"}', outcome: success, reason: answers, source: '$_iosSource'}
''',
          ),
          path: _expectationsPath,
          refs: refs,
        ),
        discover: true,
      );
      expect([for (final c in bundle.afterProbe[ContractPlatform.ios]!) c.id], ['first', 'second']);
    });

    test('a call after the probe of a request of the contract has to be valid for it', () {
      final problems = problemsOf(
        () => buildBundle(
          views: views,
          sdkMethods: sdkMethods,
          schema: schema,
          corpus: corpus,
          sdkVersion: '9.9.9-test',
          channelName: _channelName,
          denylist: Denylist.parse(_denylist, path: _denylistPath),
          expectations: Expectations.parse(
            _expectations(
              afterProbe:
                  '''
  - {id: wrong_key, platform: ios, method: set_fallback, arguments: '{"assetId":"assets/fallback.json"}', outcome: success, reason: answers, source: '$_iosSource'}
''',
            ),
            path: _expectationsPath,
            refs: refs,
          ),
          discover: true,
        ),
      );
      expect(
        problems,
        contains(allOf(startsWith('$_expectationsPath: after_probe wrong_key on ios'), contains('assetId'))),
      );
    });

    test('a call after the probe without a source is refused', () {
      expect(
        parseProblems('''
  - {id: x, platform: ios, method: is_activated, arguments: '{}', outcome: success, reason: answers}
'''),
        contains(allOf(startsWith('$_expectationsPath: after_probe[0]'), contains('source'))),
      );
    });

    test('a call after the probe needs arguments that are JSON', () {
      expect(
        parseProblems('''
  - {id: x, platform: ios, method: is_activated, arguments: 'not json', outcome: success, reason: answers, source: '$_iosSource'}
'''),
        contains(allOf(startsWith('$_expectationsPath: after_probe[0]'), contains('JSON'))),
      );
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

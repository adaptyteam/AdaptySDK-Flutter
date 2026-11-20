import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/l2a_cases.g.dart';
import 'support/l2a_probe.dart';
import 'support/l2a_types.dart';

/// The iOS SDK the app resolved, when the script that runs the probe passes it.
const _resolvedIosSha = String.fromEnvironment('L2A_IOS_SHA');

/// The methods whose requests carry models the SDK encodes from the answers of other calls.
const _modelMethods = {
  'adapty_ui_create_flow_view',
  'adapty_ui_create_onboarding_view',
  'create_web_paywall_url',
  'get_paywall_products',
  'log_show_flow',
  'make_promoted_purchase',
  'make_purchase',
  'open_web_paywall',
};

/// Sends every case of the bundle to the plugin before activation in the first test; the other tests check
/// what it answered.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final observed = <String, L2aObserved>{};
  L2aObserved? lastIsActivated;
  var ran = false;

  Map<String, L2aObserved> answers() {
    if (!ran) fail('the probe did not run');
    return observed;
  }

  /// Every case of [cases] whose answer is not what it expects, one line each.
  List<String> mismatches(Iterable<L2aCase> cases) => [
    for (final c in cases)
      if (!l2aMatches(c.expected, answers()[c.id]!))
        '${c.id} on $l2aPlatform: expected ${jsonEncode(c.expected.toJson())}, '
            'got ${jsonEncode(answers()[c.id]!.toJson())}',
  ];

  Iterable<L2aCase> called() => l2aPlatformCases.where((c) => c.expected is! L2aSkip);

  testWidgets('the plugin answers every case of the bundle before activation', (tester) async {
    await l2aReadinessBarrier(tester);
    for (final c in called()) {
      final answer = await l2aInvoke(c);
      observed[c.id] = answer;
      print(
        'L2A_OUTCOME ${jsonEncode({'id': c.id, 'method': c.method, 'platform': l2aPlatform, 'expected': c.expected.toJson(), 'basis': c.basis.wireName, if (c.variant != null) 'variant': c.variant, if (c.instancePath != null) 'path': c.instancePath, 'observed': answer.toJson(), 'matches': l2aMatches(c.expected, answer)})}',
      );
    }
    lastIsActivated = await l2aCall('is_activated', '{}');
    ran = true;

    final byBasis = <String, int>{};
    for (final c in l2aPlatformCases) {
      byBasis.update(c.basis.wireName, (n) => n + 1, ifAbsent: () => 1);
    }
    final observedKinds = <String, int>{};
    for (final answer in observed.values) {
      observedKinds.update(answer.kind, (n) => n + 1, ifAbsent: () => 1);
    }
    final takenRequired = {
      for (final c in l2aPlatformCases)
        if (c.basis == L2aBasis.insensitive && c.variant == 'remove_required') '${c.method} ${c.instancePath}',
    };
    final notCovered = [
      'calls after activation and answers of the backend',
      'fields a plugin does not require before activation',
      'decoding of the denied methods, checked only against the contract until the end-to-end stage',
      'events of the SDK and the success path of embedded views, which wait for activation',
      'a second Flutter engine in the process',
      if (l2aPlatform == 'ios') 'iOS runtimes older than the one the expectations were recorded on',
      if (l2aPlatform == 'android')
        'decoding of the creation params of embedded views beyond their structure, which waits for activation',
      if (l2aPlatform == 'android') 'events the Android SDK sends before activation',
      if (l2aPlatform == 'android') 'a fallback file set by an absolute path, which waits for activation',
    ];
    print(
      'L2A_SUMMARY ${jsonEncode({
        'platform': l2aPlatform,
        'cases': l2aPlatformCases.length,
        'called': observed.length,
        'by_basis': byBasis,
        'observed': observedKinds,
        'unexpected': mismatches(called()).length,
        'unobservable': byBasis[L2aBasis.unobservable.wireName] ?? 0,
        'required_fields_taken': takenRequired.length,
        'required_fields_taken_cases': [for (final c in l2aPlatformCases)
          if (c.basis == L2aBasis.insensitive && c.variant == 'remove_required') c.id].length,
        'denied': [for (final c in l2aPlatformCases)
          if (c.expected is L2aSkip) c.id],
        'probed_ios_sha': l2aProbedIosSha,
        if (_resolvedIosSha.isNotEmpty) 'resolved_ios_sha': _resolvedIosSha,
        'not_covered': notCovered,
      })}',
    );
  });

  test('every golden request gets its expected answer', () {
    expect(mismatches(called().where((c) => c.variant == null)), isEmpty);
  });

  test('every request of the contract the SDK sends on this platform is called, except the denied ones', () {
    final calledMethods = {for (final c in called()) c.method};
    final deniedMethods = {
      for (final c in l2aPlatformCases)
        if (c.expected is L2aSkip) c.method,
    };
    expect(answers().length, called().length);
    expect(calledMethods.intersection(deniedMethods), isEmpty);
    expect(calledMethods.union(deniedMethods), l2aContractMethods[l2aPlatform]!.toSet());
  });

  test('every broken payload of a decoding method is refused as bad params', () {
    final refused = called().where((c) => c.basis == L2aBasis.params);
    expect(refused, isNotEmpty);
    expect(mismatches(refused), isEmpty);
  });

  test('identify decodes with and without parameters', () {
    expect(mismatches(called().where((c) => c.method == 'identify' && c.variant == null)), isEmpty);
  });

  test('the models the SDK encodes are taken by the plugin', () {
    final golden = called().where((c) => _modelMethods.contains(c.method) && c.variant == null);
    expect(golden, isNotEmpty);
    expect(mismatches(golden), isEmpty);
    expect([
      for (final c in golden)
        if (answers()[c.id]!.messageClass == L2aMessageClass.params) c.id,
    ], isEmpty);
  });

  test('an empty preload of flows is taken', () {
    final empty = called().where((c) => c.id == 'preload_flows/empty');
    expect(empty, hasLength(1));
    expect(mismatches(empty), isEmpty);
  });

  test('every recorded native exception happens again', () {
    final throwing = called().where((c) => c.expected is L2aNativeException);
    expect(mismatches(throwing), isEmpty);
  });

  test('every other case gets its expected answer', () {
    expect(mismatches(called()), isEmpty);
  });

  test('every call gets one answer in time and the plugin still answers', () {
    expect([
      for (final MapEntry(:key, :value) in answers().entries)
        if (value.kind == 'timeout') key,
    ], isEmpty);
    expect(lastIsActivated?.kind, 'success');
  });

  testWidgets('the plugin answers the calls made after the probe, then still answers', (tester) async {
    answers();
    final calls = l2aAfterProbe[l2aPlatform]!;
    expect(calls, isNotEmpty);
    final wrong = <String>[];
    for (final c in calls) {
      final answer = await l2aInvoke(c);
      final matches = l2aMatches(c.expected, answer);
      print(
        'L2A_AFTER ${jsonEncode({'id': c.id, 'method': c.method, 'platform': l2aPlatform, 'expected': c.expected.toJson(), 'observed': answer.toJson(), 'matches': matches})}',
      );
      if (!matches) {
        wrong.add(
          '${c.id} on $l2aPlatform: expected ${jsonEncode(c.expected.toJson())}, got ${jsonEncode(answer.toJson())}',
        );
      }
    }
    expect(wrong, isEmpty);
    expect((await l2aCall('is_activated', '{}')).kind, 'success');
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/l2a/src/summary.dart';

const _probed = 'c818575616deff84d8d8b1f3c62e6fa57163ebc0';
const _moved = '0123456789abcdef0123456789abcdef01234567';

/// The steps file of a run where every step passed, unless [overrides] gives its exit code; -1 leaves it out.
String _steps({Map<String, int> overrides = const {}}) => [
  for (final (name, kind) in const [
    ('device', 'infra'),
    ('pub-get', 'infra'),
    ('bundle', 'probe'),
    ('packages', 'infra'),
    ('build', 'probe'),
    ('probe', 'probe'),
    ('probe-native-log', 'probe'),
    ('views', 'probe'),
    ('views-native-log', 'probe'),
  ])
    if (overrides[name] != -1) '$name\t$kind\t${overrides[name] ?? 0}\t1\t12',
].join('\n');

const _info = 'platform\tios\nmode\tlocal\nxcode\tXcode 27.0 Build version 27A266a\ndevice\tL2A-iPhone-it';

/// The output of the probe test with an `L2A_SUMMARY` line and the outcome lines [outcomes].
String _probeLog({String resolved = _probed, List<Map<String, Object?>> outcomes = const []}) => [
  '00:00 +0: loading integration_test/l2a_probe_test.dart',
  for (final outcome in outcomes) 'L2A_OUTCOME ${jsonEncode(outcome)}',
  'L2A_SUMMARY ${jsonEncode({
    'platform': 'ios',
    'cases': 1043,
    'called': 1029,
    'by_basis': {'denied': 14, 'record': 20, 'params': 838, 'insensitive': 119, 'default': 52},
    'observed': {'error': 1018, 'success': 11},
    'unexpected': 0,
    'unobservable': 0,
    'required_fields_taken': 33,
    'required_fields_taken_cases': 52,
    'denied': ['activate/full', 'set_fallback/default'],
    'probed_ios_sha': _probed,
    if (resolved.isNotEmpty) 'resolved_ios_sha': resolved,
    'not_covered': ['calls after activation and answers of the backend'],
  })}',
  '00:01 +11: All tests passed!',
].join('\n');

const _viewsLog =
    'L2A_VIEW {"id":"flow_platform_view/default","platform":"ios","created":0,"events":[]}\n'
    '00:28 +6: All tests passed!';

L2aRun _run({String? steps, String? probeLog}) =>
    L2aRun.parse(steps: steps ?? _steps(), info: _info, logs: {'probe': probeLog ?? _probeLog(), 'views': _viewsLog});

void main() {
  test('a run whose steps all passed is green, with no warning', () {
    final run = _run();
    expect(run.failureClass, isNull);
    expect(run.warnings, isEmpty);
  });

  test('an iOS SDK that moved since the expectations were recorded is a warning, not a failure', () {
    final run = _run(probeLog: _probeLog(resolved: _moved));
    expect(run.failureClass, isNull);
    expect(run.warnings, [contains('native-moved')]);
    expect(run.toMarkdown(), allOf(contains(_moved), contains(_probed)));
  });

  test('an iOS SDK whose resolved revision is unknown is a warning', () {
    final run = _run(probeLog: _probeLog(resolved: ''));
    expect(run.failureClass, isNull);
    expect(run.warnings, [contains('unknown')]);
  });

  test('an Android run says nothing about the iOS SDK', () {
    final run = L2aRun.parse(
      steps: _steps(),
      info: 'platform\tandroid',
      logs: {'probe': _probeLog().replaceAll('"platform":"ios"', '"platform":"android"')},
    );
    expect(run.warnings, isEmpty);
    expect(run.toMarkdown(), isNot(contains('iOS SDK')));
  });

  test('a failed probe step is a probe failure', () {
    expect(_run(steps: _steps(overrides: {'probe': 1})).failureClass, 'probe');
  });

  test('a native log with a defect is a probe failure', () {
    expect(_run(steps: _steps(overrides: {'views-native-log': 1})).failureClass, 'probe');
  });

  test('an outcome that does not match its expectation is a probe failure and is listed', () {
    final run = _run(
      probeLog: _probeLog(
        outcomes: [
          {
            'id': 'get_profile/default',
            'method': 'get_profile',
            'expected': {
              'error': {'code': 2002, 'class': 'other'},
            },
            'observed': {'kind': 'success', 'ms': 3},
            'matches': false,
          },
        ],
      ),
    );
    expect(run.failureClass, 'probe');
    expect(run.toMarkdown(), contains('get_profile/default'));
  });

  test('a probe that printed no summary is a probe failure', () {
    expect(_run(probeLog: '00:01 +0 -1: Some tests failed.').failureClass, 'probe');
  });

  test('a bundle that stops the run is a probe failure', () {
    expect(
      _run(steps: _steps(overrides: {'bundle': 1, 'packages': -1, 'build': -1, 'probe': -1, 'views': -1})).failureClass,
      'probe',
    );
  });

  test('a failed infra step is an infra failure, whatever came after it', () {
    expect(
      _run(steps: _steps(overrides: {'packages': 65, 'build': -1, 'probe': -1, 'views': -1})).failureClass,
      'infra',
    );
  });

  test('a run that stopped before the probe is an infra failure', () {
    expect(_run(steps: _steps(overrides: {'probe': -1, 'views': -1})).failureClass, 'infra');
    expect(_run(steps: '').failureClass, 'infra');
  });

  test('the main count of required fields is by method and path, with the count of cases next to it', () {
    expect(_run().toMarkdown(), contains('by method and path: 33 (cases: 52)'));
  });

  test('the summary names the Xcode, the denied cases and what the probe does not cover', () {
    expect(
      _run().toMarkdown(),
      allOf(contains('Xcode 27.0'), contains('set_fallback/default'), contains('calls after activation')),
    );
  });

  test('the summary shows how many cases of each basis the probe called', () {
    expect(_run().toMarkdown(), allOf(contains('params'), contains('838'), contains('insensitive'), contains('119')));
  });
}

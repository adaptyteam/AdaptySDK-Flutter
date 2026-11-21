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

const _info =
    'platform\tios\nmode\tlocal\nxcode\tXcode 27.0 Build version 27A266a\nxcode_version\t27.0\nios_runtime\t27.0\n'
    'device\tL2A-iPhone-it';

/// The cases the probe of [_probeLog] says it called.
const _called = 1029;

/// The output of the probe test with an `L2A_SUMMARY` line, the outcome lines [outcomes] and as many matching
/// outcome lines after them as make one for each case called, less [lost] of them.
String _probeLog({
  String resolved = _probed,
  List<Map<String, Object?>> outcomes = const [],
  List<Map<String, Object?>> after = const [],
  int lost = 0,
}) => [
  '00:00 +0: loading integration_test/l2a_probe_test.dart',
  for (final outcome in outcomes) 'L2A_OUTCOME ${jsonEncode(outcome)}',
  for (var i = outcomes.length; i < _called - lost; i++) 'L2A_OUTCOME {"id":"case_$i/default","matches":true}',
  for (final outcome in after) 'L2A_AFTER ${jsonEncode(outcome)}',
  'L2A_SUMMARY ${jsonEncode({
    'platform': 'ios',
    'cases': 1043,
    'called': _called,
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

/// The iOS runtime and Xcode the expectations were recorded on, as `probed` of the expectations names them.
const _probedTools = {'ios_runtime': '27.0', 'xcode': '27.0'};

L2aRun _run({String? steps, String? probeLog, String info = _info, Map<String, String> probed = _probedTools}) =>
    L2aRun.parse(
      steps: steps ?? _steps(),
      info: info,
      logs: {'probe': probeLog ?? _probeLog(), 'views': _viewsLog},
      probed: probed,
    );

/// The steps file of an Android run where every step passed, with each of [tests] under the egress guard, less the
/// steps [without].
String _androidSteps({List<String> tests = const ['probe', 'views'], Set<String> without = const {}}) => [
  for (final (name, kind) in [
    ('device', 'infra'),
    ('pub-get', 'infra'),
    ('bundle', 'probe'),
    for (final test in tests) ...[
      ('$test-guard-ready', 'infra'),
      (test, 'probe'),
      ('$test-egress', 'probe'),
      ('$test-native-log', 'probe'),
    ],
  ])
    if (!without.contains(name)) '$name\t$kind\t0\t1\t12',
].join('\n');

const _fragmentInfo = 'platform\tandroid\nmode\tlocal\nvariant\tfragment activity';
const _flutterActivityInfo = 'platform\tandroid\nmode\tlocal\nvariant\tflutter-activity activity';

L2aRun _androidRun({String? steps, String info = _fragmentInfo, String? probeLog}) => L2aRun.parse(
  steps: steps ?? _androidSteps(),
  info: info,
  logs: {'probe': (probeLog ?? _probeLog()).replaceAll('"platform":"ios"', '"platform":"android"')},
);

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
    final run = _androidRun();
    expect(run.warnings, isEmpty);
    expect(run.toMarkdown(), isNot(contains('iOS SDK')));
  });

  test('a warning of a native log check is a warning of the run, not a failure', () {
    final run = L2aRun.parse(
      steps: _steps(),
      info: _info,
      logs: {
        'probe': _probeLog(),
        'views': _viewsLog,
        'probe-native-log':
            'L2A_WARNING defect check incomplete: 912 of 923 requests the plugin is expected to refuse '
            'are in the log; 1 loss events (1 messages lost) in the window\nno defect in the native log',
      },
      probed: _probedTools,
    );
    expect(run.failureClass, isNull);
    expect(run.warnings, [startsWith('defect check incomplete: 912 of 923')]);
    expect(run.toMarkdown(), contains('defect check incomplete'));
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

  test('a call after the probe that does not match its expectation is listed', () {
    final run = _run(
      probeLog: _probeLog(
        after: [
          {
            'id': 'set_fallback/asset',
            'method': 'set_fallback',
            'expected': 'success',
            'observed': {'kind': 'error', 'code': 0, 'ms': 4},
            'matches': false,
          },
        ],
      ),
    );
    expect(run.failureClass, 'probe');
    expect(run.toMarkdown(), contains('set_fallback/asset'));
  });

  test('an iOS runtime or Xcode other than the ones the expectations were recorded on is a warning', () {
    final runtime = _run(info: _info.replaceAll('ios_runtime\t27.0', 'ios_runtime\t26.5'));
    expect(runtime.failureClass, isNull);
    expect(runtime.warnings, [allOf(contains('runtime-moved'), contains('iOS 26.5'), contains('iOS 27.0'))]);
    final xcode = _run(info: _info.replaceAll('xcode_version\t27.0', 'xcode_version\t26.6'));
    expect(xcode.failureClass, isNull);
    expect(xcode.warnings, [allOf(contains('runtime-moved'), contains('Xcode 26.6'), contains('Xcode 27.0'))]);
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

  test('a full Android run is green, with either activity', () {
    expect(_androidRun().failureClass, isNull);
    expect(
      _androidRun(
        steps: _androidSteps(tests: ['probe', 'flutter_activity']),
        info: _flutterActivityInfo,
      ).failureClass,
      isNull,
    );
  });

  test('a probe that printed fewer outcomes than the cases it called is a probe failure', () {
    expect(_run(probeLog: _probeLog(lost: 1)).failureClass, 'probe');
    expect(_androidRun(probeLog: _probeLog(lost: 1)).failureClass, 'probe');
  });

  test('a probe that printed more outcomes than the cases it called is a probe failure', () {
    final extra = '${_probeLog()}\nL2A_OUTCOME {"id":"case_0/default","matches":true}';
    expect(_run(probeLog: extra).failureClass, 'probe');
  });

  test('an outcome line cut short does not count as an outcome', () {
    final cut = _probeLog().replaceFirst(
      'L2A_OUTCOME {"id":"case_0/default","matches":true}',
      'L2A_OUTCOME {"id":"case_0/defa',
    );
    expect(_run(probeLog: cut).failureClass, 'probe');
  });

  test('a call after the probe does not count as an outcome', () {
    final after = [
      {'id': 'set_fallback/asset', 'matches': true},
      {'id': 'get_profile/after', 'matches': true},
    ];
    expect(_run(probeLog: _probeLog(after: after)).failureClass, isNull);
    expect(_run(probeLog: _probeLog(after: after.take(1).toList(), lost: 1)).failureClass, 'probe');
  });

  test('a run without a step its script always records once it gets to the tests is an infra failure', () {
    for (final step in ['probe', 'views', 'probe-native-log', 'views-native-log']) {
      expect(
        _run(steps: _steps(overrides: {step: -1})).failureClass,
        'infra',
        reason: 'iOS without $step',
      );
    }
    for (final step in ['probe', 'probe-egress', 'probe-native-log', 'views', 'views-egress', 'views-native-log']) {
      expect(
        _androidRun(steps: _androidSteps(without: {step})).failureClass,
        'infra',
        reason: 'Android without $step',
      );
    }
    for (final step in [
      'probe',
      'probe-egress',
      'probe-native-log',
      'flutter_activity',
      'flutter_activity-egress',
      'flutter_activity-native-log',
    ]) {
      final run = _androidRun(
        steps: _androidSteps(tests: ['probe', 'flutter_activity'], without: {step}),
        info: _flutterActivityInfo,
      );
      expect(run.failureClass, 'infra', reason: 'FlutterActivity without $step');
    }
  });

  test('an Android run needs the steps of the test of its activity', () {
    expect(_androidRun(info: _flutterActivityInfo).failureClass, 'infra');
    expect(_androidRun(steps: _androidSteps(tests: ['probe', 'flutter_activity'])).failureClass, 'infra');
  });

  test('a probe log that a run into the same directory appended to is read from its last run', () {
    String header(String commit) => '# command (repository adapty_flutter @ $commit, working tree clean): bash -c …';
    final mismatch = {'id': 'get_profile/default', 'expected': 'success', 'observed': 'error', 'matches': false};
    final twice = [header('41a617e'), _probeLog(), header('cff8411'), _probeLog()].join('\n');
    expect(_run(probeLog: twice).failureClass, isNull);
    final redThenGreen = [
      header('41a617e'),
      _probeLog(outcomes: [mismatch]),
      header('cff8411'),
      _probeLog(),
    ].join('\n');
    expect(_run(probeLog: redThenGreen).failureClass, isNull);
    final greenThenLost = [header('41a617e'), _probeLog(), header('cff8411'), _probeLog(lost: 1)].join('\n');
    expect(_run(probeLog: greenThenLost).failureClass, 'probe');
    final lostLostGreen = [
      for (final (commit, lost) in [('41a617e', 1), ('cff8411', 1), ('0123456', 0)]) ...[
        header(commit),
        _probeLog(lost: lost),
      ],
    ].join('\n');
    expect(_run(probeLog: lostLostGreen).failureClass, isNull);
  });

  test('a run that names no platform the scripts know is an infra failure', () {
    expect(_run(info: _info.replaceAll('platform\tios\n', '')).failureClass, 'infra');
    expect(_run(info: _info.replaceAll('platform\tios', 'platform\tweb')).failureClass, 'infra');
  });

  test('a run that lost both a step and an outcome is an infra failure', () {
    expect(
      _run(
        steps: _steps(overrides: {'views-native-log': -1}),
        probeLog: _probeLog(lost: 1),
      ).failureClass,
      'infra',
    );
  });

  test('a run that lost a step and whose probe printed no summary is an infra failure', () {
    final run = _run(
      steps: _steps(overrides: {'views-native-log': -1}),
      probeLog: '00:01 +0 -1: Some tests failed.',
    );
    expect(run.failureClass, 'infra');
    expect(run.toMarkdown(), contains('Reason: missing steps: views-native-log'));
  });

  test('a run that lost a step and whose plugin answered other than expected is an infra failure', () {
    final mismatch = {'id': 'get_profile/default', 'expected': 'success', 'observed': 'error', 'matches': false};
    final run = _run(
      steps: _steps(overrides: {'views-native-log': -1}),
      probeLog: _probeLog(outcomes: [mismatch]),
    );
    expect(run.failureClass, 'infra');
    expect(run.toMarkdown(), contains('Reason: missing steps: views-native-log'));
  });

  test('a red summary says what made the run red', () {
    expect(_run(probeLog: _probeLog(lost: 1)).toMarkdown(), contains('Reason: outcomes read: 1028 of 1029 called'));
    expect(
      _run(steps: _steps(overrides: {'views-native-log': -1})).toMarkdown(),
      contains('Reason: missing steps: views-native-log'),
    );
    expect(
      _androidRun(steps: _androidSteps(without: {'probe-egress', 'views-egress'})).toMarkdown(),
      contains('Reason: missing steps: probe-egress, views-egress'),
    );
    expect(
      _run(info: _info.replaceAll('platform\tios', 'platform\tweb')).toMarkdown(),
      contains('Reason: the run names no platform the scripts know (web)'),
    );
    expect(_run(steps: _steps(overrides: {'probe': 1})).toMarkdown(), contains('Reason: failed steps: probe'));
    expect(
      _run(steps: _steps(overrides: {'packages': 65, 'build': -1, 'probe': -1, 'views': -1})).toMarkdown(),
      contains('Reason: failed steps: packages'),
    );
    expect(
      _run(steps: _steps(overrides: {'probe': -1, 'views': -1})).toMarkdown(),
      contains('Reason: the run stopped before the probe'),
    );
    expect(_run(probeLog: '00:01 +0 -1: Some tests failed.').toMarkdown(), contains('Reason: the probe printed no'));
    final mismatch = {'id': 'get_profile/default', 'expected': 'success', 'observed': 'error', 'matches': false};
    expect(
      _run(probeLog: _probeLog(outcomes: [mismatch])).toMarkdown(),
      contains('Reason: answers other than expected: 1'),
    );
  });

  test('a green summary gives no reason', () {
    expect(_run().toMarkdown(), isNot(contains('Reason:')));
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

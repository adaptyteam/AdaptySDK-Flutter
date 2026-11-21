// The jobs of ci.yml that build with the Flutter of the repository (api, android-unit) set its version as a literal,
// while .fvmrc is what developers and the native probe workflow run. A literal left behind after .fvmrc moves would
// compare the public API or build the Android plugin on another Flutter, and every job would still pass.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const _action = 'subosito/flutter-action';

/// The jobs that set the Flutter of the repository as a literal.
const _literalJobs = ['api', 'android-unit'];

/// The only job that may run on the floor of pubspec.yaml, and how it names it.
const _floorJob = 'analyze-test-min';
const _floor = r'${{ env.FLUTTER_FLOOR }}';

/// How a job runs on the channels of its matrix instead of a version.
const _matrixChannel = r'${{ matrix.channel }}';

/// What is wrong with the Flutter versions of the workflow [text], given [fvmrc], the Flutter of the repository.
List<String> flutterVersionProblems(String text, String fvmrc) {
  final workflow = loadYaml(text);
  final jobs = workflow is YamlMap ? workflow['jobs'] : null;
  if (jobs is! YamlMap) return ['no jobs'];

  final problems = <String>[];
  final literals = <String>{};
  for (final MapEntry(key: name, value: job) in jobs.entries) {
    final steps = job is YamlMap ? job['steps'] : null;
    if (steps is! YamlList) continue;
    for (final step in steps) {
      if (step is! YamlMap || !'${step['uses']}'.startsWith('$_action@')) continue;
      final inputs = step['with'];
      final version = inputs is YamlMap ? inputs['flutter-version'] : null;
      final channel = inputs is YamlMap ? inputs['channel'] : null;
      if (version == null) {
        if (channel != _matrixChannel) {
          problems.add('$name: $_action sets neither flutter-version nor channel $_matrixChannel');
        } else if (_matrixChannels(job as YamlMap) case final channels when !channels.every((c) => c == 'stable')) {
          problems.add('$name: the matrix runs channels ${channels.join(', ')}, not only stable');
        }
      } else if (version == _floor) {
        if (name != _floorJob) problems.add('$name: flutter-version is the floor, which only $_floorJob may run');
      } else if (version is String && version.startsWith(r'${{')) {
        problems.add('$name: flutter-version is $version, neither a literal nor the floor');
      } else {
        literals.add(name as String);
        if ('$version' != fvmrc) problems.add('$name: flutter-version is $version, not $fvmrc as in .fvmrc');
      }
    }
  }
  for (final job in _literalJobs) {
    if (!literals.contains(job)) problems.add('$job: no $_action step sets flutter-version as a literal');
  }
  return problems;
}

/// The channels the matrix of [job] runs: its `channel` list, or the `channel` of each of its `include` entries.
List<Object?> _matrixChannels(YamlMap job) {
  final strategy = job['strategy'];
  final matrix = strategy is YamlMap ? strategy['matrix'] : null;
  if (matrix is! YamlMap) return [null];
  final channels = [
    if (matrix['channel'] case final YamlList list) ...list,
    if (matrix['include'] case final YamlList include)
      for (final entry in include) entry is YamlMap ? entry['channel'] : null,
  ];
  return channels.isEmpty ? [null] : channels;
}

/// The Flutter of the repository.
String _fvmrc() => (jsonDecode(File('.fvmrc').readAsStringSync()) as Map<String, Object?>)['flutter'] as String;

/// A workflow with the jobs that set the literal [version], the floor job and the matrix job, with [extra] jobs after.
String _workflow({String version = '3.50.1', String extra = ''}) =>
    '''
jobs:
  analyze-test-min:
    env:
      FLUTTER_FLOOR: 3.32.0
    steps:
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: \${{ env.FLUTTER_FLOOR }}
          channel: stable
  analyze-test:
    strategy:
      matrix:
        include:
          - name: stable
            channel: stable
    steps:
      - uses: subosito/flutter-action@v2
        with:
          channel: \${{ matrix.channel }}
  api:
    steps:
      - uses: actions/checkout@v5
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: $version # keep in sync with .fvmrc
  android-unit:
    steps:
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: $version
$extra''';

void main() {
  test('the jobs of ci.yml run the Flutter of .fvmrc, the floor only in the min job, or the stable channel', () {
    expect(flutterVersionProblems(File('.github/workflows/ci.yml').readAsStringSync(), _fvmrc()), isEmpty);
  });

  group('reading a workflow', () {
    test('literals equal to .fvmrc, the floor in the min job and the stable matrix are right', () {
      expect(flutterVersionProblems(_workflow(), '3.50.1'), isEmpty);
    });

    test('a literal other than .fvmrc is wrong in each job that sets it', () {
      expect(flutterVersionProblems(_workflow(), '3.50.2'), [
        'api: flutter-version is 3.50.1, not 3.50.2 as in .fvmrc',
        'android-unit: flutter-version is 3.50.1, not 3.50.2 as in .fvmrc',
      ]);
    });

    test('a job that lost its literal, or runs a channel instead, is wrong', () {
      final noVersion = _workflow().replaceFirst('          flutter-version: 3.50.1\n', '');
      expect(flutterVersionProblems(noVersion, '3.50.1'), [
        'android-unit: subosito/flutter-action sets neither flutter-version nor channel \${{ matrix.channel }}',
        'android-unit: no subosito/flutter-action step sets flutter-version as a literal',
      ]);
      final channel = _workflow().replaceFirst('          flutter-version: 3.50.1\n', '          channel: stable\n');
      expect(flutterVersionProblems(channel, '3.50.1'), hasLength(2));
      final noStep = _workflow().replaceFirst(RegExp(r'  android-unit:\n[\s\S]*$'), '');
      expect(flutterVersionProblems(noStep, '3.50.1'), [
        'android-unit: no subosito/flutter-action step sets flutter-version as a literal',
      ]);
    });

    test('the floor outside the min job is wrong', () {
      final floor = _workflow().replaceFirst(
        '          flutter-version: 3.50.1 # keep',
        '          flutter-version: \${{ env.FLUTTER_FLOOR }} # keep',
      );
      expect(flutterVersionProblems(floor, '3.50.1'), [
        'api: flutter-version is the floor, which only analyze-test-min may run',
        'api: no subosito/flutter-action step sets flutter-version as a literal',
      ]);
    });

    test('a version from another expression is wrong', () {
      final expression = _workflow(
        extra: '''
  other:
    steps:
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: \${{ vars.FLUTTER }}
''',
      );
      expect(flutterVersionProblems(expression, '3.50.1'), [
        'other: flutter-version is \${{ vars.FLUTTER }}, neither a literal nor the floor',
      ]);
    });

    test('a matrix that runs a channel other than stable is wrong', () {
      final beta = _workflow().replaceFirst(
        '            channel: stable\n',
        '            channel: stable\n          - name: beta\n            channel: beta\n',
      );
      expect(flutterVersionProblems(beta, '3.50.1'), [
        'analyze-test: the matrix runs channels stable, beta, not only stable',
      ]);
    });

    test('a literal that YAML reads as a number is compared as it reads', () {
      expect(flutterVersionProblems(_workflow(version: '3.50'), '3.50.1'), [
        'api: flutter-version is 3.5, not 3.50.1 as in .fvmrc',
        'android-unit: flutter-version is 3.5, not 3.50.1 as in .fvmrc',
      ]);
    });
  });
}

// CI runs on Linux in UTC, where a date sent from a local time never moves to another day: the SDK could send a
// birthday as the UTC date of a local midnight and every test would still pass. The contract request tests therefore
// run once more in a timezone ahead of UTC, where a local midnight falls on the day before in UTC.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Timezones ahead of UTC all year round (no daylight saving time), so a local midnight is always the day before in
/// UTC.
const _aheadOfUtc = {'Asia/Dubai', 'Asia/Kolkata', 'Asia/Tokyo'};

/// The test files that have to run in such a timezone.
const _files = ['test/contract/requests_test.dart', 'test/contract/platform_view_params_test.dart'];

const _job = 'analyze-test';
const _rootTests = 'Test root package';

/// The keys a step may have: anything else could skip it (`if`), let it fail without failing the job
/// (`continue-on-error`) or run it somewhere else (`working-directory`).
const _stepKeys = {'name', 'env', 'run'};

/// What is wrong with the workflow [text] for the run of the contract request tests in a timezone ahead of UTC.
List<String> timezoneStepProblems(String text) {
  final workflow = loadYaml(text);
  final jobs = workflow is YamlMap ? workflow['jobs'] : null;
  final job = jobs is YamlMap ? jobs[_job] : null;
  final steps = job is YamlMap ? job['steps'] : null;
  if (steps is! YamlList) return ['no job $_job with steps'];

  final names = [for (final step in steps) step is YamlMap ? step['name'] : null];
  final rootTests = names.indexOf(_rootTests);
  if (rootTests < 0) return ['no step "$_rootTests" in $_job'];

  final runs = [
    for (final (index, step) in steps.indexed)
      if (step is YamlMap && step['run'] is String && _files.every((step['run'] as String).contains)) (index, step),
  ];
  if (runs.isEmpty) return ['no step of $_job runs ${_files.join(' and ')}'];

  return [
    for (final (index, step) in runs) ...[
      if (!_isExactRun(step['run'] as String))
        '${step['name']}: "${step['run']}" is not exactly flutter test with ${_files.join(' and ')}',
      if (step.keys.where((key) => !_stepKeys.contains(key)).toList() case final others when others.isNotEmpty)
        '${step['name']}: has keys other than name, env and run: ${others.join(', ')}',
      if (index < rootTests) '${step['name']}: runs before "$_rootTests"',
      if (_timezone(step, job) case final tz when !_aheadOfUtc.contains(tz))
        '${step['name']}: TZ is $tz, not one of ${_aheadOfUtc.join(', ')}',
    ],
  ];
}

/// Whether [run] is `flutter test` with each of the files once and nothing else.
bool _isExactRun(String run) {
  final words = run.trim().split(RegExp(r'\s+'));
  return words.length == 2 + _files.length &&
      words[0] == 'flutter' &&
      words[1] == 'test' &&
      words.skip(2).toSet().containsAll(_files);
}

/// The timezone [step] runs in: its own, else the one of [job].
Object? _timezone(YamlMap step, YamlMap job) {
  final ofStep = step['env'];
  if (ofStep is YamlMap && ofStep.containsKey('TZ')) return ofStep['TZ'];
  final ofJob = job['env'];
  return ofJob is YamlMap ? ofJob['TZ'] : null;
}

/// A workflow with the job and [steps] after the step that runs every test of the root package.
String _workflow(String steps) => '''
jobs:
  analyze-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - name: Test root package
        run: flutter test
$steps''';

const _step = '''
      - name: Test the contract requests ahead of UTC
        env:
          TZ: Asia/Dubai
        run: flutter test test/contract/requests_test.dart test/contract/platform_view_params_test.dart
''';

void main() {
  test(
    'the workflow runs the contract request tests in a timezone ahead of UTC after the tests of the root package',
    () {
      expect(timezoneStepProblems(File('.github/workflows/ci.yml').readAsStringSync()), isEmpty);
    },
  );

  group('reading a workflow', () {
    test('a step after the tests of the root package that runs both files in Asia/Dubai is right', () {
      expect(timezoneStepProblems(_workflow(_step)), isEmpty);
    });

    test('without such a step, the workflow is wrong', () {
      expect(timezoneStepProblems(_workflow('')), [
        'no step of analyze-test runs test/contract/requests_test.dart and test/contract/platform_view_params_test.dart',
      ]);
    });

    test('a step that runs one of the files only does not count', () {
      expect(
        timezoneStepProblems(_workflow(_step.replaceFirst(' test/contract/platform_view_params_test.dart', ''))),
        hasLength(1),
      );
    });

    test('a timezone that is UTC, behind it or has daylight saving time is wrong', () {
      for (final tz in ['UTC', 'America/New_York', 'Europe/Berlin']) {
        expect(timezoneStepProblems(_workflow(_step.replaceFirst('Asia/Dubai', tz))), [
          contains('TZ is $tz'),
        ], reason: tz);
      }
      expect(timezoneStepProblems(_workflow(_step.replaceFirst('        env:\n          TZ: Asia/Dubai\n', ''))), [
        contains('TZ is null'),
      ]);
    });

    test('a step before the tests of the root package is wrong', () {
      final before = _workflow(
        '',
      ).replaceFirst('      - name: Test root package\n', '$_step      - name: Test root package\n');
      expect(timezoneStepProblems(before), [contains('runs before "Test root package"')]);
    });

    test('a run that is anything but flutter test with both files is wrong', () {
      const run = 'flutter test test/contract/requests_test.dart test/contract/platform_view_params_test.dart';
      for (final other in [
        'echo $run',
        '$run || true',
        'flutter test --plain-name each test/contract/requests_test.dart test/contract/platform_view_params_test.dart',
        '$run test/contract/responses_test.dart',
      ]) {
        expect(timezoneStepProblems(_workflow(_step.replaceFirst('run: $run', 'run: $other'))), [
          contains('is not exactly flutter test with'),
        ], reason: other);
      }
    });

    test('a step that may be skipped, may fail without failing the job or runs elsewhere is wrong', () {
      for (final key in ['if: false', 'continue-on-error: true', 'working-directory: example']) {
        final step = _step.replaceFirst('        env:\n', '        $key\n        env:\n');
        expect(timezoneStepProblems(_workflow(step)), [
          contains('has keys other than name, env and run: ${key.split(':').first}'),
        ], reason: key);
      }
    });

    test('the timezone of the job counts for a step without one, and the step overrides it', () {
      final inJob = _workflow(
        _step.replaceFirst('        env:\n          TZ: Asia/Dubai\n', ''),
      ).replaceFirst('    runs-on: ubuntu-latest\n', '    runs-on: ubuntu-latest\n    env:\n      TZ: Asia/Dubai\n');
      expect(timezoneStepProblems(inJob), isEmpty);

      final overridden = _workflow(
        _step.replaceFirst('TZ: Asia/Dubai', 'TZ: UTC'),
      ).replaceFirst('    runs-on: ubuntu-latest\n', '    runs-on: ubuntu-latest\n    env:\n      TZ: Asia/Dubai\n');
      expect(timezoneStepProblems(overridden), [contains('TZ is UTC')]);
    });

    test('a workflow without the job or the step of the root tests is wrong', () {
      expect(timezoneStepProblems('jobs:\n  api:\n    steps: []\n'), ['no job analyze-test with steps']);
      expect(timezoneStepProblems(_workflow(_step).replaceFirst('Test root package', 'Test')), [
        'no step "Test root package" in analyze-test',
      ]);
    });
  });
}

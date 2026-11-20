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

/// What is wrong with the workflow [text] for the run of the contract request tests in a timezone ahead of UTC.
List<String> timezoneStepProblems(String text) {
  final workflow = loadYaml(text);
  final steps = workflow is YamlMap ? (workflow['jobs'] as YamlMap?)?[_job]?['steps'] : null;
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
      if (!(step['run'] as String).trimLeft().startsWith('flutter test ')) '${step['name']}: not a flutter test run',
      if (index < rootTests) '${step['name']}: runs before "$_rootTests"',
      if (!_aheadOfUtc.contains((step['env'] as YamlMap?)?['TZ']))
        '${step['name']}: TZ is ${(step['env'] as YamlMap?)?['TZ']}, not one of ${_aheadOfUtc.join(', ')}',
    ],
  ];
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

    test('a step that is not a flutter test run is wrong', () {
      expect(timezoneStepProblems(_workflow(_step.replaceFirst('run: flutter test', 'run: echo flutter test'))), [
        contains('not a flutter test run'),
      ]);
    });

    test('a workflow without the job or the step of the root tests is wrong', () {
      expect(timezoneStepProblems('jobs:\n  api:\n    steps: []\n'), ['no job analyze-test with steps']);
      expect(timezoneStepProblems(_workflow(_step).replaceFirst('Test root package', 'Test')), [
        'no step "Test root package" in analyze-test',
      ]);
    });
  });
}

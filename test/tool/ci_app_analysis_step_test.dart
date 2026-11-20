// The integration test app is built only by the native probe, and only when native inputs change, so CI analyzes it
// with the root package. Its cases are generated and git-ignored: without the generator the analyzer reports the
// missing file, and with it every pull request shows a probe test that no longer compiles against the bundle.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const _job = 'analyze-test';
const _resolveRoot = 'Resolve root package';
const _app = 'integration_test_app';

/// The commands, each a step of its own: the bundle runs from the repository root, the other two in the app.
const _bundle = 'dart run tool/l2a/bundle_cases.dart --discover';
const _pubGet = 'flutter pub get';
const _analyze = 'flutter analyze';

/// The keys these steps may have: anything else could skip a step (`if`) or let it fail without failing the job
/// (`continue-on-error`).
const _stepKeys = {'name', 'run', 'working-directory'};

/// What is wrong with the workflow [text] for the analysis of the integration test app.
List<String> appAnalysisProblems(String text) {
  final workflow = loadYaml(text);
  final jobs = workflow is YamlMap ? workflow['jobs'] : null;
  final job = jobs is YamlMap ? jobs[_job] : null;
  final steps = job is YamlMap ? job['steps'] : null;
  if (steps is! YamlList) return ['no job $_job with steps'];

  final problems = <String>[];
  final timeout = job['timeout-minutes'];
  if (timeout is! int || timeout <= 0) problems.add('$_job has no timeout');

  final resolveRoot = [for (final step in steps) step is YamlMap ? step['name'] : null].indexOf(_resolveRoot);
  if (resolveRoot < 0) return [...problems, 'no step "$_resolveRoot" in $_job'];

  int? find(String run, String? directory) {
    for (final (index, step) in steps.indexed) {
      if (step is YamlMap && '${step['run']}'.trim() == run && step['working-directory'] == directory) {
        if (step.keys.where((key) => !_stepKeys.contains(key)).toList() case final others when others.isNotEmpty) {
          problems.add('${step['name']}: has keys other than name, run and working-directory: ${others.join(', ')}');
        }
        return index;
      }
    }
    problems.add('no step of $_job runs "$run" in ${directory ?? 'the repository root'}');
    return null;
  }

  final bundle = find(_bundle, null);
  final pubGet = find(_pubGet, _app);
  final analyze = find(_analyze, _app);
  if (bundle != null && bundle < resolveRoot) problems.add('the bundle runs before "$_resolveRoot"');
  if (analyze != null && bundle != null && analyze < bundle) problems.add('the app is analyzed before the bundle');
  if (analyze != null && pubGet != null && analyze < pubGet) problems.add('the app is analyzed before flutter pub get');
  return problems;
}

/// A workflow with the job, its [timeout] and [steps] after the step that resolves the root package.
String _workflow(String steps, {String timeout = '    timeout-minutes: 30\n'}) =>
    '''
jobs:
  analyze-test:
    runs-on: ubuntu-latest
$timeout    steps:
      - uses: actions/checkout@v5
      - name: Resolve root package
        run: flutter pub get
$steps''';

const _bundleStep = '''
      - name: Generate the cases of the integration test app
        run: dart run tool/l2a/bundle_cases.dart --discover
''';

const _pubGetStep = '''
      - name: Resolve the integration test app
        working-directory: integration_test_app
        run: flutter pub get
''';

const _analyzeStep = '''
      - name: Analyze the integration test app
        working-directory: integration_test_app
        run: flutter analyze
''';

void main() {
  test('the workflow generates the cases of the integration test app and analyzes the app, with a timeout', () {
    expect(appAnalysisProblems(File('.github/workflows/ci.yml').readAsStringSync()), isEmpty);
  });

  group('reading a workflow', () {
    test('the bundle, flutter pub get and flutter analyze in the app after the root is resolved are right', () {
      expect(appAnalysisProblems(_workflow('$_bundleStep$_pubGetStep$_analyzeStep')), isEmpty);
      expect(appAnalysisProblems(_workflow('$_pubGetStep$_bundleStep$_analyzeStep')), isEmpty);
    });

    test('without the bundle the app is analyzed without its cases, which is wrong', () {
      expect(appAnalysisProblems(_workflow('$_pubGetStep$_analyzeStep')), [
        'no step of analyze-test runs "dart run tool/l2a/bundle_cases.dart --discover" in the repository root',
      ]);
    });

    test('without the analysis of the app, or its flutter pub get, the workflow is wrong', () {
      expect(appAnalysisProblems(_workflow('$_bundleStep$_pubGetStep')), [
        'no step of analyze-test runs "flutter analyze" in integration_test_app',
      ]);
      expect(appAnalysisProblems(_workflow('$_bundleStep$_analyzeStep')), [
        'no step of analyze-test runs "flutter pub get" in integration_test_app',
      ]);
    });

    test('an analysis in the root or a bundle in the app does not count', () {
      expect(
        appAnalysisProblems(
          _workflow('$_bundleStep$_pubGetStep${_analyzeStep.replaceFirst('integration_test_app', 'example')}'),
        ),
        ['no step of analyze-test runs "flutter analyze" in integration_test_app'],
      );
      final inApp = _bundleStep.replaceFirst(
        '        run:',
        '        working-directory: integration_test_app\n        run:',
      );
      expect(appAnalysisProblems(_workflow('$inApp$_pubGetStep$_analyzeStep')), [
        'no step of analyze-test runs "dart run tool/l2a/bundle_cases.dart --discover" in the repository root',
      ]);
    });

    test('an analysis before the bundle or before flutter pub get is wrong', () {
      expect(appAnalysisProblems(_workflow('$_pubGetStep$_analyzeStep$_bundleStep')), [
        'the app is analyzed before the bundle',
      ]);
      expect(appAnalysisProblems(_workflow('$_bundleStep$_analyzeStep$_pubGetStep')), [
        'the app is analyzed before flutter pub get',
      ]);
    });

    test('a bundle before the root package is resolved is wrong', () {
      final before = _workflow(
        '$_pubGetStep$_analyzeStep',
      ).replaceFirst('      - name: Resolve root package\n', '$_bundleStep      - name: Resolve root package\n');
      expect(appAnalysisProblems(before), ['the bundle runs before "Resolve root package"']);
    });

    test('a step that may be skipped or may fail without failing the job is wrong', () {
      for (final key in ['if: false', 'continue-on-error: true']) {
        final step = _analyzeStep.replaceFirst('        run:', '        $key\n        run:');
        expect(appAnalysisProblems(_workflow('$_bundleStep$_pubGetStep$step')), [
          'Analyze the integration test app: has keys other than name, run and working-directory: ${key.split(':').first}',
        ], reason: key);
      }
    });

    test('a job without a timeout is wrong', () {
      expect(appAnalysisProblems(_workflow('$_bundleStep$_pubGetStep$_analyzeStep', timeout: '')), [
        'analyze-test has no timeout',
      ]);
    });

    test('a workflow without the job or the step that resolves the root package is wrong', () {
      expect(appAnalysisProblems('jobs:\n  api:\n    steps: []\n'), ['no job analyze-test with steps']);
      expect(
        appAnalysisProblems(
          _workflow('$_bundleStep$_pubGetStep$_analyzeStep').replaceFirst('Resolve root package', 'Resolve'),
        ),
        ['no step "Resolve root package" in analyze-test'],
      );
    });
  });
}

// The job that runs the native probe on simulators (.github/workflows/l2a.yml) and its scripts
// (tool/l2a/ci/): the decisions behind them, which a workflow run on GitHub would only show by failing, and the
// behaviour of the parts that run on a machine without devices (the gate, the egress guard on a fake adb).
@TestOn('mac-os || linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/l2a/src/summary.dart';
import 'workflow_actions.dart';

const _workflowPath = '.github/workflows/l2a.yml';
const _iosScript = 'tool/l2a/ci/ios.sh';
const _androidScript = 'tool/l2a/ci/android.sh';
const _common = 'tool/l2a/ci/common.sh';
const _guard = 'tool/l2a/ci/egress_guard.sh';

YamlMap _workflow() => loadYaml(File(_workflowPath).readAsStringSync()) as YamlMap;

YamlMap _jobs() => _workflow()['jobs'] as YamlMap;

/// The `on:` section; YAML 1.1 reads a bare `on` key as true.
YamlMap _triggers() => (_workflow()['on'] ?? _workflow()[true]) as YamlMap;

List<YamlMap> _steps(String job) => [
  for (final step in (_jobs()[job] as YamlMap)['steps'] as YamlList) step as YamlMap,
];

/// The jobs whose steps run [script].
List<String> _jobsRunning(String script) => [
  for (final MapEntry(:key, :value) in _jobs().entries)
    if ('${(value as YamlMap)['steps']}'.contains(script)) key as String,
];

/// The paths of the change filter that decides whether the devices run.
Set<Object?> _nativeFilter() {
  final filter = (_steps('changes').singleWhere((s) => s['id'] == 'filter')['with'] as YamlMap)['filters'];
  return ((loadYaml(filter as String) as YamlMap)['native'] as YamlList).toSet();
}

/// Whether the change filter [paths] covers [path]: one of them names it or ends with `/**` under a folder above it.
bool _filterCovers(Set<Object?> paths, String path) => paths.any((p) {
  final pattern = '$p';
  return pattern == path || (pattern.endsWith('/**') && path.startsWith(pattern.substring(0, pattern.length - 2)));
});

/// The lines of a shell script without comments.
List<String> _codeLines(String path) => [
  for (final line in File(path).readAsLinesSync())
    if (!line.trimLeft().startsWith('#')) line,
];

/// The paths an `actions/cache` [step] of [job] keeps, one per line, with each `${{ env.NAME }}` replaced by the value
/// the job or the workflow gives it.
List<String> _cachePaths(String job, YamlMap step) {
  final env = {...?_workflow()['env'] as YamlMap?, ...?(_jobs()[job] as YamlMap)['env'] as YamlMap?};
  final paths = (step['with'] as YamlMap)['path'] as String;
  return [
    for (final line in paths.split('\n'))
      if (line.trim().isNotEmpty)
        line.trim().replaceAllMapped(RegExp(r'\$\{\{\s*env\.(\w+)\s*\}\}'), (m) => '${env[m[1]] ?? m[0]}'),
  ];
}

/// The files the `hashFiles(...)` calls of a cache [key] hash, read as their list of quoted arguments; null when an
/// argument is anything but one quoted path.
List<String>? _hashedFiles(String key) {
  final files = <String>[];
  for (final call in RegExp(r'hashFiles\(([^)]*)\)').allMatches(key)) {
    for (final argument in call[1]!.split(',')) {
      final path = RegExp(r"^\s*'([^']*)'\s*$").firstMatch(argument)?.group(1);
      if (path == null) return null;
      files.add(path);
    }
  }
  return files;
}

/// Whether the cache [path] has a `.` or `..` segment, which actions/cache rejects when it saves; a leading `~` is
/// the home folder.
bool _hasDotSegment(String path) => path.split('/').any((segment) => segment == '.' || segment == '..');

/// The folder `ios.sh` builds in on CI when `L2A_DERIVED_DATA` is not set, with `~` for the home folder.
String _ciDerivedData() {
  final lines = _codeLines(_iosScript);
  final folders = [
    for (final (index, line) in lines.indexed.skip(1))
      if (lines[index - 1].trim() == r'if [ "$L2A_MODE" = ci ]; then')
        if (RegExp(r'^\s*derived_data=\$\{L2A_DERIVED_DATA:-\$HOME/([^}]+)\}$').firstMatch(line) case final m?) m[1],
  ];
  expect(folders, hasLength(1));
  return '~/${folders.single}';
}

/// The names of the probe steps [lines] record with `l2a_step`, a name with `$test` once for each of [tests].
List<String> _probeSteps(Iterable<String> lines, List<String> tests) => [
  for (final line in lines)
    if (RegExp(r'l2a_step "?([\w$-]+)"? probe ').firstMatch(line)?.group(1) case final name?)
      ...(name.contains(r'$test') ? [for (final test in tests) name.replaceAll(r'$test', test)] : [name]),
];

/// The platform a run script records, from its `l2a_init` call.
String _platformOf(List<String> lines) {
  final platforms = [
    for (final line in lines)
      if (RegExp(r'^l2a_init (\w+) ').firstMatch(line) case final m?) m[1]!,
  ];
  expect(platforms, hasLength(1));
  return platforms.single;
}

/// Runs [script] with bash, with [env], and returns its result.
Future<ProcessResult> _bash(String script, {Map<String, String> env = const {}}) =>
    Process.run('bash', ['-c', script], environment: env);

void main() {
  group('workflow', () {
    test('pull requests into the main branches run it whatever files they change', () {
      final pullRequest = _triggers()['pull_request'] as YamlMap;
      expect(pullRequest.keys, isNot(anyOf(contains('paths'), contains('paths-ignore'))));
      expect(pullRequest['branches'], containsAll(['dev', 'master', 'release/**', 'hotfix/**']));
    });

    test('a schedule runs it on dev through a job allowed to start workflows', () {
      expect(_triggers()['schedule'], [
        {'cron': '0 2 * * *'},
      ]);
      final dispatch = _jobs()['dispatch-dev'] as YamlMap;
      expect(dispatch['if'], contains("github.event_name == 'schedule'"));
      expect(dispatch['permissions'], {'actions': 'write'});
      expect('${dispatch['steps']}', contains('gh workflow run l2a.yml --ref dev -f nightly=true'));
    });

    test('the gate needs every other job and runs whatever they ended with', () {
      final gate = _jobs()['l2a-gate'] as YamlMap;
      expect((gate['needs'] as YamlList).toSet(), {..._jobs().keys}..remove('l2a-gate'));
      expect(gate['if'], 'always()');
    });

    group('the gate', () {
      Future<int> gate(String changes, List<String> results) async {
        final step = _steps('l2a-gate').single;
        final env = step['env'] as YamlMap;
        expect(env['CHANGES'], r'${{ needs.changes.result }}');
        expect(env['RESULTS'], r"${{ join(needs.*.result, ' ') }}");
        final result = await _bash(step['run'] as String, env: {'CHANGES': changes, 'RESULTS': results.join(' ')});
        return result.exitCode;
      }

      test('is green when the changes were filtered and every job passed or was skipped', () async {
        expect(await gate('success', ['success', 'success', 'skipped', 'skipped']), 0);
        expect(await gate('success', ['success', 'skipped', 'skipped', 'skipped']), 0);
      });

      test('is red when the change filter did not succeed, even if every job was skipped', () async {
        expect(await gate('skipped', ['skipped', 'skipped', 'skipped', 'skipped']), isNot(0));
        expect(await gate('failure', ['failure', 'skipped', 'skipped', 'skipped']), isNot(0));
      });

      test('is red when a job failed or was cancelled', () async {
        expect(await gate('success', ['success', 'failure', 'skipped', 'skipped']), isNot(0));
        expect(await gate('success', ['success', 'cancelled', 'success', 'skipped']), isNot(0));
      });
    });

    test('the Flutter version comes from .fvmrc, never from a literal', () {
      expect(
        File(_workflowPath).readAsStringSync(),
        isNot(matches(RegExp(r'flutter.*\d+\.\d+\.\d+', caseSensitive: false))),
      );
      var found = 0;
      for (final MapEntry(key: job, value: _) in _jobs().entries) {
        final steps = _steps(job as String);
        for (final step in steps) {
          if ('${step['uses']}'.startsWith('subosito/flutter-action')) {
            found++;
            final version = (step['with'] as YamlMap)['flutter-version'] as String;
            final id = RegExp(r'^\$\{\{ steps\.([\w-]+)\.outputs\.flutter \}\}$').firstMatch(version)?.group(1);
            expect(id, isNotNull, reason: '$job: flutter-version is $version');
            final source = steps.firstWhere((s) => s['id'] == id);
            expect(source['run'], contains('jq -r .flutter .fvmrc'), reason: '$job: step $id');
          }
        }
      }
      expect(found, greaterThanOrEqualTo(_jobsRunning('tool/l2a/ci/').length));
    });

    test('each Android job keeps the logs of a run that failed or ran a test again', () async {
      final jobs = _jobsRunning(_androidScript);
      expect(jobs, hasLength(2));
      for (final job in jobs) {
        final steps = _steps(job);
        final upload = steps.singleWhere((s) => '${s['uses']}'.startsWith('actions/upload-artifact'));
        final folder = (upload['with'] as YamlMap)['path'] as String;
        expect(upload['if'], "failure() || steps.retried.outputs.retried == 'true'", reason: job);
        final retried = steps.singleWhere((s) => s['id'] == 'retried');
        expect(retried['if'], 'always()', reason: job);
        expect(steps.indexOf(retried), lessThan(steps.indexOf(upload)), reason: job);
        // The step, run where the job runs it, against the info.tsv of a run.
        Future<String> output(String? info) async {
          final dir = Directory.systemTemp.createTempSync('l2a_retried_');
          addTearDown(() => dir.deleteSync(recursive: true));
          if (info != null) {
            Directory('${dir.path}/$folder').createSync(recursive: true);
            File('${dir.path}/$folder/info.tsv').writeAsStringSync(info);
          }
          final out = File('${dir.path}/github_output')..writeAsStringSync('');
          final result = await Process.run(
            'bash',
            ['-e', '-c', retried['run'] as String],
            workingDirectory: dir.path,
            environment: {'GITHUB_OUTPUT': out.path},
          );
          expect(result.exitCode, 0, reason: '$job: ${result.stderr}');
          return out.readAsStringSync();
        }

        expect(await output('platform\tandroid\nretried\tviews (adb: device offline)\n'), 'retried=true\n');
        expect(await output('platform\tandroid\nmode\tci\n'), '');
        expect(await output(null), '');
      }
    });

    test('the iOS job selects an explicit Xcode version', () {
      final job = _jobsRunning(_iosScript).single;
      final xcode = _steps(job).where((s) => '${s['uses']}'.startsWith('maxim-lobanov/setup-xcode')).single;
      expect('${(xcode['with'] as YamlMap)['xcode-version']}', matches(RegExp(r'^\d+\.\d+(\.\d+)?$')));
    });

    test('the plain FlutterActivity runs only at night', () {
      final jobs = [
        for (final job in _jobsRunning(_androidScript))
          if ('${(_jobs()[job] as YamlMap)['steps']}'.contains('--flutter-activity')) job,
      ];
      expect(jobs, hasLength(1));
      expect((_jobs()[jobs.single] as YamlMap)['if'], contains('inputs.nightly'));
      expect(((_triggers()['workflow_dispatch'] as YamlMap)['inputs'] as YamlMap).keys, contains('nightly'));
    });

    test('the expectations name the iOS SDK, the iOS runtime and the Xcode they were recorded on', () {
      final expectations = loadYaml(File('integration_test_app/l2a_expectations.yaml').readAsStringSync()) as YamlMap;
      final probed = expectations['probed'] as YamlMap;
      expect('${probed['ios_sha']}', matches(RegExp(r'^[0-9a-f]{40}$')));
      expect('${probed['ios_runtime']}', matches(RegExp(r'^\d+\.\d+$')));
      expect('${probed['xcode']}', matches(RegExp(r'^\d+\.\d+(\.\d+)?$')));
      expect('${probed['android']}', matches(RegExp(r'^\d+\.\d+\.\d+$')));
    });

    test('the change filter covers every input of the native probe', () {
      expect(_nativeFilter(), {
        'ios/**',
        'android/**',
        'contract/**',
        'integration_test_app/**',
        'tool/l2a/**',
        'tool/contract/**',
        'lib/src/models/**',
        'lib/src/platform_views/**',
        'lib/src/runtime/adapty_native_transport.dart',
        'lib/src/constants/method.dart',
        'lib/src/adaptyui_events_proxy.dart',
        'pubspec.yaml',
        '.fvmrc',
        '.github/workflows/l2a.yml',
      });
    });

    test('the change filter covers every file of the plugin that the integration test app imports', () {
      final listed = Process.runSync('git', ['ls-files', 'integration_test_app']);
      if (listed.exitCode != 0) fail('git ls-files integration_test_app failed: ${listed.stderr}');
      final files = [
        for (final path in '${listed.stdout}'.split('\n'))
          if (path.endsWith('.dart')) path,
      ];
      if (files.isEmpty) fail('git ls-files integration_test_app lists no Dart file');
      final filter = _nativeFilter();
      final uncovered = [
        for (final file in files)
          if (File(file).existsSync())
            for (final match in RegExp(
              r'''^(?:import|export)\s+['"]package:adapty_flutter/(src/[^'"]+)['"]''',
              multiLine: true,
            ).allMatches(File(file).readAsStringSync()))
              if (!_filterCovers(filter, 'lib/${match[1]}')) '$file: lib/${match[1]}',
      ];
      expect(uncovered, isEmpty);
    });

    test('a path is covered by the change filter when it names the path or a folder above it', () {
      const filter = {'lib/src/models/**', 'lib/src/constants/method.dart'};
      expect(_filterCovers(filter, 'lib/src/constants/method.dart'), isTrue);
      expect(_filterCovers(filter, 'lib/src/models/a/b.dart'), isTrue);
      expect(_filterCovers(filter, 'lib/src/constants/method.dart.bak'), isFalse);
      expect(_filterCovers(filter, 'lib/src/models_extra.dart'), isFalse);
      expect(_filterCovers(filter, 'lib/src/adaptyui_events_proxy.dart'), isFalse);
    });

    test('checkouts keep no credentials and third-party actions are fixed to a commit', () {
      for (final MapEntry(key: job, value: _) in _jobs().entries) {
        for (final step in _steps(job as String)) {
          if ('${step['uses']}'.startsWith('actions/checkout@')) {
            expect((step['with'] as YamlMap?)?['persist-credentials'], false, reason: '$job: ${step['uses']}');
          }
        }
      }
      final thirdParty = thirdPartyUses(File(_workflowPath).readAsLinesSync());
      expect(thirdParty, isNotEmpty);
      for (final line in thirdParty) {
        expect(line, matches(fixedToCommit));
      }
    });

    test(
      'no cache path has a . or .. segment, which actions/cache rejects when it saves, so nothing would be kept',
      () {
        final caches = [
          for (final MapEntry(key: job, value: _) in _jobs().entries)
            for (final step in _steps(job as String))
              if ('${step['uses']}'.startsWith('actions/cache@')) (job, step),
        ];
        expect(caches, isNotEmpty);
        for (final (job, step) in caches) {
          for (final path in _cachePaths(job, step)) {
            expect(_hasDotSegment(path), isFalse, reason: '$job: $path');
          }
        }
      },
    );

    test('a cache path with a . or .. segment anywhere is told apart from one in the home folder', () {
      for (final path in ['../gradle-caches', './caches', '~/a/../b', '/runner/work/r/r/../derived-data', '~/./a']) {
        expect(_hasDotSegment(path), isTrue, reason: path);
      }
      for (final path in ['~/.gradle/caches', '~/.android/avd/*', '~/l2a-derived-data/SourcePackages', 'build/..a']) {
        expect(_hasDotSegment(path), isFalse, reason: path);
      }
    });

    test('the iOS job caches the Swift packages of the folder ios.sh builds in on CI', () {
      final job = _jobsRunning(_iosScript).single;
      final cache = _steps(job).singleWhere((s) => '${s['uses']}'.startsWith('actions/cache@'));
      final env = (_jobs()[job] as YamlMap)['env'] as YamlMap?;
      final folder = env?['L2A_DERIVED_DATA'] as String? ?? _ciDerivedData();
      expect(_cachePaths(job, cache), ['$folder/SourcePackages']);
    });

    test('the Gradle cache of each Android job is keyed on the build files, the wrapper, the plugin and Flutter', () {
      final jobs = _jobsRunning(_androidScript);
      expect(jobs, hasLength(2));
      for (final job in jobs) {
        final caches = [
          for (final step in _steps(job))
            if ('${step['uses']}'.startsWith('actions/cache@') && _cachePaths(job, step).contains('~/.gradle/caches'))
              step,
        ];
        expect(caches, isNotEmpty, reason: '$job: no cache keeps ~/.gradle/caches');
        for (final cache in caches) {
          final key = '${(cache['with'] as YamlMap)['key']}';
          final files = _hashedFiles(key);
          expect(files, isNotNull, reason: '$job: the Gradle cache key hashes something other than quoted paths: $key');
          for (final file in [
            'integration_test_app/android/**/*.gradle.kts',
            'integration_test_app/android/gradle/wrapper/gradle-wrapper.properties',
            'android/build.gradle',
            '.fvmrc',
          ]) {
            expect(files, contains(file), reason: '$job: the Gradle cache key does not hash $file');
          }
        }
      }
    });

    test('the files of a cache key are the quoted arguments of hashFiles, not text that contains them', () {
      expect(_hashedFiles("k-\${{ hashFiles('a/b.kts', '.fvmrc') }}"), ['a/b.kts', '.fvmrc']);
      expect(_hashedFiles("k-\${{ hashFiles('a') }}-\${{ hashFiles( 'b' ) }}"), ['a', 'b']);
      expect(_hashedFiles("k-\${{ hashFiles('a/.fvmrc.bak') }}"), isNot(contains('.fvmrc')));
      expect(_hashedFiles('k-.fvmrc'), isEmpty);
      expect(_hashedFiles("k-\${{ hashFiles('a', env.B) }}"), isNull);
    });
  });

  group('ios.sh', () {
    test('builds the app with xcodebuild only for lib/main.dart, as flutter test leaves another target behind', () {
      final calls = _codeLines(_iosScript).where((line) => RegExp(r'(^|\s)xcodebuild\s').hasMatch(line)).toList();
      expect(calls, isNotEmpty);
      for (final call in calls) {
        expect(call, contains('FLUTTER_TARGET=lib/main.dart'));
      }
    });

    test('shuts down or deletes its simulator on any exit', () {
      expect(_codeLines(_iosScript), contains('trap ios_cleanup EXIT'));
    });

    test('reads the loss events of the unified log in the window of each test', () {
      expect(_codeLines(_iosScript).join('\n'), contains(r'log show --loss --start "$2" --predicate "$predicate"'));
    });

    test('reads the log of the wrapper and of the app process, so that a log that missed the test shows', () {
      expect(
        _codeLines(_iosScript).join('\n'),
        contains(
          """local predicate='subsystem == "io.adapty.flutter" OR process == "Runner" OR eventType == lossEvent'""",
        ),
      );
    });

    test('checks the native log of the probe against the cases the iOS bundle expects to be refused', () {
      final lines = _codeLines(_iosScript).join('\n');
      expect(lines, contains(r'params_cases=$(l2a_params_cases ios "$L2A_OUT/bundle.log")'));
      expect(lines, contains(r'"$probe_log" --plugin-refusals "$params_cases"'));
    });

    test('runs the probe and the views once each and checks the native log of each', () {
      final lines = _codeLines(_iosScript).join('\n');
      expect(lines, contains('for test in probe views; do'));
      expect(lines, contains(r'l2a_step "$test" probe 1 '));
      expect(lines, contains('l2a_step probe-native-log probe 1'));
      expect(lines, contains('l2a_step views-native-log probe 1'));
    });

    test('checks the native log of the views against the onboarding views of the iOS bundle', () {
      final checks = _codeLines(_iosScript).where((line) => line.contains('native_log_check.dart')).toList();
      expect(checks.where((line) => line.contains(r'--onboarding-views "$onboarding_views"')), hasLength(1));
      expect(
        _codeLines(_iosScript).where((line) => line.contains(r'onboarding_views=$(l2a_onboarding_views ios ')),
        hasLength(1),
      );
    });
  });

  group('common.sh', () {
    Future<ProcessResult> common(String script, {Map<String, String> env = const {}}) =>
        _bash('. $_common; $script', env: env);

    test('reads the onboarding views of a platform from the output of the bundle', () async {
      final dir = Directory.systemTemp.createTempSync('l2a_bundle_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final out = File('${dir.path}/bundle.log')
        ..writeAsStringSync(
          'wrote integration_test_app/integration_test/support/l2a_cases.g.dart (strict): ios 1043, android 1001 cases\n'
          'onboarding views: ios 3, android 2\n',
        );
      expect((await common('l2a_onboarding_views ios ${out.path}')).stdout, '3\n');
      expect((await common('l2a_onboarding_views android ${out.path}')).stdout, '2\n');
      out.writeAsStringSync('wrote it (strict): ios 1043, android 1001 cases\n');
      expect((await common('l2a_onboarding_views ios ${out.path}')).exitCode, isNot(0));
    });

    group('a run', () {
      /// Exits like `l2a_finish` after one step that runs [step], with a summary that exits with [summary].
      Future<int> run(String step, int summary) async {
        final dir = Directory.systemTemp.createTempSync('l2a_run_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final dart = File('${dir.path}/dart')..writeAsStringSync('#!/bin/bash\nexit $summary\n');
        Process.runSync('chmod', ['+x', dart.path]);
        return (await common(
          'l2a_init ios local ${dir.path}/out > /dev/null; l2a_step only probe 1 $step > /dev/null; l2a_finish',
          env: {'L2A_DART': dart.path},
        )).exitCode;
      }

      test('exits with 0 when every step passed and the summary is green', () async {
        expect(await run('true', 0), 0);
      });

      test('exits with 1 when a step failed, even if the summary is green', () async {
        expect(await run('false', 0), 1);
      });

      test('exits with 1 when the summary is red', () async {
        expect(await run('true', 1), 1);
      });
    });

    test('starts the output of each run of a step in its log the way the summary finds the last run', () async {
      final dir = Directory.systemTemp.createTempSync('l2a_run_');
      addTearDown(() => dir.deleteSync(recursive: true));
      await common('l2a_init ios local ${dir.path}/out > /dev/null; l2a_step probe probe 1 echo one > /dev/null');
      await common('l2a_init ios local ${dir.path}/out > /dev/null; l2a_step probe probe 1 echo two > /dev/null');
      final lines = File('${dir.path}/out/probe.log').readAsLinesSync();
      expect(lines.where((line) => line.startsWith(L2aRun.runHeader)), hasLength(2));
      expect(lines.first, startsWith(L2aRun.runHeader));
    });

    test('reads the cases of a platform the plugin refuses as bad params from the output of the bundle', () async {
      final dir = Directory.systemTemp.createTempSync('l2a_bundle_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final out = File('${dir.path}/bundle.log')
        ..writeAsStringSync('flow views: ios 3, android 3\nparams cases: ios 923, android 278\n');
      expect((await common('l2a_params_cases ios ${out.path}')).stdout, '923\n');
      expect((await common('l2a_params_cases android ${out.path}')).stdout, '278\n');
    });

    test('reads the flow views of a platform from the output of the bundle', () async {
      final dir = Directory.systemTemp.createTempSync('l2a_bundle_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final out = File('${dir.path}/bundle.log')
        ..writeAsStringSync('onboarding views: ios 2, android 2\nflow views: ios 3, android 4\n');
      expect((await common('l2a_flow_views android ${out.path}')).stdout, '4\n');
      expect((await common('l2a_flow_views ios ${out.path}')).stdout, '3\n');
    });

    test('takes the pids of the app from the lines the activity manager starts its processes with', () async {
      final dir = Directory.systemTemp.createTempSync('l2a_logcat_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final logcat = File('${dir.path}/logcat.log')
        ..writeAsStringSync(
          '11-20 15:26:30.001   612   640 I ActivityManager: Start proc 4212:com.adapty.flutter.adapty_l2a/u0a223 '
          'for next-top-activity {com.adapty.flutter.adapty_l2a/com.adapty.flutter.adapty_l2a.MainActivity}\n'
          '11-20 15:26:31.001   612   640 I ActivityManager: Start proc 4300:com.android.chrome/u0a120 for service\n'
          '11-20 15:27:30.001   612   640 I ActivityManager: Start proc 4401:com.adapty.flutter.adapty_l2a/u0a223 '
          'for next-top-activity\n',
        );
      expect((await common('l2a_app_pids com.adapty.flutter.adapty_l2a ${logcat.path}')).stdout, '4212\n4401\n');
    });

    test('a stopped guard passes only when it wrote PASS', () async {
      final dir = Directory.systemTemp.createTempSync('l2a_guard_result_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Future<int> stopAndCheck(String? result) async {
        final file = File('${dir.path}/egress.log');
        if (file.existsSync()) file.deleteSync();
        // A stand-in for the guard: on TERM it writes [result], if any, where the guard writes its result.
        final onTerm = result == null ? 'exit 0' : 'sleep 0.3; echo "$result" > ${file.path}; exit 0';
        return (await common(
          "(trap '$onTerm' TERM; while true; do sleep 0.1; done) >/dev/null 2>&1 & "
          'L2A_GUARD_PID=\$!; sleep 0.3; l2a_stop_guard; l2a_guard_passed ${file.path}',
        )).exitCode;
      }

      expect(await stopAndCheck('PASS uid=10247 rejected_ipv4_packets=0'), 0);
      expect(await stopAndCheck('FAIL uid=10247 rejected_ipv4_packets=2: 2 IPv4 packets rejected'), isNot(0));
      expect(await stopAndCheck(null), isNot(0));
    });

    group('a test that did not start on the device', () {
      late Directory dir;
      setUp(() => dir = Directory.systemTemp.createTempSync('l2a_start_lost_'));
      tearDown(() => dir.deleteSync(recursive: true));

      /// Runs `l2a_start_lost` on a test log of [runs] (each under the header the run script starts a run with), the
      /// guard result [guard] and the native log [native]; returns what it printed when it succeeded, null when it
      /// failed.
      Future<String?> startLost(
        List<String> runs, {
        String guard = _guardLostDevice,
        String native = _nativeStarted,
      }) async {
        final log = File('${dir.path}/views.log')
          ..writeAsStringSync([for (final run in runs) '$_runHeader\n$run\n'].join());
        final result = File('${dir.path}/views.egress.log')..writeAsStringSync('$guard\n');
        final nativeLog = File('${dir.path}/views.native.log')..writeAsStringSync(native);
        final run = await common('l2a_start_lost ${log.path} ${result.path} ${nativeLog.path}');
        return run.exitCode == 0 ? '${run.stdout}' : null;
      }

      test('when adb lost the device while flutter started the Dart Development Service of the app', () async {
        expect(await startLost([_ddsLost]), 'Failed to start Dart Development Service\n');
      });

      test('when adb lost the device while flutter installed the app or waited for it to start', () async {
        expect(await startLost([_offlineAtInstall]), 'adb: device offline\n');
        expect(await startLost([_logReaderStopped]), 'Error waiting for a debug connection\n');
      });

      test('when flutter could not find the device', () async {
        expect(await startLost([_noDevice]), 'No supported devices found\n');
      });

      test('when adb waited for the device', () async {
        expect(
          await startLost(['$_compileError\n- waiting for device -'.replaceAll(': Compilation failed', ':')]),
          'waiting for device\n',
        );
      });

      test('not when the app crashed at its start, which flutter reports the same way', () async {
        for (final crash in [
          '11-26 11:40:48.100  9097  9097 E AndroidRuntime: FATAL EXCEPTION: main',
          '11-26 11:40:48.100  9097  9097 F libc    : Fatal signal 11 (SIGSEGV), code 1 (SEGV_MAPERR)',
          '11-26 11:40:58.100  9097  9120 E ActivityManager: ANR in com.adapty.flutter.adapty_l2a',
        ]) {
          expect(await startLost([_logReaderStopped], native: '$_nativeStarted$crash\n'), isNull, reason: crash);
        }
        expect(await startLost([_logReaderStopped], native: ''), 'Error waiting for a debug connection\n');
      });

      test('not when the app sent a packet off the device, which no second run may hide', () async {
        expect(await startLost([_ddsLost], guard: _guardRejected), isNull);
        expect(await startLost([_ddsLost], guard: _guardRejected.replaceAll('IPv4', 'IPv6')), isNull);
      });

      test('not when a test of the file ran, whatever adb printed', () async {
        expect(await startLost([_testFailedThenOffline]), isNull);
        expect(await startLost(['$_ddsLost\nL2A_VIEW {"id":"flow_platform_view/default"}']), isNull);
        expect(await startLost(['$_ddsLost\n::group::✅ the probe answers']), isNull);
        expect(await startLost(['$_offlineAtInstall\n00:31 +1: views answer']), isNull);
      });

      test('not when the file failed to load for another reason, such as a compile error', () async {
        expect(await startLost([_compileError]), isNull);
      });

      test('not when only an earlier run of the test in the same log did not start', () async {
        expect(await startLost([_ddsLost, _testFailedThenOffline.replaceAll('adb: device offline', '')]), isNull);
        expect(await startLost([_testFailedThenOffline, _ddsLost]), 'Failed to start Dart Development Service\n');
      });
    });

    group('closing the guard of a run during which adb lost the device', () {
      late Directory dir;
      setUp(() {
        dir = Directory.systemTemp.createTempSync('l2a_close_guard_');
        File('${dir.path}/adb').writeAsStringSync(_fakeAdb);
        Process.runSync('chmod', ['+x', '${dir.path}/adb']);
        // The rules a guard put in place and could not read or remove while the device was away.
        File('${dir.path}/rules').writeAsStringSync('v4\nv6\n');
      });

      tearDown(() => dir.deleteSync(recursive: true));

      late File result;

      Future<ProcessResult> close(String guard, {Map<String, String> fake = const {}}) {
        result = File('${dir.path}/views.egress.first.log')..writeAsStringSync('$guard\n');
        return _bash(
          '. $_common; l2a_close_first_guard emulator-5580 com.adapty.flutter.adapty_l2a ${result.path}',
          env: {'ADB': '${dir.path}/adb', 'FAKE_DIR': dir.path, ...fake},
        );
      }

      List<String> calls() => File('${dir.path}/calls').readAsLinesSync();

      const lost =
          'FAIL uid=10247 rejected_ipv4_packets=? rejected_ipv6_packets=? uid_rules_left=0: '
          'a counter could not be read';

      test('uninstalls the app first, then reads the counters of its rules and removes them', () async {
        final run = await close(lost);
        expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
        expect(calls().first, '-s emulator-5580 uninstall com.adapty.flutter.adapty_l2a');
        final read = calls().indexWhere((c) => c.contains('iptables -w -L OUTPUT'));
        final removed = calls().indexWhere((c) => c.contains(' -D OUTPUT'));
        expect(read, greaterThan(0));
        expect(removed, greaterThan(read));
        for (final table in ['iptables', 'ip6tables']) {
          expect(
            calls(),
            contains('-s emulator-5580 shell $table -w -D OUTPUT -m owner --uid-owner 10247 ! -o lo -j REJECT'),
          );
        }
        expect(File('${dir.path}/rules').readAsStringSync().trim(), isEmpty);
        expect(result.readAsLinesSync(), [
          lost,
          'RECOVERED uid=10247 rejected_ipv4_packets=0 rejected_ipv6_packets=0 uid_rules_left=0',
        ]);
      });

      test('fails when the app sent a packet off the device, and still removes the rules', () async {
        final run = await close(lost, fake: {'FAKE_V4_PACKETS': '3'});
        expect(run.exitCode, isNot(0));
        expect(
          result.readAsLinesSync().last,
          allOf(startsWith('RECOVERED uid=10247 rejected_ipv4_packets=3 '), endsWith(': 3 IPv4 packets rejected')),
        );
        expect(File('${dir.path}/rules').readAsStringSync().trim(), isEmpty);
      });

      test('fails when a counter still cannot be read once the device is back', () async {
        File('${dir.path}/rules').writeAsStringSync('v4\n');
        final run = await close(lost);
        expect(run.exitCode, isNot(0));
        expect(result.readAsLinesSync().last, endsWith(': a counter could not be read'));
      });

      test('fails when a rule cannot be removed, so that the next guard does not count it', () async {
        final run = await close(lost, fake: {'FAKE_STUCK_RULES': '1'});
        expect(run.exitCode, isNot(0));
        expect(result.readAsLinesSync().last, contains('uid rules left'));
      });

      test('reads and removes nothing when the guard never learnt the uid of the app', () async {
        final run = await close('FAIL uid=unknown rejected_ipv4_packets=? rejected_ipv6_packets=? uid_rules_left=0');
        expect(run.exitCode, 0);
        expect(calls().where((c) => c.contains('tables')), isEmpty);
      });
    });
  });

  group('egress guard', () {
    late Directory dir;
    late File calls;
    late File result;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('l2a_egress_');
      calls = File('${dir.path}/calls');
      result = File('${dir.path}/egress.log');
      File('${dir.path}/adb').writeAsStringSync(_fakeAdb);
      Process.runSync('chmod', ['+x', '${dir.path}/adb']);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    /// Runs the guard against the fake adb until it reports that it has tried to insert its rules (`<result>.armed`),
    /// or, when the app is never installed ([installed] false), until it has looked for the app three times; then
    /// stops it with TERM and returns what it wrote. The wait follows the guard and the calls of the fake adb, not
    /// the clock, and gives up after ten seconds.
    Future<String> guard({Map<String, String> fake = const {}, bool installed = true}) async {
      final process = await Process.start(
        'bash',
        [_guard, 'emulator-5580', 'com.adapty.flutter.adapty_l2a', result.path],
        environment: {'ADB': '${dir.path}/adb', 'FAKE_DIR': dir.path, ...fake},
      );
      bool ready() {
        if (installed) return File('${result.path}.armed').existsSync();
        return calls.existsSync() &&
            calls.readAsLinesSync().where((line) => line.contains('packages.list')).length >= 3;
      }

      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (!ready()) {
        if (DateTime.now().isAfter(deadline)) {
          process.kill(ProcessSignal.sigkill);
          fail('the guard did not get to ${installed ? 'its rules' : 'a third look for the app'} in 10 s');
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      process.kill(ProcessSignal.sigterm);
      await process.exitCode.timeout(const Duration(seconds: 10));
      return result.existsSync() ? result.readAsStringSync() : '';
    }

    int inserts(String table) => calls.readAsLinesSync().where((line) => line.contains('$table -w -I OUTPUT')).length;

    test('passes when the app sent nothing off the device, and removes its rules', () async {
      expect(
        await guard(),
        startsWith('PASS uid=10247 rejected_ipv4_packets=0 rejected_ipv6_packets=0 uid_rules_left=0'),
      );
      expect((inserts('iptables'), inserts('ip6tables')), (1, 1));
    });

    test('passes when every call of adb is slow, as on a loaded machine', () async {
      expect(await guard(fake: {'FAKE_CALL_DELAY': '0.3'}), startsWith('PASS uid=10247 rejected_ipv4_packets=0'));
    });

    test('fails when the app was never installed while it ran', () async {
      expect(await guard(fake: {'FAKE_INSTALL_AFTER': 'never'}, installed: false), contains('never installed'));
    });

    test('fails when a packet was rejected', () async {
      expect(await guard(fake: {'FAKE_V4_PACKETS': '3'}), allOf(startsWith('FAIL'), contains('3 IPv4 packets')));
    });

    test('waits for the lock of the firewall on every call of iptables', () async {
      await guard();
      final tables = calls.readAsLinesSync().where((line) => RegExp(r'\bip6?tables ').hasMatch(line)).toList();
      expect(tables, isNotEmpty);
      for (final line in tables) {
        expect(line, matches(RegExp(r'\bip6?tables -w ')));
      }
    });

    test('fails when the IPv4 rule cannot be inserted', () async {
      expect(
        await guard(fake: {'FAKE_FAIL_V4_INSERT': '1'}),
        allOf(startsWith('FAIL uid=10247'), contains('the IPv4 rule could not be inserted')),
      );
    });

    test('fails once, without inserting the IPv4 rule again, when the IPv6 rule cannot be inserted', () async {
      final written = await guard(fake: {'FAKE_FAIL_V6_INSERT': '1'});
      expect(written, contains('the IPv6 rule could not be inserted'));
      expect(written, startsWith('FAIL uid=10247'));
      expect(inserts('iptables'), 1);
      expect(written, contains('uid_rules_left=0'));
    });

    test('waits for the outcome of a slow insert of the IPv6 rule before it is stopped', () async {
      final written = await guard(fake: {'FAKE_FAIL_V6_INSERT': '1', 'FAKE_V6_INSERT_SECONDS': '0.3'});
      expect(written, allOf(startsWith('FAIL uid=10247'), contains('the IPv6 rule could not be inserted')));
    });

    test('fails when its rules cannot be removed', () async {
      expect(await guard(fake: {'FAKE_STUCK_RULES': '1'}), allOf(startsWith('FAIL'), contains('uid rules left')));
    });

    test('is started only once it has uninstalled the app, so that the uninstall never races the install', () async {
      final script = await _bash(
        '. $_common; l2a_start_guard emulator-5580 com.adapty.flutter.adapty_l2a ${result.path}; '
        'l2a_guard_ready ${result.path} && grep -c uninstalled ${dir.path}/calls; l2a_stop_guard',
        env: {'ADB': '${dir.path}/adb', 'FAKE_DIR': dir.path, 'FAKE_UNINSTALL_SECONDS': '1'},
      );
      expect(script.stdout, '1\n');
    });

    test('that is not ready in time fails an infra step of the run', () async {
      final script = await _bash(
        '. $_common; l2a_init android local ${dir.path}/out > /dev/null; '
        'l2a_start_guard emulator-5580 com.adapty.flutter.adapty_l2a ${result.path}; '
        'l2a_step probe-guard-ready infra 1 l2a_guard_ready ${result.path} > /dev/null; echo rc=\$?; '
        'l2a_stop_guard; cat ${dir.path}/out/steps.tsv',
        env: {
          'ADB': '${dir.path}/adb',
          'FAKE_DIR': dir.path,
          'FAKE_UNINSTALL_SECONDS': '3',
          'L2A_GUARD_READY_SECONDS': '1',
        },
      );
      expect(
        script.stdout,
        allOf(contains('rc=1'), matches(RegExp(r'^probe-guard-ready\tinfra\t1\t', multiLine: true))),
      );
    });

    group('setting up the device', () {
      Future<ProcessResult> setUpDevice(Map<String, String> fake) => _bash(
        '. $_common; l2a_set_up_device emulator-5580 "" 3',
        env: {
          'ADB': '${dir.path}/adb',
          'FAKE_DIR': dir.path,
          'L2A_STABLE_SECONDS': '1',
          'L2A_SET_UP_PAUSE': '0',
          ...fake,
        },
      );
      int roots() => int.parse(File('${dir.path}/roots').readAsStringSync().trim());

      test('tries root again when the emulator restarts adb under it, and logs each attempt', () async {
        final result = await setUpDevice({'FAKE_ROOT_FAILS_TIMES': '2'});
        expect(result.exitCode, 0);
        expect(roots(), 3);
        expect(RegExp('device setup attempt').allMatches('${result.stdout}').length, 3);
      });

      test('gives up after three attempts', () async {
        final result = await setUpDevice({'FAKE_ROOT_FAILS_TIMES': '9'});
        expect(result.exitCode, isNot(0));
        expect(roots(), 3);
      });

      test('gives up at once when the emulator process is gone', () async {
        final result = await _bash(
          '. $_common; l2a_set_up_device emulator-5580 999999 3',
          env: {'ADB': '${dir.path}/adb', 'FAKE_DIR': dir.path, 'L2A_STABLE_SECONDS': '1', 'L2A_SET_UP_PAUSE': '0'},
        );
        expect(result.exitCode, isNot(0));
        expect(File('${dir.path}/roots').existsSync(), isFalse);
      });
    });

    test('is stopped by the trap of the script that started it, and still writes its result', () async {
      final script = await _bash(
        '. $_common; trap l2a_cleanup EXIT; '
        'l2a_start_guard emulator-5580 com.adapty.flutter.adapty_l2a ${result.path}; '
        'for _ in \$(seq 200); do [ -f ${result.path}.armed ] && break; sleep 0.05; done; '
        'exit 3',
        env: {'ADB': '${dir.path}/adb', 'FAKE_DIR': dir.path},
      );
      expect(script.exitCode, 3);
      expect(result.readAsStringSync(), startsWith('PASS uid=10247'));
    });
  });

  test('stopping an emulator the script started waits until its process is gone', () async {
    final result = await _bash(
      '. $_common; ADB=true; sleep 1.5 & L2A_STARTED_EMULATOR=emulator-5580; L2A_EMULATOR_PID=\$!; '
      'l2a_cleanup; kill -0 \$L2A_EMULATOR_PID 2>/dev/null && echo running || echo gone',
    );
    expect(result.stdout, 'gone\n');
  });

  test('android.sh runs each test under the guard and decides on its result and on the native log', () {
    final lines = _codeLines(_androidScript);
    final start = lines.indexWhere((l) => l == 'run_test() {');
    final end = lines.indexWhere((l) => l == '}', start);
    expect(start, greaterThanOrEqualTo(0));
    final body = lines.sublist(start, end).join('\n');
    final order = [
      'l2a_start_guard "\$serial" "\$package" "\$L2A_OUT/\$test.egress.log"',
      'l2a_step "\$test-guard-ready" infra 1 l2a_guard_ready "\$L2A_OUT/\$test.egress.log" || l2a_finish',
      'l2a_step "\$test" probe 1 ',
      'l2a_stop_guard',
      'l2a_step "\$test-egress" probe 1 l2a_guard_passed "\$L2A_OUT/\$test.egress.log"',
      'l2a_step "\$test-native-log" probe 1 ',
    ];
    var at = 0;
    for (final part in order) {
      final found = body.indexOf(part, at);
      expect(found, greaterThanOrEqualTo(0), reason: 'missing or out of order: $part');
      at = found + part.length;
    }
  });

  test('android.sh checks the native log of the views against the flow views of the Android bundle', () {
    final lines = _codeLines(_androidScript).join('\n');
    expect(lines, contains(r'flow_views=$(l2a_flow_views android "$L2A_OUT/bundle.log")'));
    expect(lines, contains(r'[ "$test" = views ] && counts=(--flow-views "$flow_views")'));
    expect(lines, contains(r'native_log_check.dart android "$L2A_OUT/$test.native.log" \'));
    expect(lines, contains(r'"${counts[@]}"'));
  });

  test('android.sh sets up the device with three attempts only locally', () {
    final lines = _codeLines(_androidScript).join('\n');
    expect(lines, contains(r'l2a_set_up_device "$serial" "$pid" "$setup_attempts"'));
    expect(lines, contains(r'setup_attempts=1'));
    expect(lines, contains(r'[ "$L2A_MODE" = local ] && setup_attempts=3'));
  });

  test('the summary requires of an iOS run the steps ios.sh records once it gets to the tests', () {
    final lines = _codeLines(_iosScript);
    final loop = lines.indexWhere((l) => l.startsWith('for test in '));
    expect(loop, greaterThanOrEqualTo(0));
    final tests = RegExp(r'^for test in (.+); do$').firstMatch(lines[loop])![1]!.split(' ');
    final steps = _probeSteps(lines.skip(loop), tests);
    expect(steps, isNotEmpty);
    expect(L2aRun.requiredSteps({'platform': _platformOf(lines)}), unorderedEquals(steps));
  });

  test('the summary requires of an Android run the steps android.sh records for the tests of its activity', () {
    final lines = _codeLines(_androidScript);
    // The variant: fragment by default, another one with a flag, recorded with a suffix.
    final byDefault = [
      for (final line in lines)
        if (RegExp(r'^variant=([\w-]+)$').firstMatch(line) case final m?) m[1]!,
    ];
    final byFlag = [
      for (final line in lines)
        if (RegExp(r'then variant=([\w-]+);').firstMatch(line) case final m?) m[1]!,
    ];
    final recorded = [
      for (final line in lines)
        if (RegExp(r'^l2a_info variant "\$variant(.*)"$').firstMatch(line) case final m?) m[1]!,
    ];
    expect(byDefault, hasLength(1));
    expect(byFlag, hasLength(1));
    expect(recorded, hasLength(1));
    // The tests: one list by default, another one for a variant.
    final defaultTests = [
      for (final line in lines)
        if (RegExp(r'^tests=\((.+)\)$').firstMatch(line) case final m?) m[1]!.split(' '),
    ];
    final variantTests = [
      for (final line in lines)
        if (RegExp(r'^\[ "\$variant" = ([\w-]+) \] && tests=\((.+)\)$').firstMatch(line) case final m?)
          (m[1]!, m[2]!.split(' ')),
    ];
    expect(defaultTests, hasLength(1));
    expect(variantTests, hasLength(1));
    expect([byDefault.single, byFlag.single], contains(variantTests.single.$1));
    final loop = lines.indexWhere((l) => l == 'run_test() {');
    expect(loop, greaterThanOrEqualTo(0));
    // The steps every run records: those of the block of a test (a test that runs again records more).
    final block = lines.sublist(loop, lines.indexWhere((l) => l == '}', loop));
    final platform = _platformOf(lines);
    for (final variant in [byDefault.single, byFlag.single]) {
      final tests = variant == variantTests.single.$1 ? variantTests.single.$2 : defaultTests.single;
      final steps = _probeSteps(block, tests);
      expect(steps, isNotEmpty);
      expect(
        L2aRun.requiredSteps({'platform': platform, 'variant': '$variant${recorded.single}'}),
        unorderedEquals(steps),
        reason: 'variant $variant',
      );
    }
  });

  test(
    'android.sh writes a FlutterActivity run under the repository root by default, wherever it is started',
    () async {
      final lines = _codeLines(_androidScript);
      expect(lines, contains(r'here=$(cd "$(dirname "$0")" && pwd)'));
      final assignments = [
        for (final line in lines)
          if (RegExp(r'default_out=(.+)$').firstMatch(line) case final m? when m[1] != '""') m[1]!,
      ];
      expect(assignments, [r'"$(cd "$here/../../.." && pwd)/build/l2a/android-flutter-activity"']);
      // The folder is passed as one argument even when the path of the repository has a space, and not at all when
      // there is none.
      expect(lines, contains(r'l2a_init android "${args[@]}" ${default_out:+"$default_out"}'));
      final root = Directory.current.path;
      final result = await Process.run('bash', [
        '-c',
        'here="$root/tool/l2a/ci"; cd /; default_out=${assignments.single}; echo "\$default_out"',
      ]);
      expect(result.stdout, '$root/build/l2a/android-flutter-activity\n');
    },
  );

  test('android.sh stops its guard and its emulator on any exit', () {
    expect(_codeLines(_androidScript), contains('trap l2a_cleanup EXIT'));
  });

  group('android.sh on an emulator that adb loses for a moment', () {
    late Directory dir;
    late Directory out;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('l2a_android_');
      out = Directory('${dir.path}/out');
      for (final (name, script) in [('adb', _fakeEmulator), ('flutter', _fakeFlutter), ('dart', _fakeDart)]) {
        File('${dir.path}/$name').writeAsStringSync(script);
        Process.runSync('chmod', ['+x', '${dir.path}/$name']);
      }
    });
    tearDown(() => dir.deleteSync(recursive: true));

    /// Runs `android.sh ci` against the fake emulator, flutter and dart, the views test running as [views] says,
    /// one word for each time it runs (the last word for any run after them): `pass`, `drop` (adb loses the device
    /// while flutter starts the app), `dropleak` (the same, after the app sent a packet off the device), `crash` (the
    /// app crashes at its start), `fail` (a test of the file fails), `leak` (the app does not start and sends a
    /// packet off the device). Returns the exit code of the script.
    Future<int> run(String views) async {
      final result = await Process.run(
        'bash',
        [_androidScript, 'ci', out.path],
        environment: {
          'ADB': '${dir.path}/adb',
          'L2A_FLUTTER': '${dir.path}/flutter',
          'L2A_DART': '${dir.path}/dart',
          'FAKE_DIR': dir.path,
          'FAKE_OUT': out.path,
          'FAKE_VIEWS': views,
          'L2A_STABLE_SECONDS': '1',
          'L2A_SET_UP_PAUSE': '0',
        },
      ).timeout(const Duration(minutes: 2));
      File('${dir.path}/script.out').writeAsStringSync('${result.stdout}${result.stderr}');
      return result.exitCode;
    }

    /// The run as tool/l2a/summary.dart reads it from the output directory.
    L2aRun summary() {
      String read(String name) {
        final file = File('${out.path}/$name');
        return file.existsSync() ? file.readAsStringSync() : '';
      }

      final steps = read('steps.tsv');
      return L2aRun.parse(
        steps: steps,
        info: read('info.tsv'),
        logs: {
          for (final line in steps.split('\n'))
            if (line.split('\t') case [final name, 'probe', ...]) name: read('$name.log'),
        },
      );
    }

    /// The steps the run recorded from the views test on, as `<name> <exit code>`.
    List<String> viewsSteps() => [
      for (final line in File('${out.path}/steps.tsv').readAsLinesSync().skipWhile((l) => !l.startsWith('views')))
        if (line.split('\t') case [final name, _, final rc, ...]) '$name $rc',
    ];

    int flutterRuns(String test) {
      final file = File('${dir.path}/flutter-$test');
      return file.existsSync() ? int.parse(file.readAsStringSync().trim()) : 0;
    }

    test('runs a test that did not start once more on the device set up again, and passes with it', () async {
      final code = await run('drop,pass');
      final script = File('${dir.path}/script.out').readAsStringSync();
      expect(code, 0, reason: script);
      expect(flutterRuns('views'), 2);
      expect(viewsSteps(), [
        'views-guard-ready 0',
        'views 1',
        'views-egress 1',
        'views-native-log 1',
        'views-device 0',
        'views-first-egress 0',
        'views-guard-ready 0',
        'views 0',
        'views-egress 0',
        'views-native-log 0',
      ]);
      final result = summary();
      expect(result.failureClass, isNull);
      expect(
        result.toMarkdown().split('\n'),
        allOf(contains('- retried: views (Failed to start Dart Development Service)'), contains('Result: **green**')),
      );
      // Nothing of the first run is lost: its output stays in the log of the test, its guard result and native log
      // next to the ones of the second run.
      final log = File('${out.path}/views.log').readAsStringSync();
      expect(RegExp('^${RegExp.escape(L2aRun.runHeader)}', multiLine: true).allMatches(log), hasLength(2));
      expect(log, contains('Failed to start Dart Development Service'));
      expect(log, contains('# views did not start on the device'));
      // The counters of the first guard, read once the device was back, before its rules went.
      expect(File('${out.path}/views.egress.first.log').readAsLinesSync(), [
        allOf(startsWith('FAIL uid=10217 '), endsWith('a counter could not be read')),
        'RECOVERED uid=10217 rejected_ipv4_packets=0 rejected_ipv6_packets=0 uid_rules_left=0',
      ]);
      expect(File('${out.path}/views.native.first.log').existsSync(), isTrue);
      expect(File('${out.path}/views.egress.log').readAsStringSync(), startsWith('PASS uid=10218 '));
    });

    test(
      'runs a test that did not start only once when its app sent a packet the guard read once adb was back',
      () async {
        expect(await run('dropleak,pass'), 1);
        expect(flutterRuns('views'), 1);
        expect(viewsSteps(), [
          'views-guard-ready 0',
          'views 1',
          'views-egress 1',
          'views-native-log 1',
          'views-device 0',
          'views-first-egress 1',
        ]);
        expect(
          File('${out.path}/views.egress.first.log').readAsLinesSync().last,
          allOf(startsWith('RECOVERED uid=10217 rejected_ipv4_packets=3 '), endsWith('3 IPv4 packets rejected')),
        );
        expect(summary().failure?.kind, 'probe');
        expect(File('${out.path}/info.tsv').readAsStringSync(), isNot(contains('retried')));
        // The app went before its rules, so that nothing it sends afterwards leaves unguarded.
        final calls = File('${dir.path}/calls').readAsLinesSync();
        final uninstall = calls.lastIndexWhere((c) => c.endsWith('uninstall com.adapty.flutter.adapty_l2a'));
        expect(uninstall, isNot(-1));
        final read = calls.indexWhere((c) => c.contains('-L OUTPUT') && c.contains('UID match 10217'), uninstall);
        final removed = calls.indexWhere((c) => c.contains(' -D OUTPUT') && c.contains('--uid-owner 10217'), uninstall);
        expect(read, greaterThan(uninstall));
        expect(removed, greaterThan(read));
      },
    );

    test('runs a test whose app crashed at its start only once, and stays red', () async {
      expect(await run('crash,pass'), 1);
      expect(flutterRuns('views'), 1);
      expect(viewsSteps(), ['views-guard-ready 0', 'views 1', 'views-egress 0', 'views-native-log 1']);
      expect(summary().failure?.kind, 'probe');
      expect(File('${out.path}/info.tsv').readAsStringSync(), isNot(contains('retried')));
    });

    test('runs a test that failed only once, and stays red', () async {
      expect(await run('fail'), 1);
      expect(flutterRuns('views'), 1);
      expect(viewsSteps(), ['views-guard-ready 0', 'views 1', 'views-egress 0', 'views-native-log 0']);
      expect(summary().failure, isNotNull);
      expect(summary().failure!.kind, 'probe');
      expect(File('${out.path}/info.tsv').readAsStringSync(), isNot(contains('retried')));
    });

    test('runs a test that did not start twice no more than once again, and stays red', () async {
      expect(await run('drop,drop,pass'), 1);
      expect(flutterRuns('views'), 2);
      final result = summary();
      expect(result.failure?.kind, 'probe');
      expect(result.failure?.reason, contains('views'));
    });

    test('runs a test whose app sent a packet off the device only once, and stays red', () async {
      expect(await run('leak,pass'), 1);
      expect(flutterRuns('views'), 1);
      expect(File('${out.path}/views.egress.log').readAsStringSync(), contains('3 IPv4 packets rejected'));
      expect(summary().failure?.kind, 'probe');
    });

    test('passes without a second run when the device stays', () async {
      expect(await run('pass'), 0, reason: File('${dir.path}/script.out').readAsStringSync());
      expect((flutterRuns('probe'), flutterRuns('views')), (1, 1));
      expect(File('${out.path}/info.tsv').readAsStringSync(), isNot(contains('retried')));
    });
  });
}

/// An adb that answers what the guard asks of an emulator: the app gets its uid after a few polls (or never), the
/// rules of the guard live in a file, and every call is written to `calls`.
const _fakeAdb = r'''#!/bin/bash
d=$FAKE_DIR
sleep "${FAKE_CALL_DELAY:-0}"
touch "$d/rules"
echo "$*" >> "$d/calls"
shift 2  # -s <serial>
case $1 in
  root) n=$(( $(cat "$d/roots" 2>/dev/null || echo 0) + 1 )); echo $n > "$d/roots"
    [ -n "$FAKE_ROOT_FAILS_TIMES" ] && [ $n -le $FAKE_ROOT_FAILS_TIMES ] && { echo "adb: unable to connect for root: closed"; exit 1; }
    exit 0;;
  wait-for-device) exit 0;;
  get-state) echo device; exit 0;;
  uninstall) sleep "${FAKE_UNINSTALL_SECONDS:-0}"; echo uninstalled >> "$d/calls"; exit 0;;
  shell) ;;
  *) exit 1;;
esac
cmd=$2
case $cmd in
  *packages.list*)
    n=$(( $(cat "$d/polls" 2>/dev/null || echo 0) + 1 )); echo $n > "$d/polls"
    after=${FAKE_INSTALL_AFTER:-2}
    [ "$after" != never ] && [ $n -ge $after ] && echo "com.adapty.flutter.adapty_l2a 10247 1 /data/user/0/com.adapty.flutter.adapty_l2a"
    exit 0;;
  "iptables -w -I OUTPUT"*) [ -n "$FAKE_FAIL_V4_INSERT" ] && exit 1; echo v4 >> "$d/rules"; exit 0;;
  "ip6tables -w -I OUTPUT"*) sleep "${FAKE_V6_INSERT_SECONDS:-0}"; [ -n "$FAKE_FAIL_V6_INSERT" ] && exit 1; echo v6 >> "$d/rules"; exit 0;;
  "iptables -w -L OUTPUT"*) grep -q v4 "$d/rules" 2>/dev/null && echo "${FAKE_V4_PACKETS:-0} 0 REJECT all -- * !lo 0.0.0.0/0 0.0.0.0/0 owner UID match 10247 reject-with icmp-port-unreachable"; exit 0;;
  "ip6tables -w -L OUTPUT"*) grep -q v6 "$d/rules" 2>/dev/null && echo "${FAKE_V6_PACKETS:-0} 0 REJECT all * !lo ::/0 ::/0 owner UID match 10247 reject-with icmp6-port-unreachable"; exit 0;;
  "iptables -w -D OUTPUT"*|"ip6tables -w -D OUTPUT"*)
    [ -n "$FAKE_STUCK_RULES" ] && exit 1
    t=v4; case $cmd in ip6*) t=v6;; esac
    grep -q $t "$d/rules" 2>/dev/null || exit 1
    grep -v $t "$d/rules" > "$d/rules.new"; mv "$d/rules.new" "$d/rules"; exit 0;;
  *"-S OUTPUT"*)
    while read -r t; do echo "-A OUTPUT -m owner --uid-owner 10247 ! -o lo -j REJECT ($t)"; done < "$d/rules"
    exit 0;;
esac
exit 1
''';

/// An Android emulator as android.sh in ci mode sees it through adb: one emulator, booted; the app installed by the
/// fake flutter with the next uid each time; the rules of the guard by table and uid in the file `rules`; the
/// packets the app sent off the device in `packets-v4`. While the file `dropped` exists adb has lost the device:
/// every call that needs it fails, as on the emulator of a CI runner, until adb has seen it offline twice.
const _fakeEmulator = r'''#!/bin/bash
d=$FAKE_DIR
touch "$d/rules"
echo "$*" >> "$d/calls"
if [ "$1" = devices ]; then printf 'List of devices attached\nemulator-5554\tdevice\n\n'; exit 0; fi
shift 2  # -s <serial>
lost() { [ -f "$d/dropped" ]; }
case $1 in
  root | wait-for-device) exit 0 ;;
  get-state)
    if lost; then
      n=$(( $(cat "$d/offline" 2> /dev/null || echo 0) + 1 )); echo $n > "$d/offline"
      [ $n -ge 2 ] && rm -f "$d/dropped" "$d/offline"
      echo 'error: device offline' >&2; exit 1
    fi
    echo device; exit 0 ;;
  logcat)
    lost && { echo '- waiting for device -' >&2; exit 1; }
    [ "$2" = -c ] && rm -f "$d/crashed"
    if [ "$2" = -d ] && [ -f "$d/installed" ]; then
      echo '11-26 11:40:47.600   612   640 I ActivityManager: Start proc 9097:com.adapty.flutter.adapty_l2a/u0a217 for top-activity'
      echo '11-26 11:40:49.120  9097  9097 I flutter : The Dart VM service is listening'
      [ -f "$d/crashed" ] && echo '11-26 11:40:49.300  9097  9097 E AndroidRuntime: FATAL EXCEPTION: main'
    fi
    exit 0 ;;
  uninstall) lost && exit 1; rm -f "$d/installed"; exit 0 ;;
  shell) lost && { echo 'adb: device offline' >&2; exit 1; } ;;
  *) exit 1 ;;
esac
cmd="${*:2}"
table=v4; case $cmd in ip6tables*) table=v6 ;; esac
uid=$(echo "$cmd" | sed -nE 's/.*(--uid-owner|UID match) ([0-9]+).*/\2/p')
case $cmd in
  'getprop sys.boot_completed') echo 1 ;;
  'getprop ro.build.fingerprint') echo fake/emulator ;;
  *packages.list*) [ -f "$d/installed" ] && echo "com.adapty.flutter.adapty_l2a $(cat "$d/installed") 1 /data/user/0" ;;
  *'tables -w -I OUTPUT'*) echo "$table $uid" >> "$d/rules" ;;
  *'tables -w -L OUTPUT'*)
    grep -qx "$table $uid" "$d/rules" &&
      echo "$(cat "$d/packets-$table-$uid" 2> /dev/null || echo 0) 0 REJECT owner UID match $uid" ;;
  *'tables -w -D OUTPUT'*)
    grep -qx "$table $uid" "$d/rules" || exit 1
    awk -v rule="$table $uid" '!gone && $0 == rule { gone = 1; next } 1' "$d/rules" > "$d/rules.new"
    mv "$d/rules.new" "$d/rules" ;;
  *'-S OUTPUT'*) while read -r t u; do echo "-A OUTPUT -m owner --uid-owner $u ! -o lo -j REJECT"; done < "$d/rules" ;;
esac
exit 0
''';

/// A flutter for android.sh in ci mode: it lists the emulator, and runs each test (installing the app with the next
/// uid and waiting until the guard has its rules in place) as the comma-separated words of FAKE_<TEST> say, one for
/// each time the test runs; see the test group that uses it.
const _fakeFlutter = r'''#!/bin/bash
d=$FAKE_DIR
case $1 in
  pub) exit 0 ;;
  devices) echo 'sdk gphone64 x86 64 (mobile) • emulator-5554 • android-x64 • Android 16 (API 36) (emulator)'; exit 0 ;;
  test) ;;
  *) exit 1 ;;
esac
test=$(basename "$2" _test.dart); test=${test#l2a_}
n=$(( $(cat "$d/flutter-$test" 2> /dev/null || echo 0) + 1 )); echo $n > "$d/flutter-$test"
words=FAKE_$(echo "$test" | tr a-z A-Z)
words=${!words:-pass}
mode=$(echo "$words" | cut -d, -f$n); [ -n "$mode" ] || mode=${words##*,}
echo "Running Gradle task 'assembleDebug'...                             12.1s"
echo '✓ Built build/app/outputs/flutter-apk/app-debug.apk'
uid=$(( $(cat "$d/uid" 2> /dev/null || echo 10215) + 1 )); echo $uid > "$d/uid"; echo $uid > "$d/installed"
echo 'Installing build/app/outputs/flutter-apk/app-debug.apk...          643ms'
for _ in $(seq 100); do [ -f "$FAKE_OUT/$test.egress.log.armed" ] && break; sleep 0.1; done
file=$PWD/$2
case $mode in
  pass)
    [ "$test" = probe ] && echo 'L2A_OUTCOME {"id":"get_profile/default","matches":true}' &&
      echo 'L2A_SUMMARY {"platform":"android","cases":1,"called":1,"unexpected":0,"unobservable":0}'
    [ "$test" = views ] && echo 'L2A_VIEW {"id":"flow_platform_view/default","platform":"android","created":0}'
    echo "::group::✅ $test"; echo '::endgroup::'; echo '🎉 1 test passed.'; exit 0 ;;
  fail)
    echo 'L2A_VIEW {"id":"flow_platform_view/default","platform":"android","created":0}'
    echo "::group::❌ $test (failed)"; echo 'Expected: <3>'; echo '  Actual: <2>'; echo '::endgroup::'
    echo '::error::0 tests passed, 1 failed.'; exit 1 ;;
  drop | leak | dropleak)
    case $mode in leak | dropleak) echo 3 > "$d/packets-v4-$uid" ;; esac
    case $mode in drop | dropleak) touch "$d/dropped" ;; esac
    echo "::group::❌ loading $file (failed)"
    echo "Failed to load \"$file\": Failed to start Dart Development Service"
    echo '::endgroup::'; echo '::error::0 tests passed, 1 failed.'; exit 1 ;;
  crash)
    touch "$d/crashed"
    echo 'Error waiting for a debug connection: The log reader stopped unexpectedly'
    echo "::group::❌ loading $file (failed)"
    echo "Failed to load \"$file\": Unable to start the app on the device."
    echo '::endgroup::'; echo '::error::0 tests passed, 1 failed.'; exit 1 ;;
esac
exit 1
''';

/// A dart for android.sh: the bundle has three flow views on Android, the native log check passes when the log has a
/// line of the app, and the summary is left to the test.
const _fakeDart = r'''#!/bin/bash
case $2 in
  tool/l2a/bundle_cases.dart) echo 'flow views: ios 3, android 3'; exit 0 ;;
  tool/l2a/native_log_check.dart) grep -q ' I flutter ' "$4" && ! grep -q 'FATAL EXCEPTION' "$4" ;;
  tool/l2a/summary.dart) exit 0 ;;
  *) exit 1 ;;
esac
''';

/// How the run script starts the output of a run of a test in its log.
const _runHeader =
    '${L2aRun.runHeader}adapty_flutter @ 0742602, working tree clean): bash -c cd integration_test_app && '
    "'flutter' test integration_test/l2a_views_test.dart -d emulator-5554\n"
    '# device: emulator emulator-5554\n'
    '# started: 2026-11-26 11:40:32';

/// The native log of an app that started: the lines of its process up to its Dart VM service.
const _nativeStarted =
    '# command: adb -s emulator-5554 logcat -d, lines of the app processes (9097 )\n'
    '11-26 11:40:47.659  9097  9097 I tter.adapty_l2a: Late-enabling -Xcheck:jni\n'
    '11-26 11:40:49.120  9097  9097 I flutter : The Dart VM service is listening on http://127.0.0.1:43409/7mar5bd4UbE=/\n';

/// The guard result of a test during which adb lost the device: no counter could be read.
const _guardLostDevice =
    'FAIL uid=10217 rejected_ipv4_packets=? rejected_ipv6_packets=? uid_rules_left=0: a counter could not be read';

/// The guard result of a test whose app sent packets off the device.
const _guardRejected =
    'FAIL uid=10217 rejected_ipv4_packets=3 rejected_ipv6_packets=0 uid_rules_left=0: 3 IPv4 packets rejected';

/// The views test of a CI run on GitHub (2026-11-26) during which adb lost the emulator for a second.
const _ddsLost = '''
Running Gradle task 'assembleDebug'...                             12.1s
✓ Built build/app/outputs/flutter-apk/app-debug.apk
Installing build/app/outputs/flutter-apk/app-debug.apk...          643ms
::group::❌ loading /home/runner/work/AdaptySDK-Flutter/AdaptySDK-Flutter/integration_test_app/integration_test/l2a_views_test.dart (failed)
Failed to load "/home/runner/work/AdaptySDK-Flutter/AdaptySDK-Flutter/integration_test_app/integration_test/l2a_views_test.dart": Failed to start Dart Development Service

::endgroup::

::error::0 tests passed, 1 failed.
# finished: rc=1 18s''';

/// A local run of the probe right after a quick boot (2026-11-20): adb lost the emulator while flutter installed the
/// app.
const _offlineAtInstall = '''
00:00 +0: loading /work/adapty_flutter/integration_test_app/integration_test/l2a_probe_test.dart
Running Gradle task 'assembleDebug'...                              6.9s
✓ Built build/app/outputs/flutter-apk/app-debug.apk
adb: device offline
Installing build/app/outputs/flutter-apk/app-debug.apk...           14ms
Error: ADB exited with exit code 1
adb: device offline
00:00 +0 -1: loading /work/adapty_flutter/integration_test_app/integration_test/l2a_probe_test.dart [E]
  Failed to load "/work/adapty_flutter/integration_test_app/integration_test/l2a_probe_test.dart": Unable to start the app on the device.
00:00 +0 -1: Some tests failed.
adb: device offline
# finished: rc=1 9s''';

/// A local run of the probe (2026-11-20): adb lost the emulator while flutter waited for the app to start.
const _logReaderStopped = '''
00:00 +0: loading /work/adapty_flutter/integration_test_app/integration_test/l2a_probe_test.dart
Running Gradle task 'assembleDebug'...                              7.2s
✓ Built build/app/outputs/flutter-apk/app-debug.apk
Installing build/app/outputs/flutter-apk/app-debug.apk...          320ms
Error waiting for a debug connection: The log reader stopped unexpectedly
00:00 +0 -1: loading /work/adapty_flutter/integration_test_app/integration_test/l2a_probe_test.dart [E]
  Failed to load "/work/adapty_flutter/integration_test_app/integration_test/l2a_probe_test.dart": Unable to start the app on the device.
00:00 +0 -1: Some tests failed.
adb: device offline
# finished: rc=1 10s''';

/// A run in which flutter did not find the emulator at all.
const _noDevice = '''
No supported devices found with name or id matching 'emulator-5554'.
# finished: rc=1 2s''';

/// A run whose test ran and failed, after which adb lost the emulator.
const _testFailedThenOffline = '''
00:00 +0: loading /work/adapty_flutter/integration_test_app/integration_test/l2a_views_test.dart
Running Gradle task 'assembleDebug'...                              7.0s
✓ Built build/app/outputs/flutter-apk/app-debug.apk
Installing build/app/outputs/flutter-apk/app-debug.apk...          320ms
00:28 +0: every flow view reports the error of a view made before activation
00:31 +0 -1: every flow view reports the error of a view made before activation [E]
  Expected: <3>
    Actual: <2>
00:31 +0 -1: Some tests failed.
adb: device offline
# finished: rc=1 31s''';

/// A run whose test file did not compile.
const _compileError = '''
00:00 +0: loading /work/adapty_flutter/integration_test_app/integration_test/l2a_views_test.dart
integration_test/l2a_views_test.dart:12:3: Error: Undefined name 'views'.
00:05 +0 -1: loading /work/adapty_flutter/integration_test_app/integration_test/l2a_views_test.dart [E]
  Failed to load "/work/adapty_flutter/integration_test_app/integration_test/l2a_views_test.dart": Compilation failed
00:05 +0 -1: Some tests failed.
# finished: rc=1 5s''';

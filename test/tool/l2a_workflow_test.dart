// The job that runs the native probe on simulators (.github/workflows/l2a.yml) and its scripts
// (tool/l2a/ci/): the decisions behind them, which a workflow run on GitHub would only show by failing, and the
// behaviour of the parts that run on a machine without devices (the gate, the egress guard on a fake adb).
@TestOn('mac-os || linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

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

/// The lines of a shell script without comments.
List<String> _codeLines(String path) => [
  for (final line in File(path).readAsLinesSync())
    if (!line.trimLeft().startsWith('#')) line,
];

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

    test('the expectations name the iOS SDK they were recorded on', () {
      final expectations = loadYaml(File('integration_test_app/l2a_expectations.yaml').readAsStringSync()) as YamlMap;
      expect('${(expectations['probed'] as YamlMap)['ios_sha']}', matches(RegExp(r'^[0-9a-f]{40}$')));
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

    /// Runs the guard against the fake adb for [seconds], stops it with TERM and returns what it wrote.
    Future<String> guard({Map<String, String> fake = const {}, double seconds = 1.5}) async {
      final process = await Process.start(
        'bash',
        [_guard, 'emulator-5580', 'com.adapty.flutter.adapty_l2a', result.path],
        environment: {'ADB': '${dir.path}/adb', 'FAKE_DIR': dir.path, ...fake},
      );
      await Future<void>.delayed(Duration(milliseconds: (seconds * 1000).round()));
      process.kill(ProcessSignal.sigterm);
      await process.exitCode.timeout(const Duration(seconds: 10));
      return result.existsSync() ? result.readAsStringSync() : '';
    }

    int inserts(String table) => calls.readAsLinesSync().where((line) => line.contains('$table -I OUTPUT')).length;

    test('passes when the app sent nothing off the device, and removes its rules', () async {
      expect(
        await guard(),
        startsWith('PASS uid=10247 rejected_ipv4_packets=0 rejected_ipv6_packets=0 uid_rules_left=0'),
      );
      expect((inserts('iptables'), inserts('ip6tables')), (1, 1));
    });

    test('fails when the app was never installed while it ran', () async {
      expect(await guard(fake: {'FAKE_INSTALL_AFTER': 'never'}, seconds: 0.8), contains('never installed'));
    });

    test('fails when a packet was rejected', () async {
      expect(await guard(fake: {'FAKE_V4_PACKETS': '3'}), allOf(startsWith('FAIL'), contains('3 IPv4 packets')));
    });

    test('fails once, without inserting the IPv4 rule again, when the IPv6 rule cannot be inserted', () async {
      final written = await guard(fake: {'FAKE_FAIL_V6_INSERT': '1'});
      expect(written, startsWith('FAIL uid=10247'));
      expect(inserts('iptables'), 1);
      expect(written, contains('uid_rules_left=0'));
    });

    test('fails when its rules cannot be removed', () async {
      expect(await guard(fake: {'FAKE_STUCK_RULES': '1'}), allOf(startsWith('FAIL'), contains('uid rules left')));
    });

    test('is stopped by the trap of the script that started it, and still writes its result', () async {
      final script = await _bash(
        '. $_common; trap l2a_cleanup EXIT; '
        'l2a_start_guard emulator-5580 com.adapty.flutter.adapty_l2a ${result.path}; sleep 1.5; exit 3',
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

  test('android.sh stops its guard and its emulator on any exit', () {
    expect(_codeLines(_androidScript), contains('trap l2a_cleanup EXIT'));
  });
}

/// An adb that answers what the guard asks of an emulator: the app gets its uid after a few polls (or never), the
/// rules of the guard live in a file, and every call is written to `calls`.
const _fakeAdb = r'''#!/bin/bash
d=$FAKE_DIR
touch "$d/rules"
echo "$*" >> "$d/calls"
shift 2  # -s <serial>
case $1 in root|uninstall|wait-for-device) exit 0;; shell) ;; *) exit 1;; esac
cmd=$2
case $cmd in
  *packages.list*)
    n=$(( $(cat "$d/polls" 2>/dev/null || echo 0) + 1 )); echo $n > "$d/polls"
    after=${FAKE_INSTALL_AFTER:-2}
    [ "$after" != never ] && [ $n -ge $after ] && echo "com.adapty.flutter.adapty_l2a 10247 1 /data/user/0/com.adapty.flutter.adapty_l2a"
    exit 0;;
  "iptables -I OUTPUT"*) [ -n "$FAKE_FAIL_V4_INSERT" ] && exit 1; echo v4 >> "$d/rules"; exit 0;;
  "ip6tables -I OUTPUT"*) [ -n "$FAKE_FAIL_V6_INSERT" ] && exit 1; echo v6 >> "$d/rules"; exit 0;;
  "iptables -L OUTPUT"*) grep -q v4 "$d/rules" 2>/dev/null && echo "${FAKE_V4_PACKETS:-0} 0 REJECT all -- * !lo 0.0.0.0/0 0.0.0.0/0 owner UID match 10247 reject-with icmp-port-unreachable"; exit 0;;
  "ip6tables -L OUTPUT"*) grep -q v6 "$d/rules" 2>/dev/null && echo "${FAKE_V6_PACKETS:-0} 0 REJECT all * !lo ::/0 ::/0 owner UID match 10247 reject-with icmp6-port-unreachable"; exit 0;;
  "iptables -D OUTPUT"*|"ip6tables -D OUTPUT"*)
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

import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/contract_schema.dart' show ContractPlatform;
import '../../tool/l2a/src/native_log.dart';

void main() {
  group('iOS', () {
    // Lines of `log show --predicate 'subsystem == "io.adapty.flutter"'` on a simulator before activation.
    const header = 'getpwuid_r did not find a match for uid 501';
    const flowNotActivated =
        '2026-11-19 23:28:53.738 F  Runner[97148:2b62665] [io.adapty.flutter:wrapper] The operation couldn’t be '
        'completed. (AdaptyUIErrorDomain error 4003.)';
    const onboardingNotActivated =
        '2026-11-19 23:28:59.116 F  Runner[97148:2b6265b] [io.adapty.flutter:wrapper] The operation couldn’t be '
        'completed. (AdaptyUIErrorDomain error 4002.)';
    const brokenParams =
        '2026-11-19 23:28:56.434 F  Runner[97148:2b62650] [io.adapty.flutter:wrapper] The data couldn’t be read '
        'because it is missing.';
    const sdkNotActivated =
        '2026-11-19 23:27:50.911 F  Runner[95715:2b60349] [io.adapty:sdk] Completed getProfile() [oMhnGK] with error: '
        'AdaptyError.notActivated([4.4.1]: Adapty/Adapty+Shared.swift#43).';

    test('the errors of views before activation are no defect', () {
      expect(
        defectLines(
          [header, flowNotActivated, onboardingNotActivated, sdkNotActivated].join('\n'),
          ContractPlatform.ios,
        ),
        isEmpty,
      );
    });

    test('an event the plugin cannot encode is a defect', () {
      const lostEvent =
          '2026-11-20 12:00:00.000 E  Runner[1:2] [io.adapty.flutter:wrapper] Plugin encoding error: The data '
          'couldn\u2019t be written because it isn\u2019t in the correct format.';
      expect(defectLines([header, flowNotActivated, lostEvent].join('\n'), ContractPlatform.ios), [lostEvent]);
    });

    test('a second registration of the plugin is a defect', () {
      const twice =
          '2026-11-20 12:00:00.000 W  Runner[1:2] [io.adapty.flutter:wrapper] Attempt to register the plugin twice! '
          'Skipping.';
      expect(defectLines([header, twice].join('\n'), ContractPlatform.ios), [twice]);
    });

    test('a line of another subsystem that could not read a request is no defect', () {
      const pluginRefused =
          '2026-11-19 23:27:50.951 F  Runner[95715:2b60365] [io.adapty:plugin] Request params of method:get_flow is '
          'invalid: The data couldn\u2019t be read because it is missing.';
      expect(defectLines([header, pluginRefused].join('\n'), ContractPlatform.ios), isEmpty);
    });

    test('counts the onboarding views that met an inactive SDK', () {
      expect(
        onboardingNotActivatedLines(
          [header, flowNotActivated, onboardingNotActivated, onboardingNotActivated].join('\n'),
        ),
        2,
      );
      expect(onboardingNotActivatedLines([header, flowNotActivated, brokenParams].join('\n')), 0);
    });

    test('a line of another subsystem about an onboarding view and an inactive SDK is not counted', () {
      const sdkOnboardingNotActivated =
          '2026-11-19 23:28:59.120 E  Runner[97148:2b6265b] [io.adapty:ui] The operation couldn’t be '
          'completed. (AdaptyUIErrorDomain error 4002.)';
      expect(onboardingNotActivatedLines([header, onboardingNotActivated, sdkOnboardingNotActivated].join('\n')), 1);
    });

    test('a log that log show did not write is a problem', () {
      const command = "# command: xcrun simctl spawn 349D log show --start '2026-11-20 13:49:39' --predicate '…'";
      expect(nativeLogProblems([command, 'Invalid device: 349D'].join('\n'), ContractPlatform.ios), [
        contains('log show'),
      ]);
    });

    test('a log without a line of the app process is a problem, as its window missed the test', () {
      // What log show writes for a window with no entry: the command of the script, then only the header.
      const command = "# command: xcrun simctl spawn 349D log show --start '2026-11-20 13:49:39' --predicate '…'";
      const columns = 'Timestamp                       Thread     Type        Activity             PID    TTL';
      expect(nativeLogProblems([command, header, columns].join('\n'), ContractPlatform.ios), [
        contains('no line of the app process'),
      ]);
    });

    test('a log of the app process without a line of the wrapper is no problem', () {
      const columns = 'Timestamp                       Thread     Type        Activity             PID    TTL';
      const vmService =
          '2026-11-20 17:05:49.609720+0400 0x32a13c7  Default     0x0                  94816  0    Runner: (Flutter) '
          'flutter: The Dart VM service is listening on http://127.0.0.1:56100/RbleMrkMr60=/';
      expect(nativeLogProblems([header, columns, vmService].join('\n'), ContractPlatform.ios), isEmpty);
    });

    test('a wrong number of onboarding views that met an inactive SDK is a problem', () {
      const columns = 'Timestamp                       Thread     Type        Activity             PID    TTL';
      final log = [columns, onboardingNotActivated].join('\n');
      expect(nativeLogProblems(log, ContractPlatform.ios, onboardingViews: 1), isEmpty);
      expect(nativeLogProblems(log, ContractPlatform.ios, onboardingViews: 2), [contains('1 onboarding views')]);
    });

    test('creation params the wrapper cannot read are a defect', () {
      expect(defectLines([header, flowNotActivated, brokenParams].join('\n'), ContractPlatform.ios), [brokenParams]);
    });
  });

  group('Android', () {
    // Lines of `adb logcat -d` of the app processes (by the pids the activity manager started them with) on an
    // emulator before activation, with the log level of the SDK at verbose.
    const sdkNotActivated = '11-19 23:35:48.990  5007  5122 E Adapty_v4.4.0: ERROR: Adapty was not initialized';
    const callThrew =
        '11-19 23:35:49.010  5007  5007 E MethodChannel#flutter.adapty.com/adapty: java.lang.NullPointerException: '
        'Parameter specified as non-null is null: method com.adapty.Adapty.identify, parameter customerUserId';
    const viewFailed =
        '11-19 23:36:38.886  5690  5690 E MethodChannel#flutter/platform_views: Failed to handle method call';
    const viewThrew =
        '11-19 23:36:38.886  5690  5690 E MethodChannel#flutter/platform_views: java.lang.NullPointerException: Attempt '
        "to invoke virtual method 'java.lang.String com.adapty.internal.data.models.OnboardingBuilder.getUrl()' on a "
        'null object reference';
    const fatal = '11-19 23:36:40.001  5690  5690 E AndroidRuntime: FATAL EXCEPTION: main';

    test('not activated and the exceptions of recorded calls are no defect', () {
      expect(defectLines([sdkNotActivated, callThrew].join('\n'), ContractPlatform.android), isEmpty);
    });

    test('a platform view that fails to be created is a defect', () {
      expect(defectLines([sdkNotActivated, viewFailed, viewThrew].join('\n'), ContractPlatform.android), [
        viewFailed,
        viewThrew,
      ]);
    });

    test('a crash is a defect', () {
      expect(defectLines([sdkNotActivated, fatal].join('\n'), ContractPlatform.android), [fatal]);
    });

    const viewNotConfigured =
        '11-20 15:26:42.068  4212  4271 E Adapty_v4.4.0: ERROR: Failed to get view configuration: Adapty was not '
        'initialized';
    const argsNotParsed =
        '11-20 15:26:49.856  4212  4271 E Adapty_v4.4.0: ERROR: could not parse args as CreateFlowViewArgs '
        '({"flow":"broken","locale":"fr"})';
    const nativeCrash =
        '11-20 15:27:01.120  4212  4212 F libc    : Fatal signal 11 (SIGSEGV), code 1 (SEGV_MAPERR), fault addr 0x0';

    test('creation params the plugin cannot parse are a defect', () {
      expect(defectLines([sdkNotActivated, argsNotParsed].join('\n'), ContractPlatform.android), [argsNotParsed]);
    });

    test('a native crash is a defect', () {
      expect(defectLines([sdkNotActivated, nativeCrash].join('\n'), ContractPlatform.android), [nativeCrash]);
    });

    test('each flow view whose params parsed asks for its configuration once', () {
      final log = [viewNotConfigured, argsNotParsed, viewNotConfigured].join('\n');
      expect(flowViewConfigurationLines(log), 2);
      expect(
        nativeLogProblems([viewNotConfigured, viewNotConfigured].join('\n'), ContractPlatform.android, flowViews: 2),
        isEmpty,
      );
      expect(
        nativeLogProblems(log, ContractPlatform.android, flowViews: 3),
        containsAll([contains(argsNotParsed), contains('2 flow views asked for their configuration, 3 expected')]),
      );
    });

    test('a log without a line of the app process is a problem, as the log was lost', () {
      const header = '# command: adb -s emulator-5580 logcat -d, lines of the app processes ()';
      expect(nativeLogProblems(header, ContractPlatform.android), [contains('no line of the app')]);
      expect(nativeLogProblems([header, sdkNotActivated].join('\n'), ContractPlatform.android), isEmpty);
    });

    test('the problems of a log name its defect lines', () {
      expect(nativeLogProblems([sdkNotActivated, fatal].join('\n'), ContractPlatform.android), [contains(fatal)]);
    });
  });
}

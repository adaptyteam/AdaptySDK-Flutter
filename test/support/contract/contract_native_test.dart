// The contract of the contract native: it checks every call of the SDK against the bridge contract for its platform,
// answers from the corpus of that platform, sends events from it and leaves nothing behind after a test.
import 'dart:convert';
import 'dart:io';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/runtime/adapty_internal_error_sink.dart';
import 'package:adapty_flutter/src/runtime/adapty_native_transport.dart';
import 'package:adapty_flutter/src/runtime/adapty_runtime.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/contract/src/corpus.dart';
import '../../../tool/contract/src/overlays.dart';
import '../collecting_error_sink.dart';
import 'contract_runtime.dart';

const ios = ContractPlatform.ios;
const android = ContractPlatform.android;

const _channel = MethodChannel(adaptyChannelName);

TestDefaultBinaryMessenger get _messenger => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

/// Calls [method] on the adapty channel as the SDK does, with [arguments] as a JSON string, and returns the reply
/// decoded.
Future<Object?> _invoke(String method, Object? arguments) async {
  final reply = await _channel.invokeMethod<String>(method, jsonEncode(arguments));
  return reply == null ? null : jsonDecode(reply);
}

/// The baseline of a repository whose only file is a baseline with [yaml], read as the corpus reads it.
List<BaselineEntry> _baseline(String yaml) {
  final root = Directory.systemTemp.createTempSync('contract_baseline_');
  addTearDown(() => root.deleteSync(recursive: true));
  File('${root.path}/${Corpus.baselinePath}')
    ..createSync(recursive: true)
    ..writeAsStringSync(yaml);
  final corpus = Corpus.load(root.path);
  expect(corpus.problems, isEmpty);
  return corpus.baseline;
}

final class _Observer extends AdaptyUIFlowsEventsObserver {
  final appeared = <AdaptyUIFlowView>[];

  @override
  void flowViewDidAppear(AdaptyUIFlowView view) => appeared.add(view);

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) {}

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AdaptyRuntime before;
  setUpAll(() => before = AdaptyRuntime.current);

  tearDownAll(() async {
    expect(identical(AdaptyRuntime.current, before), isTrue, reason: 'the runtime current before the tests is back');
    expect(_messenger.checkMockMessageHandler(adaptyChannelName, null), isTrue, reason: 'no native answers the calls');
    ByteData? reply = ByteData(1);
    await _messenger.handlePlatformMessage(
      adaptyChannelName,
      const StandardMethodCodec().encodeMethodCall(const MethodCall('did_load_latest_profile', '{}')),
      (data) => reply = data,
    );
    expect(reply, isNull, reason: 'nothing takes the events of the native side');
  });

  group('requests', () {
    test('a request the contract accepts is answered and kept in the journal', () async {
      final rt = installContractRuntime(platform: ios);

      await Adapty().getProfile();

      final call = rt.native.calls.single;
      expect(call.method, 'get_profile');
      expect(call.arguments, isEmpty);
      expect(call.violations, isEmpty);
      expect(jsonDecode(call.reply!), contains('success'));
      expect(rt.native.problems, isEmpty);
    });

    test('a key the contract does not know is a problem naming the path, the method and the platform', () async {
      final rt = installContractRuntime(platform: android);

      await _invoke('get_profile', {'bogus': 1});

      expect(rt.native.problems, [
        allOf(contains('/bogus'), contains('additionalProperties'), contains('get_profile'), contains('android')),
      ]);
      expect(
        rt.native.verify,
        throwsA(isA<TestFailure>().having((e) => e.message, 'message', allOf(contains('/bogus'), contains('android')))),
      );
      rt.native.takeProblems();
    });

    test('arguments that are not a JSON object are a problem', () async {
      final rt = installContractRuntime(platform: ios);

      await _channel.invokeMethod<String>('get_profile', '[1]');

      expect(rt.native.problems, [allOf(contains('get_profile'), contains('JSON object'))]);
      rt.native.takeProblems();
    });

    test('a method the contract does not have is a problem and gets the native "method not found" answer', () async {
      final rt = installContractRuntime(platform: ios);

      final reply = await _invoke('get_flows', {});

      expect(reply, {
        'error': {'adapty_code': 2006, 'message': 'Method get_flows not found'},
      });
      expect(rt.native.problems, [allOf(contains('get_flows'), contains('not a request of the contract'))]);
      rt.native.takeProblems();
    });

    test('a method the platform does not handle gets 2006 and is a platform_method problem', () async {
      final rt = installContractRuntime(platform: android);

      final reply = await _invoke('get_log_level', {});

      expect(reply, {
        'error': {'adapty_code': 2006, 'message': 'Method get_log_level not found'},
      });
      expect(rt.native.problems, [allOf(contains('platform_method'), contains('get_log_level'), contains('android'))]);
      rt.native.takeProblems();
    });

    test('a method without a case in the corpus is a problem and gets no answer', () async {
      final rt = installContractRuntime(platform: ios);

      final reply = await _channel.invokeMethod<String>('get_log_level', '{}');

      expect(reply, isNull);
      expect(rt.native.problems, [allOf(contains('get_log_level'), contains('ios'), contains('no case "default"'))]);
      rt.native.takeProblems();
    });
  });

  group('the baseline', () {
    test('an item takes away exactly its violation and keeps it for the test to see', () async {
      final rt = installContractRuntime(
        platform: android,
        baseline: _baseline('''
- id: extra-key
  direction: request
  entry: GetProfile.Request
  path: /bogus
  keyword: additionalProperties
  platform: android
  case: get_profile/bogus
  reason: r
  decision: accepted
'''),
      );

      await _invoke('get_profile', {'bogus': 1, 'other': 2});

      expect(rt.native.problems, [allOf(contains('/other'), isNot(contains('/bogus')))]);
      expect(
        rt.native.suppressed.map((s) => (s.call.method, s.violation.instancePath, s.violation.keyword, s.item.id)),
        [('get_profile', '/bogus', 'additionalProperties', 'extra-key')],
      );
      rt.native.takeProblems();
    });

    test('an item of the other platform takes nothing away', () async {
      final rt = installContractRuntime(
        platform: ios,
        baseline: _baseline('''
- id: extra-key
  direction: request
  entry: GetProfile.Request
  path: /bogus
  keyword: additionalProperties
  platform: android
  case: get_profile/bogus
  reason: r
  decision: accepted
'''),
      );

      await _invoke('get_profile', {'bogus': 1});

      expect(rt.native.problems, [contains('/bogus')]);
      expect(rt.native.suppressed, isEmpty);
      rt.native.takeProblems();
    });

    test('a batch item takes away a field of the other platform the SDK sends', () async {
      const batch = '''
- id: platform-fields
  direction: request
  keyword: platform_field
  items:
    - {entry: Identify.Request, path: /parameters/obfuscated_account_id, platform: ios, case: identify/with_parameters}
  reason: r
  decision: accepted
  source: [s]
''';
      final without = installContractRuntime(platform: ios);
      await Adapty().identify('user-1', androidObfuscatedAccountId: 'account-1');
      expect(without.native.problems, [
        allOf(contains('platform_field'), contains('/parameters/obfuscated_account_id')),
      ]);
      without.native.takeProblems();

      final rt = installContractRuntime(platform: ios, baseline: _baseline(batch));
      await Adapty().identify('user-1', androidObfuscatedAccountId: 'account-1');

      expect(rt.native.problems, isEmpty);
      expect(rt.native.suppressed.map((s) => (s.violation.instancePath, s.item.caseName)), [
        ('/parameters/obfuscated_account_id', 'identify/with_parameters'),
      ]);
    });

    test('an item takes away a method the platform does not handle, and the answer stays 2006', () async {
      final rt = installContractRuntime(
        platform: android,
        baseline: _baseline('''
- id: unhandled
  direction: request
  entry: GetLogLevel.Request
  path: ''
  keyword: platform_method
  platform: android
  case: get_log_level/default
  reason: r
  decision: accepted
'''),
      );

      final reply = await _invoke('get_log_level', {});

      expect(reply, {
        'error': {'adapty_code': 2006, 'message': 'Method get_log_level not found'},
      });
      expect(rt.native.problems, isEmpty);
      expect(rt.native.suppressed.map((s) => (s.violation.keyword, s.item.id)), [('platform_method', 'unhandled')]);
    });
  });

  group('answers', () {
    test('the answer is the default case of the platform', () async {
      installContractRuntime(platform: ios);
      expect((await Adapty().getProfile()).accessLevels['premium']!.store, 'app_store');
    });

    test('on Android the answer is the Android case', () async {
      installContractRuntime(platform: android);
      expect((await Adapty().getProfile()).accessLevels['premium']!.store, 'play_store');
    });

    test('another case answers from then on', () async {
      final rt = installContractRuntime(platform: android);
      rt.native.respond('get_profile', 'error');

      await expectLater(
        Adapty().getProfile(),
        throwsA(
          isA<AdaptyError>()
              .having((e) => e.code, 'code', 2002)
              .having((e) => e.message, 'message', 'something failed'),
        ),
      );
    });

    test('a case the platform does not have is refused at once', () {
      final rt = installContractRuntime(platform: android);
      expect(() => rt.native.respond('get_profile', 'missing'), throwsArgumentError);
      expect(() => rt.native.respond('get_pending_store_message_types', 'default'), throwsArgumentError);
    });

    test('before activation iOS answers 2002', () async {
      final rt = installContractRuntime(platform: ios);
      rt.native.replyNotActivated();

      await expectLater(
        Adapty().getProfile(),
        throwsA(
          isA<AdaptyError>()
              .having((e) => e.code, 'code', 2002)
              .having(
                (e) => e.message,
                'message',
                'Adapty SDK is not initialized. You need to activate the SDK before using its methods.',
              ),
        ),
      );
    });

    test('before activation Android answers 20', () async {
      final rt = installContractRuntime(platform: android);
      rt.native.replyNotActivated();

      await expectLater(
        Adapty().getProfile(),
        throwsA(
          isA<AdaptyError>()
              .having((e) => e.code, 'code', 20)
              .having((e) => e.message, 'message', 'Adapty was not initialized'),
        ),
      );
    });
  });

  group('events', () {
    test('an event reaches the SDK and the handler answers null', () async {
      final rt = installContractRuntime(platform: android);
      final profile = Adapty().didUpdateProfileStream.first;

      final reply = await rt.native.sendEvent('did_load_latest_profile');

      expect(reply, isNull);
      expect((await profile).accessLevels['premium']!.store, 'play_store');
    });

    test('an event the platform does not send is refused at once', () {
      final rt = installContractRuntime(platform: android);
      expect(() => rt.native.sendEvent('did_receive_promoted_purchase'), throwsArgumentError);
    });

    test('the answer to an event is matched by its event id', () async {
      final rt = installContractRuntime(platform: ios);

      await rt.native.sendEvent('flow_view_did_ask_permission');
      await settle(rt.runtime);

      final answer = rt.native.answersTo('hr_1').single;
      expect(answer.method, 'flow_view_did_answer_permission');
      expect(answer.arguments, {'event_id': 'hr_1', 'status': 'denied'});
      expect(rt.native.problems, isEmpty);
    });

    test('a second answer to the same event is a problem', () async {
      final rt = installContractRuntime(platform: ios);
      await rt.native.sendEvent('flow_view_did_ask_permission');
      await settle(rt.runtime);

      await _invoke('flow_view_did_answer_permission', {'event_id': 'hr_1', 'status': 'granted'});

      expect(rt.native.problems, [allOf(contains('flow_view_did_answer_permission'), contains('hr_1'))]);
      rt.native.takeProblems();
    });

    test('an answer to an event the native never sent is a problem', () async {
      final rt = installContractRuntime(platform: ios);

      await _invoke('flow_view_did_answer_permission', {'event_id': 'hr_9', 'status': 'granted'});

      expect(rt.native.problems, [allOf(contains('flow_view_did_answer_permission'), contains('hr_9'))]);
      rt.native.takeProblems();
    });
  });

  group('the runtime', () {
    test('app message ids are the same in every run', () async {
      final rt = installContractRuntime(platform: android);
      final observer = _Observer();
      AdaptyUI().setFlowsEventsObserver(observer);
      await rt.native.sendEvent('flow_view_did_appear');

      await AdaptyUI().sendAppMessage(observer.appeared.single, {'step': 'welcome'});
      await AdaptyUI().sendAppMessage(observer.appeared.single, {'step': 'paywall'});

      expect(rt.native.calls.where((call) => call.method == 'adapty_ui_send_app_message').map((c) => c.arguments), [
        {
          'id': 'view-1',
          'message_id': '00000000-0000-4000-8000-000000000001',
          'payload': {'step': 'welcome'},
        },
        {
          'id': 'view-1',
          'message_id': '00000000-0000-4000-8000-000000000002',
          'payload': {'step': 'paywall'},
        },
      ]);
    });

    test('the SDK version is replaced by a placeholder in the normalized arguments only', () async {
      final rt = installContractRuntime(platform: ios);
      final pubspecVersion = RegExp(
        r'^version: (\S+)$',
        multiLine: true,
      ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);

      await Adapty().activate(configuration: AdaptyConfiguration(apiKey: 'public-key'));

      final call = rt.native.calls.singleWhere((call) => call.method == 'activate');
      expect((call.normalizedArguments['configuration']! as Map)['cross_platform_sdk_version'], '<sdk-version>');
      expect((call.arguments['configuration']! as Map)['cross_platform_sdk_version'], pubspecVersion);
      expect(rt.native.problems, isEmpty);
    });

    test('an error the SDK swallowed is a problem of the test', () async {
      final rt = installContractRuntime(platform: ios);

      await rt.native.sendEvent('flow_view_did_appear', caseName: 'without_view');
      await settle(rt.runtime);

      expect(
        rt.verify,
        throwsA(
          isA<TestFailure>().having(
            (e) => e.message,
            'message',
            allOf(contains('eventDecodeFailed'), contains('flow_view_did_appear')),
          ),
        ),
      );
      expect(rt.takeErrorRecords().map((r) => (r.kind, r.context)), [
        (AdaptyInternalErrorKind.eventDecodeFailed, 'flow_view_did_appear'),
      ]);
      rt.verify();
    });

    test('the runtime is current during the test and the SDK handles events on it', () async {
      final rt = installContractRuntime(platform: ios);
      expect(identical(AdaptyRuntime.current, rt.runtime), isTrue);
      expect(identical(AdaptyRuntime.current, before), isFalse);
    });
  });
}

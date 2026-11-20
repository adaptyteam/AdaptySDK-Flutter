// What the SDK answers when an event of the native side asks for an answer: a permission the flow asks for, a purchase
// or a restore it hands over in observer mode, and the app review it asks for. Each answer goes under the event id of
// its event, once, valid for the platform under the bridge contract, equal to what the native decoders of that platform
// read and to the golden case under contract/requests/<answer>/.
//
// The golden cases are written with ADAPTY_CONTRACT_UPDATE=1, and the writer refuses an answer that is not what the
// table says.
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/constants/method.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/contract_schema.dart';
import '../../tool/contract/src/corpus.dart';
import '../support/collecting_error_sink.dart';
import '../support/contract/contract_runtime.dart';
import 'support/golden_cases.dart';

const ios = ContractPlatform.ios;
const android = ContractPlatform.android;

const _plugin = 'Sources.AdaptyPlugin/Requests';
const _cross = 'crossplatform/src/main/java/com/adapty/internal/crossplatform';

const _permissionDecoders =
    'ios@release/4.4.1 $_plugin/Request.FlowViewDidAnswerPermission.swift:12-28 (status and detail, matched by '
    'event_id); android@4.4.0 $_cross/AdaptyCallHandler.kt:564-574, $_cross/entities.kt:109 (event_id and status '
    'required)';

String _observerDecoders(String request, int line) =>
    'ios@release/4.4.1 $_plugin/Request.$request.swift:12-16 (event_id); '
    'android@4.4.0 $_cross/AdaptyCallHandler.kt:$line, :600 (event_id required)';

final class _Handler extends AdaptyUISystemRequestsHandler {
  _Handler(this.result);

  final AdaptyUIPermissionResult result;
  var appReviews = 0;

  @override
  Future<AdaptyUIPermissionResult> handlePermission(
    AdaptyUIFlowView view,
    AdaptyUIPermission permission,
    Map<String, String>? customArgs,
  ) async => result;

  @override
  Future<void> handleAppReviewRequest(AdaptyUIFlowView view) async => appReviews++;
}

/// A resolver of observer mode that starts and finishes every purchase and restore at once.
final class _StartAndFinish implements AdaptyUIObserverModeResolver {
  @override
  void observerModeDidInitiatePurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    void Function() onStartPurchase,
    void Function() onFinishPurchase,
  ) {
    onStartPurchase();
    onFinishPurchase();
  }

  @override
  void observerModeDidInitiateRestore(
    AdaptyUIFlowView view,
    void Function() onStartRestore,
    void Function() onFinishRestore,
  ) {
    onStartRestore();
    onFinishRestore();
  }
}

/// One answer the SDK has to send: the case it is kept as and its arguments, written out from the native decoders.
typedef _Answer = ({String method, String caseName, Map<String, Object?> arguments, String source});

/// An event that asks for answers: what the app has set before it comes, the event id of its case and the answers the
/// SDK sends to it, in order.
final class _Run {
  const _Run(this.name, this.event, this.eventId, this.arrange, this.answers);

  final String name;
  final String event;
  final String eventId;
  final void Function() arrange;
  final List<_Answer> answers;
}

final _runs = [
  _Run(
    'a granted permission',
    'flow_view_did_ask_permission',
    'hr_1',
    () {
      AdaptyUI().setSystemRequestsHandler(_Handler(const AdaptyUIPermissionResult.granted()));
    },
    [
      (
        method: 'flow_view_did_answer_permission',
        caseName: 'granted',
        arguments: {'event_id': 'hr_1', 'status': 'granted'},
        source: _permissionDecoders,
      ),
    ],
  ),
  _Run(
    'a permission denied with a detail',
    'flow_view_did_ask_permission',
    'hr_1',
    () {
      AdaptyUI().setSystemRequestsHandler(_Handler(const AdaptyUIPermissionResult.denied('not now')));
    },
    [
      (
        method: 'flow_view_did_answer_permission',
        caseName: 'denied_with_detail',
        arguments: {'event_id': 'hr_1', 'status': 'denied', 'detail': 'not now'},
        source: _permissionDecoders,
      ),
    ],
  ),
  _Run('a permission without a handler', 'flow_view_did_ask_permission', 'hr_1', () {}, [
    (
      method: 'flow_view_did_answer_permission',
      caseName: 'without_handler',
      arguments: {'event_id': 'hr_1', 'status': 'denied'},
      source: _permissionDecoders,
    ),
  ]),
  _Run(
    'a purchase in observer mode',
    'flow_view_observer_did_initiate_purchase',
    'e1',
    () {
      AdaptyUI().setObserverModeResolver(_StartAndFinish());
    },
    [
      (
        method: 'observer_purchase_did_start',
        caseName: 'default',
        arguments: {'event_id': 'e1'},
        source: _observerDecoders('ObserverPurchaseDidStart', 576),
      ),
      (
        method: 'observer_purchase_did_finish',
        caseName: 'default',
        arguments: {'event_id': 'e1'},
        source: _observerDecoders('ObserverPurchaseDidFinish', 582),
      ),
    ],
  ),
  _Run(
    'a restore in observer mode',
    'flow_view_observer_did_initiate_restore',
    'e2',
    () {
      AdaptyUI().setObserverModeResolver(_StartAndFinish());
    },
    [
      (
        method: 'observer_restore_did_start',
        caseName: 'default',
        arguments: {'event_id': 'e2'},
        source: _observerDecoders('ObserverRestoreDidStart', 588),
      ),
      (
        method: 'observer_restore_did_finish',
        caseName: 'default',
        arguments: {'event_id': 'e2'},
        source: _observerDecoders('ObserverRestoreDidFinish', 594),
      ),
    ],
  ),
];

String _directory(String method) => '${Corpus.directory}/${CorpusKind.request.directory}/$method';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final schema = ContractSchema.load('.');
  final corpus = Corpus.load('.');
  final answers = [for (final run in _runs) ...run.answers];

  final recorded = <_Answer, Map<ContractPlatform, Map<String, Object?>>>{};
  tearDownAll(() {
    if (!updateGoldenCases) return;
    for (final MapEntry(key: answer, value: platforms) in recorded.entries) {
      writeGoldenCase(
        directory: _directory(answer.method),
        name: '${answer.method}/${answer.caseName}',
        caseName: answer.caseName,
        expected: {
          for (final platform in schema.methodPlatforms[answer.method]!)
            platform: (payload: answer.arguments, notes: answer.source),
        },
        recorded: platforms,
      );
    }
  });

  group('the table', () {
    test('every answer to an event is sent by a run', () {
      expect(answers.map((a) => a.method).toSet(), NativeEventResponse.values.map((r) => r.wireName).toSet());
    });

    test('every answer of a run has a case of its own', () {
      final names = answers.map((a) => '${a.method}/${a.caseName}').toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test('every golden answer is a case of the table', () {
      final names = answers.map((a) => '${a.method}/${a.caseName}').toSet();
      final methods = NativeEventResponse.values.map((r) => r.wireName).toSet();
      for (final fixture in corpus.fixtures) {
        if (fixture.kind != CorpusKind.request || !methods.contains(fixture.name)) continue;
        expect(names, contains('${fixture.name}/${fixture.caseName}'), reason: fixture.path);
      }
    });
  });

  group('each run', () {
    for (final run in _runs) {
      for (final platform in ContractPlatform.values) {
        test('${run.name} on ${platform.name}', () async {
          final rt = installContractRuntime(platform: platform);
          run.arrange();

          await rt.native.sendEvent(run.event);
          await settle(rt.runtime);

          final sent = rt.native.answersTo(run.eventId);
          expect(sent.map((call) => call.method), run.answers.map((a) => a.method), reason: 'one answer of each kind');
          expect(rt.native.calls, hasLength(sent.length), reason: 'nothing but the answers');
          for (final (call, answer) in [for (var i = 0; i < sent.length; i++) (sent[i], run.answers[i])]) {
            expect(call.normalizedArguments, answer.arguments, reason: answer.method);
            if (updateGoldenCases) {
              (recorded[answer] ??= {})[platform] = call.normalizedArguments;
              continue;
            }
            final golden = corpus.fixture(CorpusKind.request, answer.method, answer.caseName, platform);
            expect(golden, isNotNull, reason: 'no golden answer; write it with ADAPTY_CONTRACT_UPDATE=1');
            expect(golden!.payload, call.normalizedArguments, reason: golden.path);
          }
        });
      }
    }
  });

  group('event ids', () {
    for (final platform in ContractPlatform.values) {
      test('two permissions asked at once on ${platform.name} are answered each under its own event id', () async {
        final rt = installContractRuntime(platform: platform);
        AdaptyUI().setSystemRequestsHandler(_Handler(const AdaptyUIPermissionResult.granted()));

        await rt.native.sendEvent('flow_view_did_ask_permission', eventId: 'hr_a');
        await rt.native.sendEvent('flow_view_did_ask_permission', eventId: 'hr_b');
        await settle(rt.runtime);

        expect(rt.native.answersTo('hr_a').single.arguments, {'event_id': 'hr_a', 'status': 'granted'});
        expect(rt.native.answersTo('hr_b').single.arguments, {'event_id': 'hr_b', 'status': 'granted'});
      });

      test('two purchases in observer mode on ${platform.name} are answered each under its own event id', () async {
        final rt = installContractRuntime(platform: platform);
        AdaptyUI().setObserverModeResolver(_StartAndFinish());

        await rt.native.sendEvent('flow_view_observer_did_initiate_purchase', eventId: 'e_a');
        await rt.native.sendEvent('flow_view_observer_did_initiate_purchase', eventId: 'e_b');
        await settle(rt.runtime);

        for (final id in ['e_a', 'e_b']) {
          expect(rt.native.answersTo(id).map((call) => [call.method, call.arguments]), [
            [
              'observer_purchase_did_start',
              {'event_id': id},
            ],
            [
              'observer_purchase_did_finish',
              {'event_id': id},
            ],
          ]);
        }
      });
    }
  });

  group('no answer', () {
    for (final event in ['flow_view_observer_did_initiate_purchase', 'flow_view_observer_did_initiate_restore']) {
      test('$event without a resolver is not answered: only the resolver can start and finish it', () async {
        final rt = installContractRuntime(platform: ios);

        await rt.native.sendEvent(event);
        await settle(rt.runtime);

        expect(rt.native.calls, isEmpty);
      });
    }
  });

  group('the app review', () {
    for (final platform in ContractPlatform.values) {
      test('asked for without a handler on ${platform.name}, the SDK asks the native side for it', () async {
        final rt = installContractRuntime(platform: platform);

        await rt.native.sendEvent('flow_view_did_request_app_review');
        await settle(rt.runtime);

        final request = rt.native.calls.single;
        expect(request.method, 'adapty_ui_request_app_review');
        expect(request.normalizedArguments, const <String, Object?>{});
        expect(
          corpus.fixture(CorpusKind.request, 'adapty_ui_request_app_review', 'default', platform)?.payload,
          request.normalizedArguments,
          reason: 'the golden request of the method',
        );
      });
    }

    test('asked for with a handler, it goes to the handler and not to the native side', () async {
      final rt = installContractRuntime(platform: ios);
      final handler = _Handler(const AdaptyUIPermissionResult.granted());
      AdaptyUI().setSystemRequestsHandler(handler);

      await rt.native.sendEvent('flow_view_did_request_app_review');
      await settle(rt.runtime);

      expect(handler.appReviews, 1);
      expect(rt.native.calls, isEmpty);
    });
  });
}

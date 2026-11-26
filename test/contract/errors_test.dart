// What the SDK makes of an answer of the native side that is not a success: an error reaches the app as the same
// AdaptyError for every method, and an answer the contract rejects fails the call as an internal plugin error, unless
// the SDK does not read what is wrong with it.
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/runtime/adapty_internal_error_sink.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/contract_schema.dart';
import '../../tool/contract/src/corpus.dart';
import '../support/contract/contract_runtime.dart';
import 'support/api_calls.dart';
import 'support/golden_cases.dart';

final _schema = ContractSchema.load('.');
final _corpus = Corpus.load('.');

/// What a native error looks like, from the corpus: the error case of `get_profile` on iOS.
Object? get _errorEnvelope => _corpus.fixture(CorpusKind.response, 'get_profile', 'error', ios)!.payload;

/// The methods whose answer the contract never makes an error.
const _neverAnError = {'is_activated', 'present_code_redemption_sheet', 'set_log_level'};

/// The corpus of this repository with the native error as the case `error` of every other method on iOS.
final _corpusWithErrors = Corpus(
  fixtures: [
    ..._corpus.fixtures,
    for (final method in _sentMethods)
      if (!_neverAnError.contains(method) && _corpus.fixture(CorpusKind.response, method, 'error', ios) == null)
        CorpusFixture(
          kind: CorpusKind.response,
          name: method,
          caseName: 'error',
          platform: ios,
          path: 'responses/$method/error.ios.json (made by the test)',
          provenance: {'source': 'hand', 'native': repositoryRefs.ios},
          expect: null,
          notes: 'the error case of get_profile on iOS',
          payload: _errorEnvelope,
        ),
  ],
  baseline: _corpus.baseline,
  problems: const [],
);

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

/// The answers to events, which the SDK sends on its own when the native side asks: the event that makes it send each.
final Map<String, Future<void> Function(ContractRuntime rt)> _answers = {
  'flow_view_did_answer_permission': (rt) => _send(rt, 'flow_view_did_ask_permission'),
  'observer_purchase_did_start': (rt) => _send(rt, 'flow_view_observer_did_initiate_purchase', observer: true),
  'observer_purchase_did_finish': (rt) => _send(rt, 'flow_view_observer_did_initiate_purchase', observer: true),
  'observer_restore_did_start': (rt) => _send(rt, 'flow_view_observer_did_initiate_restore', observer: true),
  'observer_restore_did_finish': (rt) => _send(rt, 'flow_view_observer_did_initiate_restore', observer: true),
};

Future<void> _send(ContractRuntime rt, String event, {bool observer = false}) async {
  if (observer) AdaptyUI().setObserverModeResolver(_StartAndFinish());
  await rt.native.sendEvent(event);
  await pumpEventQueue();
}

/// Every method the SDK sends: by a call of the public API or as an answer to an event.
final _sentMethods = {for (final call in apiCalls) call.method, ..._answers.keys};

/// A call of the public API that sends [method] on [platform].
ApiCall _callOf(String method, ContractPlatform platform) =>
    apiCalls.firstWhere((call) => call.method == method && call.expected[platform] != null);

/// The methods whose success value the SDK does not read: they answer nothing to the app.
const _successNotRead = {
  'activate',
  'adapty_ui_destroy_flow_view',
  'adapty_ui_dismiss_flow_view',
  'adapty_ui_dismiss_onboarding_view',
  'adapty_ui_open_url',
  'adapty_ui_present_flow_view',
  'adapty_ui_present_onboarding_view',
  'adapty_ui_request_app_review',
  'adapty_ui_send_app_message',
  'flow_view_did_answer_permission',
  'identify',
  'log_show_flow',
  'logout',
  'observer_purchase_did_finish',
  'observer_purchase_did_start',
  'observer_restore_did_finish',
  'observer_restore_did_start',
  'open_web_paywall',
  'preload_flows',
  'preload_flows_for_default_audience',
  'present_code_redemption_sheet',
  'report_transaction',
  'set_fallback',
  'set_integration_identifiers',
  'set_log_level',
  'show_store_messages',
  'update_collecting_refund_data_consent',
  'update_external_attribution_data',
  'update_profile',
  'update_refund_preference',
};

/// The cases the contract rejects that the SDK reads as something an app can use, with what the app gets.
const _readAnyway = {
  'adapty_ui_show_dialog/unknown_action': 'an action it does not know is the primary one',
  'get_flow/without_variations': 'a flow without variations has no paywalls',
  'get_flow_for_default_audience/without_variations': 'a flow without variations has no paywalls',
  'make_promoted_purchase/unknown_type': 'a purchase result type it does not know is a pending purchase',
};

/// The event cases the contract rejects that the SDK reads anyway, with what it does with them.
const _eventsReadAnyway = {
  'did_receive_promoted_purchase/without_purchase_intent_id': 'a promoted product without a purchase intent id',
  'flow_view_did_finish_purchase/unknown_result': 'a purchase result type it does not know is a pending purchase',
  'flow_view_did_receive_analytic_event/without_params': 'an analytic event without parameters has empty ones',
};

/// The event cases the contract rejects that the SDK drops because they carry a value it does not know, reporting
/// that instead of an event it could not read, with the value as the record names it.
const _eventsDroppedForUnknownValue = {
  'onboarding_on_state_updated_action/unknown_element_type': 'element type "slider"',
  'onboarding_on_state_updated_action/unknown_input_type': 'input type "phone"',
};

/// The warning a purchase result type the SDK does not know, [type], is read anyway with.
String _purchaseResultWarning(String type) =>
    'Adapty received a purchase result type this SDK version doesn\'t know, "$type", and reads it as pending.';

/// The warning lines in the log of [rt].
List<String> _warnings(ContractRuntime rt) => [
  for (final (level, message) in rt.log.lines)
    if (level == AdaptyLogLevel.warn) message,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AdaptyLogLevel logLevel;
  setUp(() {
    // activate and setLogLevel change the level of the logger.
    logLevel = AdaptyLogger.logLevel;
    AdaptyLogger.logLevel = AdaptyLogLevel.info;
  });
  tearDown(() => AdaptyLogger.logLevel = logLevel);

  group('a native error reaches the app as the same AdaptyError', () {
    test('the error answers every method by the contract, but those that never answer an error', () {
      for (final method in _sentMethods) {
        final report = _schema.validateResponse(method, _errorEnvelope, platform: ios);
        expect(report.isValid, !_neverAnError.contains(method), reason: '$method: ${report.describe()}');
      }
    });

    for (final method in _sentMethods.difference(_neverAnError).toList()..sort()) {
      test(method, () async {
        final rt = installContractRuntime(platform: ios, corpus: _corpusWithErrors);
        rt.native.respond(method, 'error');

        final AdaptyError error;
        if (_answers[method] case final send?) {
          await send(rt);
          final records = rt.takeErrorRecords();
          expect(records.map((r) => (r.kind, r.context)), [(AdaptyInternalErrorKind.replyFailed, method)]);
          error = records.single.error as AdaptyError;
        } else {
          error = await _callOf(method, ios)
              .call(rt)
              .then<AdaptyError>(
                (_) => fail('$method did not fail'),
                onError: (Object e) => e is AdaptyError ? e : fail('$method failed with $e'),
              );
        }

        expect(
          (error.code, error.message, error.detail),
          (
            2002,
            'something failed',
            '{"adapty_code":2002,"message":"something failed","detail":"AdaptyError.notActivated"}',
          ),
        );
      });
    }
  });

  group('an answer the contract rejects', () {
    final negatives = [
      for (final f in _corpus.fixtures)
        if (f.kind == CorpusKind.response && f.isNegative) f,
    ]..sort((a, b) => a.path.compareTo(b.path));

    test('is a case of a method the SDK sends, with one way to read it', () {
      for (final f in negatives) {
        expect(_sentMethods, contains(f.name), reason: f.path);
        expect(_successNotRead.contains(f.name) && _readAnyway.containsKey('${f.name}/${f.caseName}'), isFalse);
      }
      expect(_readAnyway.keys, everyElement(isIn([for (final f in negatives) '${f.name}/${f.caseName}'])));
    });

    for (final fixture in negatives) {
      final name = '${fixture.name}/${fixture.caseName}';
      for (final platform in fixture.platform == null ? _schema.methodPlatforms[fixture.name]! : {fixture.platform!}) {
        final ignored = _successNotRead.contains(fixture.name) || _readAnyway.containsKey(name);
        test(
          '$name on ${platform.name} ${ignored ? 'is left alone: ${_readAnyway[name] ?? 'the SDK does not read the success value'}' : 'fails the call as an internal plugin error'}',
          () async {
            final rt = installContractRuntime(platform: platform);
            rt.native.respond(fixture.name, fixture.caseName);

            Object? outcome;
            if (_answers[fixture.name] case final send?) {
              await send(rt);
              expect(rt.takeErrorRecords(), isEmpty);
            } else {
              outcome = await _callOf(
                fixture.name,
                platform,
              ).call(rt).then<Object?>((_) => null, onError: (Object e) => e);
            }
            expect(rt.native.calls.where((c) => c.method == fixture.name), hasLength(1));
            if (ignored) {
              expect(outcome, isNull);
            } else {
              expect(
                outcome,
                isA<AdaptyError>()
                    .having((e) => e.code, 'code', AdaptyErrorCode.internalPluginError)
                    .having((e) => e.message, 'message', 'Internal plugin error in Adapty.${fixture.name}()'),
              );
            }
          },
        );
      }
    }

    test('an unknown action of a dialog is the primary one', () async {
      final rt = installContractRuntime(platform: ios);
      rt.native.respond('adapty_ui_show_dialog', 'unknown_action');
      final view = await AdaptyUI().createFlowView(flow: await Adapty().getFlow(placementId: 'placement-id'));

      final action = await view.showDialog(title: 'Title', content: 'Content', primaryActionTitle: 'OK');

      expect(action, AdaptyUIDialogActionType.primary);
    });

    for (final method in ['get_flow', 'get_flow_for_default_audience']) {
      test('$method without variations gives a flow without paywalls', () async {
        final rt = installContractRuntime(platform: ios);
        rt.native.respond(method, 'without_variations');

        final flow = method == 'get_flow'
            ? await Adapty().getFlow(placementId: 'placement-id')
            : await Adapty().getFlowForDefaultAudience(placementId: 'placement-id');

        expect(flow.paywalls, isEmpty);
        expect(flow.instanceIdentity, 'flow-1');
      });
    }

    test('a purchase result type it does not know is a pending purchase, with one warning', () async {
      final rt = installContractRuntime(platform: ios);
      rt.native.respond('make_promoted_purchase', 'unknown_type');
      final promoted = Adapty().didReceivePromotedPurchaseStream.first;
      await rt.native.sendEvent('did_receive_promoted_purchase');

      final result = await Adapty().makePromotedPurchase(product: await promoted);

      expect(result, isA<AdaptyPurchaseResultPending>());
      expect(_warnings(rt), [_purchaseResultWarning('deferred')]);
    });
  });

  group('an event the contract rejects', () {
    final negatives = [
      for (final f in _corpus.fixtures)
        if (f.kind == CorpusKind.event && f.isNegative) f,
    ]..sort((a, b) => a.path.compareTo(b.path));

    test('every case read anyway is a case the contract rejects', () {
      expect(_eventsReadAnyway.keys, everyElement(isIn([for (final f in negatives) '${f.name}/${f.caseName}'])));
    });

    test('every case dropped for a value it does not know is a case the contract rejects that is not read anyway', () {
      expect(
        _eventsDroppedForUnknownValue.keys,
        everyElement(isIn([for (final f in negatives) '${f.name}/${f.caseName}'])),
      );
      expect(_eventsDroppedForUnknownValue.keys, everyElement(isNot(isIn(_eventsReadAnyway.keys))));
    });

    for (final fixture in negatives) {
      final name = '${fixture.name}/${fixture.caseName}';
      for (final platform in fixture.platform == null ? _schema.eventPlatforms[fixture.name]! : {fixture.platform!}) {
        final readAnyway = _eventsReadAnyway[name];
        final dropped = _eventsDroppedForUnknownValue[name];
        test(
          '$name on ${platform.name} ${readAnyway != null
              ? 'is read anyway: $readAnyway'
              : dropped != null
              ? 'is dropped for a value it does not know: $dropped'
              : 'is an event the SDK could not read'}',
          () async {
            final rt = installContractRuntime(platform: platform);
            // An app that listens gets a promoted product; the SDK does not buy it on its own.
            final promoted = Adapty().didReceivePromotedPurchaseStream.listen((_) {});
            addTearDown(promoted.cancel);

            await rt.native.sendEvent(fixture.name, caseName: fixture.caseName);
            await pumpEventQueue();

            final records = rt.takeErrorRecords();
            expect(records.map((r) => (r.kind, r.context)), [
              if (readAnyway == null && dropped == null) (AdaptyInternalErrorKind.eventDecodeFailed, fixture.name),
              if (dropped != null) (AdaptyInternalErrorKind.unknownEventValue, fixture.name),
            ]);
            if (dropped != null) {
              expect(records.single.logLevel, AdaptyLogLevel.warn);
              expect(
                records.single.message,
                "Adapty dropped an onboarding state update: this SDK version doesn't know its $dropped.",
              );
              expect(rt.log.lines.where((line) => line.$1 == AdaptyLogLevel.warn), isEmpty);
            }
          },
        );
      }
    }

    test('an analytic event without parameters reaches the observer with empty ones', () async {
      final rt = installContractRuntime(platform: ios);
      final observer = _FlowEvents();
      AdaptyUI().setFlowsEventsObserver(observer);

      await rt.native.sendEvent('flow_view_did_receive_analytic_event', caseName: 'without_params');
      await pumpEventQueue();

      expect(observer.received.map((e) => (e.$1, e.$2)), [('view-1', 'analytic-1')]);
      expect(observer.received.single.$3, isEmpty);
    });

    test(
      'a flow purchase with a result type it does not know reaches the observer as pending, with one warning',
      () async {
        final rt = installContractRuntime(platform: ios);
        final observer = _FlowEvents();
        AdaptyUI().setFlowsEventsObserver(observer);

        await rt.native.sendEvent('flow_view_did_finish_purchase', caseName: 'unknown_result');
        await pumpEventQueue();

        expect(observer.purchases, [isA<AdaptyPurchaseResultPending>()]);
        expect(_warnings(rt), [_purchaseResultWarning('refunded')]);
      },
    );

    test('a promoted product without a purchase intent id reaches the app, and buying it sends none', () async {
      final rt = installContractRuntime(platform: ios);
      final products = <AdaptyPromotedProduct>[];
      final promoted = Adapty().didReceivePromotedPurchaseStream.listen(products.add);
      addTearDown(promoted.cancel);

      await rt.native.sendEvent('did_receive_promoted_purchase', caseName: 'without_purchase_intent_id');
      await pumpEventQueue();
      expect(products.map((p) => p.vendorProductId), ['promoted.product']);

      await Adapty().makePromotedPurchase(product: products.single);

      final product = rt.native.calls.single.arguments['product']! as Map<String, Object?>;
      expect(product.containsKey('purchase_intent_id'), isFalse);
      expect(rt.native.takeProblems(), [
        contains('/product: required at #/\$defs/AdaptyPromotedProduct.Request (missing "purchase_intent_id")'),
      ]);
    });
  });
}

/// Keeps the view id, the name and the parameters of every analytic event of a flow, and every purchase result.
final class _FlowEvents extends AdaptyUIFlowsEventsObserver {
  final received = <(String, String, Map<String, dynamic>)>[];
  final purchases = <AdaptyPurchaseResult>[];

  @override
  void flowViewDidReceiveAnalyticEvent(AdaptyUIFlowView view, String name, Map<String, dynamic> params) =>
      received.add((view.id, name, params));

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) => purchases.add(purchaseResult);

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) {}
}

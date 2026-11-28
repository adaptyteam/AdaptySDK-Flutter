/// What happens when a call the SDK makes and does not wait for fails: the default handling of flow events (closing the
/// view, opening a URL) and the start and finish callbacks the Observer mode resolver gets. The error goes to the error
/// sink of the runtime the event arrived on and never surfaces as an uncaught error.
///
/// Every view id here is not one of an embedded view, so its events go to the default handling and not to a widget.
import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/runtime/adapty_internal_error_sink.dart';
import 'package:adapty_flutter/src/runtime/adapty_log_sink.dart';
import 'package:adapty_flutter/src/runtime/adapty_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/capturing_log_sink.dart';
import 'support/collecting_error_sink.dart';
import 'support/fake_transport.dart';
import 'support/test_runtime.dart';

const _view = {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'};

const _close = {
  'view': _view,
  'action': {'type': 'close'},
};

const _openUrl = {
  'view': _view,
  'action': {'type': 'open_url', 'value': 'https://adapty.io', 'open_in': 'browser_out_app'},
};

const _error = {
  'view': _view,
  'error': {'adapty_code': 4106, 'message': 'the flow failed'},
};

/// A yearly subscription as the iOS SDK reports it.
const _product = {
  'vendor_product_id': 'com.app.yearly',
  'flow_product_id': 'p1',
  'adapty_product_id': 'adapty-yearly',
  'access_level_id': 'premium',
  'product_type': 'annual',
  'paywall_product_index': 0,
  'paywall_variation_id': 'variation-id',
  'paywall_ab_test_name': 'ab-test',
  'paywall_name': 'Paywall',
  'localized_description': 'Premium for a year',
  'localized_title': 'Premium',
  'is_family_shareable': false,
  'region_code': 'DE',
  'price': {'amount': 119.88, 'currency_code': 'EUR', 'currency_symbol': '€', 'localized_string': '119,88 €'},
  'subscription': {
    'group_identifier': '21345678',
    'period': {'unit': 'year', 'number_of_units': 1},
    'localized_period': '1 year',
  },
};

/// Keeps the action handling it inherits from [AdaptyUIFlowsEventsObserver].
class _InheritingObserver extends AdaptyUIFlowsEventsObserver {
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

/// Keeps the callbacks it gets, by the wire name of the call each one makes.
class _Resolver extends AdaptyUIObserverModeResolver {
  final callbacks = <String, void Function()>{};

  @override
  void observerModeDidInitiatePurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    void Function() onStartPurchase,
    void Function() onFinishPurchase,
  ) {
    callbacks['observer_purchase_did_start'] = onStartPurchase;
    callbacks['observer_purchase_did_finish'] = onFinishPurchase;
  }

  @override
  void observerModeDidInitiateRestore(
    AdaptyUIFlowView view,
    void Function() onStartRestore,
    void Function() onFinishRestore,
  ) {
    callbacks['observer_restore_did_start'] = onStartRestore;
    callbacks['observer_restore_did_finish'] = onFinishRestore;
  }
}

/// Runs [body] in a guarded zone, lets the work it started on [rt] run to the end and returns what escaped the zone
/// uncaught, together with what [body] itself threw: a failure inside the zone would otherwise never reach the test.
///
/// A resolver callback that is not meant to be waited for is called from a block body, as an app calls a
/// `void Function()`: an arrow body would hand what the callback returns to `await`.
Future<List<Object>> _uncaughtIn(AdaptyRuntime rt, FutureOr<void> Function() body) async {
  final caught = <Object>[];
  await runZonedGuarded(() async {
    try {
      await body();
    } catch (e) {
      caught.add(e);
    }
    await settle(rt);
  }, (error, _) => caught.add(error));
  return caught;
}

Matcher _adaptyError(int code) => isA<AdaptyError>().having((e) => e.code, 'code', code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('default handling of flow events', () {
    test('a failing default dismiss is reported as backgroundCallFailed labelled default_observer.dismiss', () async {
      final sink = CollectingErrorSink();
      final fake = FakeTransport()..replyError('adapty_ui_dismiss_flow_view', code: 3001);
      final rt = installTestRuntime(transport: fake, errorSink: sink);

      final caught = await _uncaughtIn(rt, () => fake.deliver('flow_view_did_perform_action', _close));

      expect(caught, isEmpty);
      expect(fake.calls.map((call) => call.$1), ['adapty_ui_dismiss_flow_view']);
      expect(sink.records, hasLength(1));
      final record = sink.records.single;
      expect(record.kind, AdaptyInternalErrorKind.backgroundCallFailed);
      expect(record.context, 'default_observer.dismiss');
      expect(record.correlationId, isNull);
      expect(record.error, _adaptyError(3001));
    });

    test('a failing default openUrl is reported as backgroundCallFailed labelled default_observer.open_url', () async {
      final sink = CollectingErrorSink();
      final fake = FakeTransport()..replyError('adapty_ui_open_url', code: 3001);
      final rt = installTestRuntime(transport: fake, errorSink: sink);

      final caught = await _uncaughtIn(rt, () => fake.deliver('flow_view_did_perform_action', _openUrl));

      expect(caught, isEmpty);
      expect(fake.calls.map((call) => call.$1), ['adapty_ui_open_url']);
      expect(sink.records, hasLength(1));
      final record = sink.records.single;
      expect(record.kind, AdaptyInternalErrorKind.backgroundCallFailed);
      expect(record.context, 'default_observer.open_url');
      expect(record.correlationId, isNull);
      expect(record.error, _adaptyError(3001));
    });

    test('an error of a modal view without an observer makes no call and reports nothing', () async {
      final sink = CollectingErrorSink();
      final fake = FakeTransport()..replyError('adapty_ui_dismiss_flow_view', code: 3001);
      final rt = installTestRuntime(transport: fake, errorSink: sink);

      final caught = await _uncaughtIn(rt, () => fake.deliver('flow_view_did_receive_error', _error));

      expect(caught, isEmpty);
      expect(fake.calls, isEmpty);
      expect(sink.records, isEmpty);
    });

    test('a failing dismiss of a global observer that inherits flowViewDidPerformAction is reported', () async {
      final sink = CollectingErrorSink();
      final fake = FakeTransport()..replyError('adapty_ui_dismiss_flow_view', code: 3001);
      final rt = installTestRuntime(transport: fake, errorSink: sink);
      AdaptyUI().setFlowsEventsObserver(_InheritingObserver());

      final caught = await _uncaughtIn(rt, () => fake.deliver('flow_view_did_perform_action', _close));

      expect(caught, isEmpty);
      expect(fake.calls.map((call) => call.$1), ['adapty_ui_dismiss_flow_view']);
      expect(sink.records, hasLength(1));
      final record = sink.records.single;
      expect(record.kind, AdaptyInternalErrorKind.backgroundCallFailed);
      expect(record.context, 'default_observer.dismiss');
      expect(record.error, _adaptyError(3001));
    });

    test('a failing openUrl of a global observer that inherits flowViewDidPerformAction is reported', () async {
      final sink = CollectingErrorSink();
      final fake = FakeTransport()..replyError('adapty_ui_open_url', code: 3001);
      final rt = installTestRuntime(transport: fake, errorSink: sink);
      AdaptyUI().setFlowsEventsObserver(_InheritingObserver());

      final caught = await _uncaughtIn(rt, () => fake.deliver('flow_view_did_perform_action', _openUrl));

      expect(caught, isEmpty);
      expect(fake.calls.map((call) => call.$1), ['adapty_ui_open_url']);
      expect(sink.records, hasLength(1));
      final record = sink.records.single;
      expect(record.kind, AdaptyInternalErrorKind.backgroundCallFailed);
      expect(record.context, 'default_observer.open_url');
      expect(record.error, _adaptyError(3001));
    });

    test('a failing default dismiss is logged as an error', () async {
      final logSink = CapturingLogSink();
      final fake = FakeTransport()
        ..replyError('adapty_ui_dismiss_flow_view', code: 3001, message: 'the view is not found');
      final rt = installTestRuntime(transport: fake, logErrors: true, logSink: logSink);

      final caught = await _uncaughtIn(rt, () => fake.deliver('flow_view_did_perform_action', _close));

      expect(caught, isEmpty);
      expect(logSink.lines, [
        (
          AdaptyLogLevel.error,
          'Adapty background call default_observer.dismiss failed: '
              '(code: 3001, message: the view is not found, detail: null)',
        ),
      ]);
    });

    test('the default dismiss calls the native side in the turn of the event', () async {
      final fake = FakeTransport();
      final rt = installTestRuntime(transport: fake, errorSink: CollectingErrorSink());

      final delivered = fake.deliver('flow_view_did_perform_action', _close);
      final callsInTheTurn = fake.calls.map((call) => call.$1).toList();
      await delivered;
      await settle(rt);

      expect(callsInTheTurn, ['adapty_ui_dismiss_flow_view']);
    });

    test('the default dismiss of an event on runtime A is reported to A', () async {
      final sinkA = CollectingErrorSink();
      final fakeA = FakeTransport()..replyError('adapty_ui_dismiss_flow_view', code: 3001);
      final a = installTestRuntime(transport: fakeA, errorSink: sinkA);
      final sinkB = CollectingErrorSink();
      final fakeB = FakeTransport();
      installTestRuntime(transport: fakeB, errorSink: sinkB);

      final caught = await _uncaughtIn(a, () => fakeA.deliver('flow_view_did_perform_action', _close));

      expect(caught, isEmpty);
      expect(fakeA.calls.map((call) => call.$1), ['adapty_ui_dismiss_flow_view']);
      expect(fakeB.calls, isEmpty);
      expect(sinkA.records, hasLength(1));
      expect(sinkA.records.single.kind, AdaptyInternalErrorKind.backgroundCallFailed);
      expect(sinkA.records.single.context, 'default_observer.dismiss');
      expect(sinkB.records, isEmpty);
    });
  });

  group('Observer mode resolver callbacks', () {
    /// Installs a runtime over [fake] with [sink], [logSink] and a [_Resolver], delivers a purchase with event id `e1`
    /// and a restore with event id `e2`, and returns the resolver.
    Future<_Resolver> initiate(FakeTransport fake, AdaptyInternalErrorSink sink, {AdaptyLogSink? logSink}) async {
      installTestRuntime(transport: fake, errorSink: sink, logSink: logSink);
      final resolver = _Resolver();
      AdaptyUI().setObserverModeResolver(resolver);
      await fake.deliver('flow_view_observer_did_initiate_purchase', {
        'event_id': 'e1',
        'view': _view,
        'product': _product,
      });
      await fake.deliver('flow_view_observer_did_initiate_restore', {'event_id': 'e2', 'view': _view});
      return resolver;
    }

    test('a failed finish call is reported as replyFailed, not uncaught', () async {
      final sink = CollectingErrorSink();
      final fake = FakeTransport()..replyError('observer_purchase_did_finish', code: 2002);
      final resolver = await initiate(fake, sink);
      final rt = AdaptyRuntime.current;

      final caught = await _uncaughtIn(rt, () {
        resolver.callbacks['observer_purchase_did_finish']!();
      });

      expect(caught, isEmpty);
      expect(fake.calls.map((call) => call.$1), ['observer_purchase_did_finish']);
      expect(sink.records, hasLength(1));
      final record = sink.records.single;
      expect(record.kind, AdaptyInternalErrorKind.replyFailed);
      expect(record.context, 'observer_purchase_did_finish');
      expect(record.correlationId, 'e1');
      expect(record.error, _adaptyError(2002));
    });

    test('an app that waits for a callback gets the answer of the native side when it arrives', () async {
      final sink = CollectingErrorSink();
      final fake = FakeTransport();
      final resolver = await initiate(fake, sink);
      final rt = AdaptyRuntime.current;
      final held = fake.hold('observer_purchase_did_finish');

      var completed = false;
      final waited = Future<void>(() => resolver.callbacks['observer_purchase_did_finish']!()).then((_) {
        completed = true;
      });
      await pumpEventQueue();
      final completedBeforeTheAnswer = completed;
      held.complete();
      await waited;
      await settle(rt);

      expect(completedBeforeTheAnswer, isFalse);
      expect(completed, isTrue);
      expect(sink.records, isEmpty);
    });

    for (final (method, eventId) in [
      ('observer_purchase_did_start', 'e1'),
      ('observer_purchase_did_finish', 'e1'),
      ('observer_restore_did_start', 'e2'),
      ('observer_restore_did_finish', 'e2'),
    ]) {
      test(
        'an app that waits for a failed $method callback gets the error, and the failure is still reported',
        () async {
          final sink = CollectingErrorSink();
          final fake = FakeTransport()..replyError(method, code: 2002);
          final resolver = await initiate(fake, sink);
          final rt = AdaptyRuntime.current;

          final caught = await _uncaughtIn(rt, () async {
            await expectLater(Future<void>(() => resolver.callbacks[method]!()), throwsA(_adaptyError(2002)));
          });

          expect(caught, isEmpty);
          expect(sink.records, hasLength(1));
          expect(sink.records.single.kind, AdaptyInternalErrorKind.replyFailed);
          expect(sink.records.single.context, method);
          expect(sink.records.single.correlationId, eventId);
        },
      );
    }

    for (final method in [
      'observer_purchase_did_start',
      'observer_purchase_did_finish',
      'observer_restore_did_start',
      'observer_restore_did_finish',
    ]) {
      test('a failed $method call is logged as an error naming the call', () async {
        final logSink = CapturingLogSink();
        final fake = FakeTransport()..replyError(method, code: 2002, message: 'the answer failed');
        final resolver = await initiate(fake, LoggingErrorSink(logSink), logSink: logSink);
        final rt = AdaptyRuntime.current;

        final caught = await _uncaughtIn(rt, () {
          resolver.callbacks[method]!();
        });

        expect(caught, isEmpty);
        expect(logSink.lines, [
          (AdaptyLogLevel.error, 'Error in Adapty.$method(): (code: 2002, message: the answer failed, detail: null)'),
        ]);
      });
    }

    test('a failed call of each callback is reported under its wire name with the event id of its event', () async {
      final sink = CollectingErrorSink();
      final fake = FakeTransport();
      for (final method in [
        'observer_purchase_did_start',
        'observer_purchase_did_finish',
        'observer_restore_did_start',
        'observer_restore_did_finish',
      ]) {
        fake.replyError(method, code: 2002);
      }
      final resolver = await initiate(fake, sink);
      final rt = AdaptyRuntime.current;

      final caught = await _uncaughtIn(rt, () {
        resolver.callbacks['observer_purchase_did_start']!();
        resolver.callbacks['observer_purchase_did_finish']!();
        resolver.callbacks['observer_restore_did_start']!();
        resolver.callbacks['observer_restore_did_finish']!();
      });

      expect(caught, isEmpty);
      expect(
        [for (final record in sink.records) (record.kind, record.context, record.correlationId)],
        unorderedEquals([
          (AdaptyInternalErrorKind.replyFailed, 'observer_purchase_did_start', 'e1'),
          (AdaptyInternalErrorKind.replyFailed, 'observer_purchase_did_finish', 'e1'),
          (AdaptyInternalErrorKind.replyFailed, 'observer_restore_did_start', 'e2'),
          (AdaptyInternalErrorKind.replyFailed, 'observer_restore_did_finish', 'e2'),
        ]),
      );
    });

    test('each callback calls the native side in the turn it is called', () async {
      final sink = CollectingErrorSink();
      final fake = FakeTransport();
      final resolver = await initiate(fake, sink);
      final rt = AdaptyRuntime.current;

      final callsInTheTurn = <(String, Object?)>[];
      for (final method in [
        'observer_purchase_did_start',
        'observer_purchase_did_finish',
        'observer_restore_did_start',
        'observer_restore_did_finish',
      ]) {
        resolver.callbacks[method]!();
        final (name, arguments) = fake.calls.last;
        callsInTheTurn.add((name, arguments['event_id']));
      }
      await settle(rt);

      expect(callsInTheTurn, [
        ('observer_purchase_did_start', 'e1'),
        ('observer_purchase_did_finish', 'e1'),
        ('observer_restore_did_start', 'e2'),
        ('observer_restore_did_finish', 'e2'),
      ]);
      expect(sink.records, isEmpty);
    });

    test('a failed finish call is reported to the runtime of its event, not the current one', () async {
      final sinkA = CollectingErrorSink();
      final fakeA = FakeTransport()..replyError('observer_purchase_did_finish', code: 2002);
      final resolver = await initiate(fakeA, sinkA);
      final a = AdaptyRuntime.current;
      final sinkB = CollectingErrorSink();
      final fakeB = FakeTransport();
      installTestRuntime(transport: fakeB, errorSink: sinkB);

      final caught = await _uncaughtIn(a, () {
        resolver.callbacks['observer_purchase_did_finish']!();
      });

      expect(caught, isEmpty);
      expect(fakeA.calls.map((call) => call.$1), ['observer_purchase_did_finish']);
      expect(fakeB.calls, isEmpty);
      expect(sinkA.records, hasLength(1));
      expect(sinkA.records.single.context, 'observer_purchase_did_finish');
      expect(sinkA.records.single.correlationId, 'e1');
      expect(sinkB.records, isEmpty);
    });
  });
}

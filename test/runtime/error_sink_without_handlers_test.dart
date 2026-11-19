/// The errors the SDK swallows while it handles native events go to the error sink of the runtime, with their kind,
/// the event or call they came from and the request id when one was read.
///
/// No system requests handler and no observer mode resolver is ever set in this file: until they move into the
/// runtime they live in the `AdaptyUI()` singleton, and the cases with them are in `error_sink_handlers_test.dart`.
import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/runtime/adapty_internal_error_sink.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/collecting_error_sink.dart';
import '../support/fake_transport.dart';
import '../support/test_runtime.dart';

const _view = {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'};

const _promotedProduct = {
  'vendor_product_id': 'promoted.product',
  'localized_description': 'Promoted product',
  'localized_title': 'Promoted',
  'is_family_shareable': true,
  'region_code': 'US',
  'price': {'amount': 9.99, 'currency_code': 'USD', 'currency_symbol': r'$', 'localized_string': r'$9.99'},
};

class _ThrowingWidget extends AdaptyUIFlowsEventsObserver {
  @override
  void flowViewDidFinishPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product, AdaptyPurchaseResult result) {}

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) => throw StateError('widget boom');
}

List<String> _printed(void Function() body) {
  final lines = <String>[];
  runZoned(body, zoneSpecification: ZoneSpecification(print: (_, _, _, line) => lines.add(line)));
  return lines;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LoggingErrorSink prints event failures exactly as before', () {
    final rt = installTestRuntime();

    final lines = _printed(
      () => rt.diagnostics.errorSink.report(
        const AdaptyInternalErrorRecord(
          AdaptyInternalErrorKind.eventDecodeFailed,
          'boom',
          context: 'flow_view_did_appear',
        ),
      ),
    );

    expect(lines, [endsWith('- ERROR: Error in Adapty._handleIncomingMethodCall: boom')]);
  });

  test('LoggingErrorSink prints a replay failure with its own place', () {
    final rt = installTestRuntime();

    final lines = _printed(
      () => rt.diagnostics.errorSink.report(
        const AdaptyInternalErrorRecord(
          AdaptyInternalErrorKind.observerThrew,
          'boom',
          context: 'flow_view_did_receive_error',
          where: 'flowViewDidReceiveError',
        ),
      ),
    );

    expect(lines, [endsWith('- ERROR: Error in flowViewDidReceiveError: boom')]);
  });

  test('a throwing widget on a replayed error is reported as observerThrew', () async {
    final sink = CollectingErrorSink();
    final fake = FakeTransport();
    installTestRuntime(transport: fake, errorSink: sink);
    addTearDown(() => AdaptyUI().unregisterFlowEventsListener('flutter_native_9'));

    await fake.deliver('flow_view_did_receive_error', {
      'view': {'id': 'flutter_native_9', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
      'error': {'adapty_code': 4001, 'message': 'not supported'},
    });
    expect(sink.records, isEmpty);

    AdaptyUI().registerFlowEventsListener(_ThrowingWidget(), 'flutter_native_9');

    expect(sink.records, hasLength(1));
    final record = sink.records.single;
    expect(record.kind, AdaptyInternalErrorKind.observerThrew);
    expect(record.context, 'flow_view_did_receive_error');
    expect(record.where, 'flowViewDidReceiveError');
    expect(record.error, isA<StateError>().having((e) => e.message, 'message', 'widget boom'));
  });

  test('a decode failure is reported as eventDecodeFailed', () async {
    final sink = CollectingErrorSink();
    final fake = FakeTransport();
    installTestRuntime(transport: fake, errorSink: sink);

    final reply = await fake.deliver('flow_view_did_appear', {'view': 1});

    expect(reply, isNull);
    expect(sink.records, hasLength(1));
    final record = sink.records.single;
    expect(record.kind, AdaptyInternalErrorKind.eventDecodeFailed);
    expect(record.context, 'flow_view_did_appear');
    expect(record.correlationId, isNull);
    expect(record.where, 'Adapty._handleIncomingMethodCall');
    expect(record.error, isA<TypeError>());
    expect(record.stack, isNotNull);
  });

  test('a broken observer-mode event without a resolver is not decoded', () async {
    final sink = CollectingErrorSink();
    final fake = FakeTransport();
    installTestRuntime(transport: fake, errorSink: sink);

    await fake.deliver('flow_view_observer_did_initiate_purchase', {'event_id': 'e1', 'view': 1});

    expect(sink.records, isEmpty);
    expect(fake.calls, isEmpty);
  });

  test('a broken observer-mode restore without a resolver is not decoded', () async {
    final sink = CollectingErrorSink();
    final fake = FakeTransport();
    installTestRuntime(transport: fake, errorSink: sink);

    await fake.deliver('flow_view_observer_did_initiate_restore', {'event_id': 'e2', 'view': 1});

    expect(sink.records, isEmpty);
    expect(fake.calls, isEmpty);
  });

  test('a failed default app review is reported as replyFailed', () async {
    final sink = CollectingErrorSink();
    final fake = FakeTransport()..replyError('adapty_ui_request_app_review', code: 2002);
    installTestRuntime(transport: fake, errorSink: sink);

    await fake.deliver('flow_view_did_request_app_review', {'view': _view});

    expect(fake.calls.map((call) => call.$1), ['adapty_ui_request_app_review']);
    expect(sink.records, hasLength(1));
    final record = sink.records.single;
    expect(record.kind, AdaptyInternalErrorKind.replyFailed);
    expect(record.context, 'adapty_ui_request_app_review');
    expect(record.correlationId, isNull);
    expect(record.error, isA<AdaptyError>().having((e) => e.code, 'code', 2002));
  });

  test('a failed default app review is logged as before', () async {
    final fake = FakeTransport()..replyError('adapty_ui_request_app_review', code: 2002);
    installTestRuntime(transport: fake);

    final lines = <String>[];
    await runZoned(
      () => fake.deliver('flow_view_did_request_app_review', {'view': _view}),
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => lines.add(line)),
    );

    expect(lines, [
      endsWith('- ERROR: Error in Adapty._handleIncomingMethodCall: (code: 2002, message: x, detail: null)'),
    ]);
  });

  test('a failed automatic promoted purchase is reported as promotedAutoCompleteFailed', () async {
    final sink = CollectingErrorSink();
    final fake = FakeTransport()..replyError('make_promoted_purchase', code: 2);
    final rt = installTestRuntime(transport: fake, errorSink: sink);

    await fake.deliver('did_receive_promoted_purchase', {'product': _promotedProduct});
    await settle(rt);

    expect(fake.calls.map((call) => call.$1), ['make_promoted_purchase']);
    expect(sink.records, hasLength(1));
    final record = sink.records.single;
    expect(record.kind, AdaptyInternalErrorKind.promotedAutoCompleteFailed);
    expect(record.context, 'promoted_purchase.complete');
    expect(record.correlationId, isNull);
    expect(record.error, isA<AdaptyError>().having((e) => e.code, 'code', 2));
  });

  test('the errors of an event on runtime A go to the sink of A after B is installed', () async {
    final sinkA = CollectingErrorSink();
    final fakeA = FakeTransport()..replyError('adapty_ui_request_app_review', code: 2002);
    installTestRuntime(transport: fakeA, errorSink: sinkA);
    final sinkB = CollectingErrorSink();
    installTestRuntime(errorSink: sinkB);

    await fakeA.deliver('flow_view_did_appear', {'view': 1});
    await fakeA.deliver('flow_view_did_request_app_review', {'view': _view});

    expect(sinkA.records.map((record) => record.kind), [
      AdaptyInternalErrorKind.eventDecodeFailed,
      AdaptyInternalErrorKind.replyFailed,
    ]);
    expect(sinkB.records, isEmpty);
  });
}

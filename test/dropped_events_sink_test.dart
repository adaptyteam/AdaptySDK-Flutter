/// What the SDK reports when it drops an event: an event it does not know, and the oldest error of an embedded flow
/// view that waited for its widget when more than 16 such errors are waiting. Each is one warning-level record; the
/// SDK goes on as before: the unknown event is answered with null, and the dropped error never reaches the widget.
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_error.dart' show AdaptyErrorJSONBuilder;
import 'package:adapty_flutter/src/models/adaptyui/adaptyui_flow_view.dart' show AdaptyUIFlowViewJSONBuilder;
import 'package:adapty_flutter/src/runtime/adapty_internal_error_sink.dart';
import 'package:adapty_flutter/src/runtime/adapty_runtime.dart';
import 'package:adapty_flutter/src/runtime/event_dispatcher.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/capturing_log_sink.dart';
import 'support/collecting_error_sink.dart';
import 'support/fake_transport.dart';
import 'support/test_runtime.dart';

const _notSupported = {'adapty_code': 4001, 'message': 'the platform is not supported'};

/// Keeps the errors delivered to it, like the observer an embedded flow view registers.
class _Widget extends AdaptyUIFlowsEventsObserver {
  final errors = <AdaptyError>[];

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) {}

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) => errors.add(error);
}

Map<String, dynamic> _view(String id) => {'id': id, 'placement_id': 'placement-id', 'variation_id': 'variation-id'};

/// Sends an error for each of the embedded views `flutter_native_<first>` … `flutter_native_<last>`, none of which
/// has a widget listening.
Future<void> _sendEmbeddedErrors(FakeTransport fake, int first, int last) async {
  for (var i = first; i <= last; i++) {
    await fake.deliver('flow_view_did_receive_error', {'view': _view('flutter_native_$i'), 'error': _notSupported});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an unknown event is reported as unknownEvent with its id', () async {
    final sink = CollectingErrorSink();
    final logSink = CapturingLogSink();
    final fake = FakeTransport();
    installTestRuntime(transport: fake, errorSink: sink, logSink: logSink);

    final reply = await fake.deliver('not_a_known_event', {'view': _view('view-1')});

    expect(reply, isNull);
    expect(sink.records, hasLength(1));
    final record = sink.records.single;
    expect(record.kind, AdaptyInternalErrorKind.unknownEvent);
    expect(record.error, 'not_a_known_event');
    expect(record.context, 'not_a_known_event');
    expect(logSink.lines, isEmpty);
    expect(fake.calls, isEmpty);
  });

  test('an unknown event is logged as a single warning naming it', () async {
    final logSink = CapturingLogSink();
    final fake = FakeTransport();
    installTestRuntime(transport: fake, logSink: logSink);

    await fake.deliver('not_a_known_event', {'view': _view('view-1')});

    expect(logSink.lines, [
      (AdaptyLogLevel.warn, 'Adapty received an unknown event "not_a_known_event" and ignored it'),
    ]);
  });

  test('an unknown event is reported to the sink of the runtime that handles it', () async {
    final sink = CollectingErrorSink();
    // Never installed: the current runtime stays another one.
    final runtime = AdaptyRuntime(transport: FakeTransport(), errorSink: sink);
    addTearDown(runtime.debugDispose);

    await const AdaptyEventDispatcher().dispatch(runtime, 'not_a_known_event', jsonEncode({'view': _view('view-1')}));

    expect(sink.records.map((record) => record.kind), [AdaptyInternalErrorKind.unknownEvent]);
  });

  test('an evicted pending error is reported as pendingErrorDropped', () async {
    final sink = CollectingErrorSink();
    final logSink = CapturingLogSink();
    final fake = FakeTransport();
    installTestRuntime(transport: fake, errorSink: sink, logSink: logSink);

    await _sendEmbeddedErrors(fake, 200, 215);

    expect(sink.records, isEmpty, reason: 'sixteen errors fit, none is dropped yet');

    await _sendEmbeddedErrors(fake, 216, 216);

    expect(sink.records, hasLength(1));
    final record = sink.records.single;
    expect(record.kind, AdaptyInternalErrorKind.pendingErrorDropped);
    expect(record.error, 'flutter_native_200');
    expect(record.context, 'flow_view_did_receive_error');
    expect(logSink.lines, isEmpty);
  });

  test('a second error of a pending view is not reported as dropped', () async {
    final sink = CollectingErrorSink();
    final fake = FakeTransport();
    installTestRuntime(transport: fake, errorSink: sink);

    await _sendEmbeddedErrors(fake, 1, 1);
    await _sendEmbeddedErrors(fake, 1, 1);

    expect(sink.records, isEmpty);
  });

  test('a repeated error of the oldest pending view moves it to the end when the buffer is full', () async {
    final sink = CollectingErrorSink();
    final fake = FakeTransport();
    installTestRuntime(transport: fake, errorSink: sink);
    await _sendEmbeddedErrors(fake, 500, 515);
    await _sendEmbeddedErrors(fake, 500, 500);
    sink.records.clear();

    await _sendEmbeddedErrors(fake, 516, 516);

    expect(sink.records.map((record) => record.error), ['flutter_native_501']);
  });

  test('a repeated error of a pending view keeps its place when the buffer has room', () async {
    final sink = CollectingErrorSink();
    final fake = FakeTransport();
    installTestRuntime(transport: fake, errorSink: sink);
    await _sendEmbeddedErrors(fake, 600, 610);
    await _sendEmbeddedErrors(fake, 600, 600);

    await _sendEmbeddedErrors(fake, 611, 616);

    expect(sink.records.map((record) => record.error), ['flutter_native_600']);
  });

  test('an error of a view whose widget is gone is kept for a widget registered later under the same id', () async {
    final sink = CollectingErrorSink();
    final fake = FakeTransport();
    installTestRuntime(transport: fake, errorSink: sink);
    AdaptyUI().registerFlowEventsListener(_Widget(), 'flutter_native_700');
    AdaptyUI().unregisterFlowEventsListener('flutter_native_700');
    await _sendEmbeddedErrors(fake, 700, 700);

    final widget = _Widget();
    AdaptyUI().registerFlowEventsListener(widget, 'flutter_native_700');

    expect(widget.errors.map((error) => error.message), ['the platform is not supported']);
    expect(sink.records, isEmpty);
  });

  test('an evicted pending error is logged as a single warning naming its view', () async {
    final logSink = CapturingLogSink();
    final fake = FakeTransport();
    installTestRuntime(transport: fake, logSink: logSink);

    await _sendEmbeddedErrors(fake, 200, 216);

    expect(logSink.lines, [
      (
        AdaptyLogLevel.warn,
        'Adapty dropped an error of the embedded flow view flutter_native_200: '
            'more than 16 errors were waiting for their widgets',
      ),
    ]);
  });

  test('an evicted pending error is reported to the sink of the runtime that kept it', () async {
    final sinkA = CollectingErrorSink();
    final fakeA = FakeTransport();
    final a = installTestRuntime(transport: fakeA, errorSink: sinkA);
    await _sendEmbeddedErrors(fakeA, 200, 215);
    final sinkB = CollectingErrorSink();
    installTestRuntime(errorSink: sinkB);

    // The 17th error reaches the runtime that keeps the other sixteen while another runtime is current.
    a.ui.eventsProxy.flowViewDidReceiveError(
      AdaptyUIFlowViewJSONBuilder.fromJsonValue(_view('flutter_native_216')),
      AdaptyErrorJSONBuilder.fromJsonValue(_notSupported),
    );

    expect(sinkA.records.map((record) => record.error), ['flutter_native_200']);
    expect(sinkB.records, isEmpty);
  });
}

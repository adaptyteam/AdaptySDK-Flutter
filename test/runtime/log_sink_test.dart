/// Where the SDK log goes: the log sink of the runtime the line belongs to, past the log level of the package.
import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/runtime/adapty_internal_error_sink.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/capturing_log_sink.dart';
import '../support/fake_transport.dart';
import '../support/test_runtime.dart';

const _profile = {'profile_id': 'profile-1', 'segment_hash': 'segment-hash', 'timestamp': 1, 'is_test_user': false};

const _embeddedView = {'id': 'flutter_native_7', 'placement_id': 'placement-id', 'variation_id': 'variation-id'};

const _notSupported = {'adapty_code': 4001, 'message': 'not supported'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AdaptyLogLevel savedLogLevel;

  setUp(() => savedLogLevel = AdaptyLogger.logLevel);
  tearDown(() => AdaptyLogger.logLevel = savedLogLevel);

  test('AdaptyLogger writes through the log sink of the current runtime', () {
    final sink = CapturingLogSink();
    installTestRuntime(logSink: sink, withEventHandler: false);

    final printed = _printed(() => AdaptyLogger.write(AdaptyLogLevel.warn, 'x'));

    expect(sink.lines, [(AdaptyLogLevel.warn, 'x')]);
    expect(printed, isEmpty);
  });

  test('stamps come from the log sink', () {
    installTestRuntime(logSink: CapturingLogSink(), withEventHandler: false);

    expect([AdaptyLogger.stamp, AdaptyLogger.stamp], ['0001', '0002']);
  });

  test('the lines of one native call share one stamp', () async {
    final fake = FakeTransport()..reply('is_activated', false);
    final sink = CapturingLogSink();
    installTestRuntime(transport: fake, logSink: sink, withEventHandler: false);
    AdaptyLogger.logLevel = AdaptyLogLevel.verbose;

    await Adapty().isActivated();
    await Adapty().isActivated();

    // Each call logs its arguments, the raw and the decoded reply and the success object.
    expect(sink.lines.map((line) => line.$2.substring(0, 6)), [
      ...List.filled(4, '[0001]'),
      ...List.filled(4, '[0002]'),
    ]);
  });

  test('a verbose line does not reach the log sink at the info level', () {
    final sink = CapturingLogSink();
    installTestRuntime(logSink: sink, withEventHandler: false);
    AdaptyLogger.logLevel = AdaptyLogLevel.info;

    AdaptyLogger.write(AdaptyLogLevel.warn, 'x');
    AdaptyLogger.write(AdaptyLogLevel.verbose, 'y');

    expect(sink.lines, [(AdaptyLogLevel.warn, 'x')]);
  });

  test('LoggingErrorSink drops a record below the log level', () {
    final sink = CapturingLogSink();
    final rt = installTestRuntime(logSink: sink, withEventHandler: false);
    AdaptyLogger.logLevel = AdaptyLogLevel.error;

    rt.diagnostics.errorSink
      ..report(const AdaptyInternalErrorRecord(AdaptyInternalErrorKind.replyFailed, 'boom', context: 'set_fallback'))
      ..report(
        const AdaptyInternalErrorRecord(
          AdaptyInternalErrorKind.promotedAutoCompleteFailed,
          'late',
          context: 'make_purchase',
        ),
      );

    expect(sink.lines, [(AdaptyLogLevel.error, 'Error in Adapty._handleIncomingMethodCall: boom')]);
  });

  test('a fresh runtime warns about an ignored gradient setting again', () {
    const gradient = LinearGradient(colors: [Color(0xFF0000FF), Color(0xFF00FF00)], tileMode: TileMode.mirror);
    const warning =
        'AdaptyCustomAsset.linearGradient(tileMode: TileMode.mirror): flows do not support this setting, so it is '
        'ignored.';
    final sinkA = CapturingLogSink();
    final sinkB = CapturingLogSink();

    // Serializing the asset is what warns; the JSON itself is not needed here.
    installTestRuntime(logSink: sinkA, withEventHandler: false);
    AdaptyCustomAsset.linearGradient(gradient: gradient).jsonValue;
    AdaptyCustomAsset.linearGradient(gradient: gradient).jsonValue;
    installTestRuntime(logSink: sinkB, withEventHandler: false);
    AdaptyCustomAsset.linearGradient(gradient: gradient).jsonValue;

    expect(sinkA.lines, [(AdaptyLogLevel.warn, warning)]);
    expect(sinkB.lines, [(AdaptyLogLevel.warn, warning)]);
  });

  test("a log line written while handling an event goes to the sink of that event's runtime", () async {
    final fakeA = FakeTransport();
    final sinkA = CapturingLogSink();
    final sinkB = CapturingLogSink();
    installTestRuntime(transport: fakeA, logSink: sinkA);
    installTestRuntime(logSink: sinkB);
    // Only now: at the info level the line would stop before any sink, and installing B logs a verbose line to B.
    AdaptyLogger.logLevel = AdaptyLogLevel.verbose;

    await fakeA.deliver('did_load_latest_profile', {'profile': _profile});

    expect(
      sinkA.lines,
      contains(
        isA<(AdaptyLogLevel, String)>()
            .having((line) => line.$1, 'level', AdaptyLogLevel.verbose)
            .having((line) => line.$2, 'message', startsWith('handleIncomingCall did_load_latest_profile')),
      ),
    );
    expect(sinkB.lines.map((line) => line.$2), isNot(contains(startsWith('handleIncomingCall'))));
  });

  test('a widget that throws on a replayed error is logged by the runtime that kept the error', () async {
    final fakeA = FakeTransport();
    final sinkA = CapturingLogSink();
    final a = installTestRuntime(transport: fakeA, logSink: sinkA);
    await fakeA.deliver('flow_view_did_receive_error', {'view': _embeddedView, 'error': _notSupported});
    final sinkB = CapturingLogSink();
    installTestRuntime(logSink: sinkB);

    // An embedded view registers with the runtime it was created in, whichever runtime is current by then.
    a.ui.eventsProxy.registerFlowEventsListener(_ThrowingWidget(), 'flutter_native_7');

    expect(sinkA.lines, [(AdaptyLogLevel.error, 'Error in flowViewDidReceiveError: Bad state: widget boom')]);
    expect(sinkB.lines, isEmpty);
  });
}

class _ThrowingWidget extends AdaptyUIFlowsEventsObserver {
  @override
  void flowViewDidFinishPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product, AdaptyPurchaseResult result) {}

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) => throw StateError('widget boom');
}

/// Every line [body] prints.
List<String> _printed(void Function() body) {
  final lines = <String>[];
  runZoned(body, zoneSpecification: ZoneSpecification(print: (_, _, _, line) => lines.add(line)));
  return lines;
}

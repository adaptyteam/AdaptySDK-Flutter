/// The contract of the test runtime helper the runtime tests build on.
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/runtime/adapty_internal_error_sink.dart';
import 'package:adapty_flutter/src/runtime/adapty_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capturing_log_sink.dart';
import 'collecting_error_sink.dart';
import 'test_runtime.dart';

const _swallowed = AdaptyInternalErrorRecord(
  AdaptyInternalErrorKind.eventDecodeFailed,
  'boom',
  context: 'flow_view_did_appear',
);

/// Runs the clean-ups in [tearDowns] as the test framework does: the last registered first.
Future<void> _runTearDowns(List<dynamic Function()> tearDowns) async {
  for (final tearDown in tearDowns.reversed) {
    await tearDown();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('at the end of the test the runtime is disposed while still current, then the previous one comes back', () {
    final previous = AdaptyRuntime.current;
    late final AdaptyRuntime runtime;
    AdaptyRuntime? currentWhenClosed;
    // Tear-downs run in reverse order, so this one runs after the helper's own.
    addTearDown(() {
      expect(
        currentWhenClosed,
        same(runtime),
        reason: 'the streams of the runtime were not closed while it was current',
      );
      expect(AdaptyRuntime.current, same(previous));
    });
    runtime = installTestRuntime();
    Adapty().didUpdateProfileStream.listen(null, onDone: () => currentWhenClosed = AdaptyRuntime.current);
  });
  group('an error the SDK swallows', () {
    test('fails the test when it ends, with what was swallowed', () async {
      final previous = AdaptyRuntime.current;
      final tearDowns = <dynamic Function()>[];
      final runtime = installTestRuntime(registerTearDown: tearDowns.add);

      runtime.diagnostics.errorSink.report(_swallowed);

      await expectLater(
        _runTearDowns(tearDowns),
        throwsA(
          isA<TestFailure>().having(
            (e) => e.message,
            'message',
            allOf(contains('eventDecodeFailed'), contains('flow_view_did_appear'), contains('boom')),
          ),
        ),
      );
      expect(AdaptyRuntime.current, same(previous));
    });

    test('goes to the log of a test that chose the log, and the test does not fail', () async {
      final tearDowns = <dynamic Function()>[];
      final log = CapturingLogSink();
      final runtime = installTestRuntime(logErrors: true, logSink: log, registerTearDown: tearDowns.add);

      runtime.diagnostics.errorSink.report(_swallowed);
      await _runTearDowns(tearDowns);

      expect(log.lines, [(AdaptyLogLevel.error, 'Error in Adapty._handleIncomingMethodCall: boom')]);
    });

    test('goes to the sink a test gave, and the test does not fail', () async {
      final tearDowns = <dynamic Function()>[];
      final sink = CollectingErrorSink();
      final runtime = installTestRuntime(errorSink: sink, registerTearDown: tearDowns.add);

      runtime.diagnostics.errorSink.report(_swallowed);
      await _runTearDowns(tearDowns);

      expect(sink.records, [same(_swallowed)]);
    });
  });
}

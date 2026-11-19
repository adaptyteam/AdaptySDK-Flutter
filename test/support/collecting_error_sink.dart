import 'package:adapty_flutter/src/runtime/adapty_internal_error_sink.dart';
import 'package:adapty_flutter/src/runtime/adapty_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keeps every record the SDK reports, in order.
final class CollectingErrorSink implements AdaptyInternalErrorSink {
  final records = <AdaptyInternalErrorRecord>[];

  @override
  void report(AdaptyInternalErrorRecord record) => records.add(record);
}

/// Lets the events delivered to [runtime] and the background work they started run to the end.
Future<void> settle(AdaptyRuntime runtime) async {
  await pumpEventQueue();
  await runtime.diagnostics.background.idle;
  await pumpEventQueue();
}

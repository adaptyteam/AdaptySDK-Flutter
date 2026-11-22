import 'package:adapty_flutter/src/adapty.dart';
import 'package:adapty_flutter/src/runtime/adapty_internal_error_sink.dart';
import 'package:adapty_flutter/src/runtime/adapty_log_sink.dart';
import 'package:adapty_flutter/src/runtime/adapty_platform_info.dart';
import 'package:adapty_flutter/src/runtime/adapty_runtime.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_test/flutter_test.dart';

import 'collecting_error_sink.dart';
import 'fake_transport.dart';

/// Puts a fresh runtime over [transport] (a new [FakeTransport] by default) in place of the current one for the rest
/// of the test, and returns it. With [withEventHandler] the SDK installs its event handler on it, as after a hot
/// restart. The errors the SDK swallows go to [errorSink]; with [logErrors] they go to the log, as in production;
/// with neither they are kept, and any error kept fails the test when it ends, with the kind, the place and the
/// context of each. The runtime reports [platform] as its platform, the host one when it is null. Its log lines go to
/// [logSink], printed when it is null. App message ids come from [newMessageId], six random characters from
/// `0-9A-Za-z` when it is null. At the end of the test the runtime is disposed and the previous one comes back. The
/// clean-up is registered with [registerTearDown], which only the self-test of this file replaces.
///
/// A stream taken from `Adapty()`, and an observer or a handler set through `AdaptyUI()`, belongs to the runtime that
/// was current at that moment: take it after this call, or inside `runBound` of another runtime. A subscription made
/// before this call stays on the runtime that was current before it (the production one, unless the test installed
/// another) and gets no event from [transport].
///
/// Resume or cancel a paused subscription before the test ends: disposing the runtime waits for its streams to close,
/// and a paused subscription keeps its stream from closing until the test times out.
///
/// Never over the method channel transport: disposing that runtime would take the incoming handler of the production
/// runtime off the shared channel.
AdaptyRuntime installTestRuntime({
  FakeTransport? transport,
  bool withEventHandler = true,
  AdaptyInternalErrorSink? errorSink,
  bool logErrors = false,
  AdaptyPlatformInfo? platform,
  AdaptyLogSink? logSink,
  String Function()? newMessageId,
  @visibleForTesting void Function(dynamic Function()) registerTearDown = addTearDown,
}) {
  assert(errorSink == null || !logErrors, 'errors go either to the given sink or to the log');
  final unexpected = errorSink == null && !logErrors ? CollectingErrorSink() : null;
  final runtime = AdaptyRuntime(
    transport: transport ?? FakeTransport(),
    errorSink: errorSink ?? unexpected,
    platform: platform,
    logSink: logSink,
    newMessageId: newMessageId,
  );
  final previous = AdaptyRuntime.debugInstall(runtime);
  registerTearDown(() async {
    await runtime.debugDispose();
    AdaptyRuntime.debugInstall(previous);
    if (unexpected != null && unexpected.records.isNotEmpty) {
      fail(
        'The SDK swallowed ${unexpected.records.length} error(s) the test did not choose a sink for:\n'
        '${unexpected.records.map((r) => '${r.kind.name} in ${r.where} (${r.context}): ${r.error}').join('\n')}',
      );
    }
  });
  if (withEventHandler) Adapty().setupAfterHotRestart();
  return runtime;
}

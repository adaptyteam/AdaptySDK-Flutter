import 'package:adapty_flutter/src/adapty.dart';
import 'package:adapty_flutter/src/runtime/adapty_internal_error_sink.dart';
import 'package:adapty_flutter/src/runtime/adapty_platform_info.dart';
import 'package:adapty_flutter/src/runtime/adapty_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

/// Puts a fresh runtime over [transport] (a new [FakeTransport] by default) in place of the current one for the rest
/// of the test, and returns it. With [withEventHandler] the SDK installs its event handler on it, as after a hot
/// restart. The errors the SDK swallows go to [errorSink], to the log when it is null. The runtime reports [platform]
/// as its platform, the host one when it is null. App message ids come from [newMessageId], random version 4 UUIDs
/// when it is null. At the end of the test the runtime is disposed and the previous one comes back.
///
/// Never over the method channel transport: disposing that runtime would take the incoming handler of the production
/// runtime off the shared channel.
AdaptyRuntime installTestRuntime({
  FakeTransport? transport,
  bool withEventHandler = true,
  AdaptyInternalErrorSink? errorSink,
  AdaptyPlatformInfo? platform,
  String Function()? newMessageId,
}) {
  final runtime = AdaptyRuntime(
    transport: transport ?? FakeTransport(),
    errorSink: errorSink,
    platform: platform,
    newMessageId: newMessageId,
  );
  final previous = AdaptyRuntime.debugInstall(runtime);
  addTearDown(() async {
    await runtime.debugDispose();
    AdaptyRuntime.debugInstall(previous);
  });
  if (withEventHandler) Adapty().setupAfterHotRestart();
  return runtime;
}

import 'package:adapty_flutter/src/adapty.dart';
import 'package:adapty_flutter/src/runtime/adapty_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

/// Puts a fresh runtime over [transport] (a new [FakeTransport] by default) in place of the current one for the rest
/// of the test, and returns it. With [withEventHandler] the SDK installs its event handler on it, as after a hot
/// restart. At the end of the test the runtime is disposed and the previous one comes back.
///
/// Never over the method channel transport: disposing that runtime would take the incoming handler of the production
/// runtime off the shared channel.
AdaptyRuntime installTestRuntime({FakeTransport? transport, bool withEventHandler = true}) {
  final runtime = AdaptyRuntime(transport: transport ?? FakeTransport());
  final previous = AdaptyRuntime.debugInstall(runtime);
  addTearDown(() async {
    await runtime.debugDispose();
    AdaptyRuntime.debugInstall(previous);
  });
  if (withEventHandler) Adapty().setupAfterHotRestart();
  return runtime;
}

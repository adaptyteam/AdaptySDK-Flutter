import 'dart:async';

import 'package:flutter/foundation.dart';

import 'adapty_native_transport.dart';
import 'adapty_runtime_environment.dart';

/// The zone value under which [AdaptyRuntime.runBound] puts its runtime.
const Symbol adaptyRuntimeZoneKey = #adaptyRuntime;

/// What the SDK runs on: the way to the native side, for now.
///
/// The facades `Adapty()` and `AdaptyUI()` work on [current]. In the app that is the one production runtime over the
/// adapty channel; a test can put its own runtime in place with [debugInstall]. The handling of a native event runs in
/// [runBound] of the runtime the event arrived on, so a call it makes goes back to that runtime.
final class AdaptyRuntime {
  /// A runtime over [transport]. The transport is required: a second runtime over the shared adapty channel would
  /// take the incoming handler of the production runtime off it.
  AdaptyRuntime({required AdaptyNativeTransport transport})
    : environment = AdaptyRuntimeEnvironment(transport: transport),
      _isProduction = false;

  AdaptyRuntime._production()
    : environment = AdaptyRuntimeEnvironment(transport: const MethodChannelTransport()),
      _isProduction = true;

  final AdaptyRuntimeEnvironment environment;
  final bool _isProduction;
  bool _disposed = false;

  AdaptyNativeTransport get transport => environment.transport;

  /// Sends the events of the native side to [handler]; null stops the delivery.
  void setEventHandler(AdaptyEventHandler? handler) => transport.setEventHandler(handler);

  /// Runs [body] with this runtime as [current], including everything [body] schedules.
  R runBound<R>(R Function() body) => runZoned(body, zoneValues: {adaptyRuntimeZoneKey: this});

  /// One per isolate, created on first use. The incoming handler on the channel holds on to the runtime it was
  /// installed for, so there must never be a second one.
  static final AdaptyRuntime _productionInstance = AdaptyRuntime._production();

  static AdaptyRuntime? _installed;

  /// The runtime bound by [runBound], else the one installed by [debugInstall], else the production one.
  static AdaptyRuntime get current =>
      (Zone.current[adaptyRuntimeZoneKey] as AdaptyRuntime?) ?? _installed ?? _productionInstance;

  /// Makes [runtime] current outside [runBound] and returns the runtime installed before, if any; null brings the
  /// production runtime back. Only in debug builds.
  @visibleForTesting
  static AdaptyRuntime? debugInstall(AdaptyRuntime? runtime) {
    if (!kDebugMode) throw StateError('AdaptyRuntime.debugInstall is only available in debug builds');
    final previous = _installed;
    _installed = runtime;
    return previous;
  }

  /// Stops the delivery of native events to this runtime; a second call does nothing. The production runtime cannot
  /// be disposed: its handler is the one the app relies on.
  @visibleForTesting
  Future<void> debugDispose() {
    if (_isProduction) throw StateError('the production runtime cannot be disposed');
    if (_disposed) return Future.value();
    _disposed = true;
    setEventHandler(null);
    return Future.value();
  }
}

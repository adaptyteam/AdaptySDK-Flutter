import 'dart:async';

import 'package:flutter/foundation.dart';

import 'adapty_internal_error_sink.dart';

/// Work the SDK starts and nobody awaits. A failure goes to the error sink instead of the zone.
final class BackgroundWork {
  BackgroundWork(this._errorSink);

  final AdaptyInternalErrorSink _errorSink;
  int _pending = 0;
  Completer<void>? _drained;

  /// Waits for [future] in the background; if it fails, reports a record of kind [onError] with [label] as context.
  void track(String label, Future<void> future, {required AdaptyInternalErrorKind onError}) {
    _pending++;
    future
        .then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) =>
              _errorSink.report(AdaptyInternalErrorRecord(onError, error, stack: stack, context: label)),
        )
        .whenComplete(_finishOne);
  }

  void _finishOne() {
    _pending--;
    if (_pending > 0) return;
    final drained = _drained;
    _drained = null;
    drained?.complete();
  }

  /// How many tracked futures have not completed yet.
  int get pending => _pending;

  /// Completes once no tracked future is pending.
  @visibleForTesting
  Future<void> get idle => _pending == 0 ? Future.value() : (_drained ??= Completer<void>()).future;
}

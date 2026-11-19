import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/src/runtime/adapty_native_transport.dart';

/// A native side in memory: records every call, answers with what the test set and delivers events to the handler
/// the SDK installed.
final class FakeTransport implements AdaptyNativeTransport {
  /// Every call the SDK made, in order: its wire name and decoded arguments.
  final calls = <(String, Map<String, dynamic>)>[];

  final _replies = <String, String>{};
  final _holds = <String, Completer<void>>{};
  AdaptyEventHandler? _handler;

  /// Answers every following call of [method] with [success], until the test sets another answer for it.
  void reply(String method, Object? success) => _replies[method] = jsonEncode({'success': success});

  /// Answers every following call of [method] with an error, until the test sets another answer for it.
  void replyError(String method, {required int code, String message = 'x'}) => _replies[method] = jsonEncode({
    'error': {'adapty_code': code, 'message': message},
  });

  /// Keeps the answers to [method] back until the returned completer completes.
  Completer<void> hold(String method) => _holds[method] = Completer<void>();

  bool get hasEventHandler => _handler != null;

  /// Sends [eventName] with [payload] to the SDK and returns its reply.
  Future<Object?> deliver(String eventName, Map<String, dynamic> payload) {
    final handler = _handler;
    if (handler == null) {
      throw StateError('no event handler: call Adapty().activate() or setupAfterHotRestart() first');
    }
    return handler(eventName, jsonEncode(payload));
  }

  @override
  Future<String?> invoke(String method, String jsonArgs) async {
    calls.add((method, jsonDecode(jsonArgs) as Map<String, dynamic>));
    final hold = _holds[method];
    if (hold != null) await hold.future;
    return _replies[method] ?? jsonEncode({'success': null});
  }

  @override
  void setEventHandler(AdaptyEventHandler? handler) => _handler = handler;
}

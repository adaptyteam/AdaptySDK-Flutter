/// Calls the plugin on the adapty channel the way the SDK does, with the arguments as a JSON string,
/// and tells what it answered.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:adapty_l2a/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'l2a_cases.g.dart';
import 'l2a_types.dart';

/// The channel of the plugin, by the name the SDK declares.
const l2aChannel = MethodChannel(l2aChannelName);

/// The platform the probe runs on, as the bundle names it.
String get l2aPlatform => Platform.isIOS ? 'ios' : 'android';

/// The cases of the platform the probe runs on.
List<L2aCase> get l2aPlatformCases => l2aCases[l2aPlatform]!;

/// What a plugin answered a call.
final class L2aObserved {
  const L2aObserved(this.kind, {required this.milliseconds, this.code, this.messageClass, this.message});

  /// `success`, `error`, `native_exception`, `timeout`, `missing_plugin` or `unreadable`.
  final String kind;
  final int milliseconds;
  final int? code;
  final L2aMessageClass? messageClass;
  final String? message;

  Map<String, Object?> toJson() => {
    'kind': kind,
    if (code != null) 'code': code,
    if (messageClass != null) 'class': messageClass!.name,
    if (message != null) 'message': message,
    'ms': milliseconds,
  };
}

/// The kind of the error [message] the plugin answers a call of [method] with.
L2aMessageClass l2aMessageClass(String method, String message) {
  for (final MapEntry(key: messageClass, value: pattern) in l2aMessagePatterns[l2aPlatform]!.entries) {
    if (RegExp(pattern.replaceAll('{method}', RegExp.escape(method))).hasMatch(message)) return messageClass;
  }
  return L2aMessageClass.other;
}

/// Calls [method] with [arguments] and tells what the plugin answered within [timeout].
Future<L2aObserved> l2aCall(String method, String arguments, {Duration timeout = const Duration(seconds: 10)}) async {
  final watch = Stopwatch()..start();
  L2aObserved observed(String kind, {int? code, L2aMessageClass? messageClass, String? message}) => L2aObserved(
    kind,
    milliseconds: watch.elapsedMilliseconds,
    code: code,
    messageClass: messageClass,
    message: message,
  );
  try {
    final reply = await l2aChannel.invokeMethod<Object?>(method, arguments).timeout(timeout);
    final decoded = reply is String ? jsonDecode(reply) : null;
    return switch (decoded) {
      {'error': {'adapty_code': final int code, 'message': final String message}} => observed(
        'error',
        code: code,
        messageClass: l2aMessageClass(method, message),
        message: message,
      ),
      {'success': _} => observed('success'),
      _ => observed('unreadable', message: '$reply'),
    };
  } on TimeoutException {
    return observed('timeout');
  } on MissingPluginException catch (e) {
    return observed('missing_plugin', message: e.message);
  } on PlatformException catch (e) {
    return observed('native_exception', message: '${e.code}: ${e.message}');
  }
}

/// Calls the plugin with the case [c].
Future<L2aObserved> l2aInvoke(L2aCase c) => l2aCall(c.method, c.arguments);

/// Whether [observed] is what [expected] says; an observed or skipped case always is.
bool l2aMatches(L2aOutcome expected, L2aObserved observed) => switch (expected) {
  L2aSuccess() => observed.kind == 'success',
  L2aError(:final code, :final messageClass) =>
    observed.kind == 'error' && observed.code == code && observed.messageClass == messageClass,
  L2aNativeException() => observed.kind == 'native_exception',
  L2aTimeout() => observed.kind == 'timeout',
  L2aSkip() || L2aObserve() => true,
};

/// Starts the app and waits until the plugin answers: the first frame, `is_activated` replying with a
/// success, and one turn of the event loop. Fails when the plugin never answers.
Future<void> l2aReadinessBarrier(WidgetTester tester) async {
  await tester.pumpWidget(const L2aApp());
  await tester.pump();
  L2aObserved? last;
  for (var attempt = 0; attempt < 50; attempt++) {
    last = await l2aCall('is_activated', '{}', timeout: const Duration(seconds: 2));
    if (last.kind == 'success') break;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  await Future<void>.delayed(Duration.zero);
  if (last?.kind != 'success') {
    fail('the plugin does not answer is_activated on $l2aChannelName: ${last?.toJson()}');
  }
}

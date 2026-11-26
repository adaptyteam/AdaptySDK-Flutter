/// How a permission request a flow makes is answered when there is no handler, the handler throws, the request can't
/// be read, its event_id is empty or the answer fails, as the log and the error sink of the runtime see it.
///
/// A handler is set only in the body of a test, right after it installs its runtime; what it does is set by
/// [_throwing].
import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/runtime/adapty_internal_error_sink.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/capturing_log_sink.dart';
import 'support/collecting_error_sink.dart';
import 'support/fake_transport.dart';
import 'support/test_runtime.dart';

const _view = {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'};

Map<String, dynamic> _request() => {'event_id': 'hr_1', 'view': _view, 'permission': 'camera'};

/// Whether the handler throws; otherwise it grants every permission.
bool _throwing = false;

class _Handler extends AdaptyUISystemRequestsHandler {
  final permissions = <String>[];

  @override
  Future<AdaptyUIPermissionResult> handlePermission(
    AdaptyUIFlowView view,
    AdaptyUIPermission permission,
    Map<String, String>? customArgs,
  ) async {
    permissions.add(permission.value);
    if (_throwing) throw StateError('boom');
    return const AdaptyUIPermissionResult.granted();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTransport fake;
  late CollectingErrorSink sink;
  late CapturingLogSink log;

  void install() {
    fake = FakeTransport();
    sink = CollectingErrorSink();
    log = CapturingLogSink();
    installTestRuntime(transport: fake, errorSink: sink, logSink: log);
  }

  List<Map<String, dynamic>> answers() => [
    for (final (method, arguments) in fake.calls)
      if (method == 'flow_view_did_answer_permission') arguments,
  ];

  List<String> warnings() => [
    for (final (level, message) in log.lines)
      if (level == AdaptyLogLevel.warn) message,
  ];

  tearDown(() => _throwing = false);

  test('a missing handler is logged as a warning naming setSystemRequestsHandler', () async {
    install();

    await fake.deliver('flow_view_did_ask_permission', _request());

    expect(warnings(), [
      "No AdaptyUISystemRequestsHandler set; answering denied for permission 'camera'. "
          'Set one with AdaptyUI().setSystemRequestsHandler().',
    ]);
    expect(sink.records, isEmpty);
  });

  test('an empty permission without a handler is logged as it came and answered denied', () async {
    install();

    await fake.deliver('flow_view_did_ask_permission', _request()..['permission'] = '');

    expect(warnings(), [
      "No AdaptyUISystemRequestsHandler set; answering denied for permission ''. "
          'Set one with AdaptyUI().setSystemRequestsHandler().',
    ]);
    expect(answers(), [
      {'event_id': 'hr_1', 'status': 'denied'},
    ]);
  });

  test('a handler set after the request does not answer it', () async {
    install();

    await fake.deliver('flow_view_did_ask_permission', _request());
    expect(answers(), [
      {'event_id': 'hr_1', 'status': 'denied'},
    ]);

    final handler = _Handler();
    AdaptyUI().setSystemRequestsHandler(handler);
    await pumpEventQueue();

    expect(handler.permissions, isEmpty);
    expect(answers(), hasLength(1));
  });

  test('a handler set while the request waits for its turn does not answer it', () async {
    install();
    final handler = _Handler();

    final delivered = fake.deliver('flow_view_did_ask_permission', _request());
    AdaptyUI().setSystemRequestsHandler(handler);
    await delivered;

    expect(handler.permissions, isEmpty);
    expect(answers(), [
      {'event_id': 'hr_1', 'status': 'denied'},
    ]);
  });

  test('a non-string custom_args value is reported with its event id without calling the handler', () async {
    install();
    final handler = _Handler();
    AdaptyUI().setSystemRequestsHandler(handler);

    await fake.deliver('flow_view_did_ask_permission', _request()..['custom_args'] = {'a': 1});

    expect(sink.records.map((record) => (record.kind, record.context, record.correlationId)), [
      (AdaptyInternalErrorKind.eventDecodeFailed, 'flow_view_did_ask_permission', 'hr_1'),
    ]);
    expect(handler.permissions, isEmpty);
  });

  test('a non-string permission is reported with its event id without calling the handler', () async {
    install();
    final handler = _Handler();
    AdaptyUI().setSystemRequestsHandler(handler);

    await fake.deliver('flow_view_did_ask_permission', _request()..['permission'] = 1);

    expect(sink.records.map((record) => (record.kind, record.context, record.correlationId)), [
      (AdaptyInternalErrorKind.eventDecodeFailed, 'flow_view_did_ask_permission', 'hr_1'),
    ]);
    expect(handler.permissions, isEmpty);
  });

  test('a request answered by a handler logs no warning', () async {
    install();
    AdaptyUI().setSystemRequestsHandler(_Handler());

    await fake.deliver('flow_view_did_ask_permission', _request());

    expect(warnings(), isEmpty);
    expect(answers(), [
      {'event_id': 'hr_1', 'status': 'granted'},
    ]);
  });

  test('an undecodable request is reported with its event id and answered denied', () async {
    install();
    final handler = _Handler();
    AdaptyUI().setSystemRequestsHandler(handler);

    await fake.deliver('flow_view_did_ask_permission', _request()..['view'] = 42);

    expect(sink.records, hasLength(1));
    final record = sink.records.single;
    expect(record.kind, AdaptyInternalErrorKind.eventDecodeFailed);
    expect(record.context, 'flow_view_did_ask_permission');
    expect(record.correlationId, 'hr_1');
    expect(handler.permissions, isEmpty);
    expect(answers(), [
      {'event_id': 'hr_1', 'status': 'denied'},
    ]);
  });

  test('a failed answer is reported once and not retried', () async {
    install();
    fake.replyError('flow_view_did_answer_permission', code: 2002);
    final uncaught = <Object>[];

    await runZonedGuarded(() async {
      await fake.deliver('flow_view_did_ask_permission', _request());
      await pumpEventQueue();
    }, (error, _) => uncaught.add(error));

    expect(answers(), hasLength(1));
    expect(sink.records, hasLength(1));
    final record = sink.records.single;
    expect(record.kind, AdaptyInternalErrorKind.replyFailed);
    expect(record.context, 'flow_view_did_answer_permission');
    expect(record.correlationId, 'hr_1');
    expect(record.error, isA<AdaptyError>().having((e) => e.code, 'code', 2002));
    expect(uncaught, isEmpty);
  });

  test('a failed answer is logged as an error in the handling of the event', () async {
    fake = FakeTransport()..replyError('flow_view_did_answer_permission', code: 2002, message: 'the answer failed');
    log = CapturingLogSink();
    installTestRuntime(transport: fake, errorSink: LoggingErrorSink(log), logSink: log);
    AdaptyUI().setSystemRequestsHandler(_Handler());

    await fake.deliver('flow_view_did_ask_permission', _request());
    await pumpEventQueue();

    expect(answers(), hasLength(1));
    expect(log.lines, [
      (
        AdaptyLogLevel.error,
        'Error in Adapty._handleIncomingMethodCall: (code: 2002, message: the answer failed, detail: null)',
      ),
    ]);
  });

  test('a failed answer of a handler leaves the event itself with a null reply', () async {
    fake = FakeTransport()..replyError('flow_view_did_answer_permission', code: 2002, message: 'the answer failed');
    log = CapturingLogSink();
    installTestRuntime(transport: fake, errorSink: LoggingErrorSink(log), logSink: log);
    AdaptyUI().setSystemRequestsHandler(_Handler());

    final reply = await fake.deliver('flow_view_did_ask_permission', _request());

    expect(reply, isNull);
    expect(answers(), [
      {'event_id': 'hr_1', 'status': 'granted'},
    ]);
    expect(log.lines, [
      (
        AdaptyLogLevel.error,
        'Error in Adapty._handleIncomingMethodCall: (code: 2002, message: the answer failed, detail: null)',
      ),
    ]);
  });

  test('a failed denied answer without a handler leaves the event with a null reply after the warning', () async {
    fake = FakeTransport()..replyError('flow_view_did_answer_permission', code: 2002, message: 'the answer failed');
    log = CapturingLogSink();
    installTestRuntime(transport: fake, errorSink: LoggingErrorSink(log), logSink: log);

    final reply = await fake.deliver('flow_view_did_ask_permission', _request());

    expect(reply, isNull);
    expect(answers(), [
      {'event_id': 'hr_1', 'status': 'denied'},
    ]);
    expect(log.lines, [
      (
        AdaptyLogLevel.warn,
        "No AdaptyUISystemRequestsHandler set; answering denied for permission 'camera'. "
            'Set one with AdaptyUI().setSystemRequestsHandler().',
      ),
      (
        AdaptyLogLevel.error,
        'Error in Adapty._handleIncomingMethodCall: (code: 2002, message: the answer failed, detail: null)',
      ),
    ]);
  });

  test('a request with an empty event_id is answered denied with that event_id when there is no handler', () async {
    install();

    final reply = await fake.deliver('flow_view_did_ask_permission', _request()..['event_id'] = '');

    expect(reply, isNull);
    expect(answers(), [
      {'event_id': '', 'status': 'denied'},
    ]);
    expect(warnings(), [
      "No AdaptyUISystemRequestsHandler set; answering denied for permission 'camera'. "
          'Set one with AdaptyUI().setSystemRequestsHandler().',
    ]);
    expect(sink.records, isEmpty);
  });

  test('a request with an empty event_id reaches the handler and its result is answered with that event_id', () async {
    install();
    final handler = _Handler();
    AdaptyUI().setSystemRequestsHandler(handler);

    await fake.deliver('flow_view_did_ask_permission', _request()..['event_id'] = '');

    expect(handler.permissions, ['camera']);
    expect(answers(), [
      {'event_id': '', 'status': 'granted'},
    ]);
    expect(sink.records, isEmpty);
  });

  test('a throwing handler is reported as handlerThrew with the event id', () async {
    install();
    AdaptyUI().setSystemRequestsHandler(_Handler());
    _throwing = true;

    await fake.deliver('flow_view_did_ask_permission', _request());

    expect(sink.records, hasLength(1));
    final record = sink.records.single;
    expect(record.kind, AdaptyInternalErrorKind.handlerThrew);
    expect(record.context, 'flow_view_did_ask_permission');
    expect(record.correlationId, 'hr_1');
    expect(record.error.toString(), contains('boom'));
  });

  test('a request without event_id is reported as eventDecodeFailed', () async {
    install();

    final reply = await fake.deliver('flow_view_did_ask_permission', _request()..remove('event_id'));

    expect(reply, isNull);
    expect(answers(), isEmpty);
    expect(sink.records.map((record) => record.kind), [AdaptyInternalErrorKind.eventDecodeFailed]);
    expect(sink.records.single.context, 'flow_view_did_ask_permission');
  });
}

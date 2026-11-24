import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

/// What the handler does with a request; each test sets it before the event.
late Future<AdaptyUIPermissionResult> Function(Map<String, String>? customArgs) _answer;

class _Handler extends AdaptyUISystemRequestsHandler {
  final requests = <(AdaptyUIFlowView, AdaptyUIPermission, Map<String, String>?)>[];
  bool started = false;

  @override
  Future<AdaptyUIPermissionResult> handlePermission(
    AdaptyUIFlowView view,
    AdaptyUIPermission permission,
    Map<String, String>? customArgs,
  ) {
    started = true;
    requests.add((view, permission, customArgs));
    return _answer(customArgs);
  }
}

final _handler = _Handler();

Map<String, dynamic> _request({Object? view, Map<String, dynamic>? customArgs}) => {
  'event_id': 'hr_1',
  'view': view ?? {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
  'permission': 'camera',
  if (customArgs != null) 'custom_args': customArgs,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];

  Future<void> deliver(String method, Map<String, dynamic> arguments) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        _channel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, jsonEncode(arguments))),
        (_) {},
      );

  Future<void> sendEvent(String method, Map<String, dynamic> arguments) async {
    await deliver(method, arguments);
    await pumpEventQueue();
  }

  Future<List<String>> capturingLogs(Future<void> Function() body) async {
    final logs = <String>[];
    await runZoned(body, zoneSpecification: ZoneSpecification(print: (_, _, _, line) => logs.add(line)));
    return logs;
  }

  Iterable<MethodCall> answers() => calls.where((call) => call.method == 'flow_view_did_answer_permission');

  Iterable<Object?> answerArguments() => answers().map((call) => jsonDecode(call.arguments as String));

  setUp(() {
    calls.clear();
    _handler.requests.clear();
    _handler.started = false;
    _answer = (_) async => const AdaptyUIPermissionResult.granted();
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return jsonEncode({'success': true});
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('a throwing handler is answered denied', () async {
    AdaptyUI().setSystemRequestsHandler(_handler);
    _answer = (_) => throw StateError('permission boom');

    final logs = await capturingLogs(() => sendEvent('flow_view_did_ask_permission', _request()));

    expect(_handler.requests, hasLength(1));
    expect(answerArguments(), [
      {'event_id': 'hr_1', 'status': 'denied'},
    ]);
    expect(logs.where((line) => line.contains('ERROR:')), [
      endsWith('ERROR: Error in Adapty._handleIncomingMethodCall: Bad state: permission boom'),
    ]);
  });

  test('a request with an undecodable view is answered denied without calling the handler', () async {
    AdaptyUI().setSystemRequestsHandler(_handler);

    await capturingLogs(() => sendEvent('flow_view_did_ask_permission', _request(view: 42)));

    expect(_handler.requests, isEmpty);
    expect(answerArguments(), [
      {'event_id': 'hr_1', 'status': 'denied'},
    ]);
  });

  test('a non-string custom_args value is answered denied without calling the handler', () async {
    AdaptyUI().setSystemRequestsHandler(_handler);
    _answer = (customArgs) async => AdaptyUIPermissionResult.granted(customArgs!['a']);

    await capturingLogs(() => sendEvent('flow_view_did_ask_permission', _request(customArgs: {'a': 1})));

    expect(_handler.requests.length, 0);
    expect(answerArguments(), [
      {'event_id': 'hr_1', 'status': 'denied'},
    ]);
  });

  test('a handler returning a failed future is answered denied', () async {
    AdaptyUI().setSystemRequestsHandler(_handler);
    _answer = (_) => Future.error(StateError('permission boom'));

    await capturingLogs(() => sendEvent('flow_view_did_ask_permission', _request()));

    expect(_handler.requests, hasLength(1));
    expect(answerArguments(), [
      {'event_id': 'hr_1', 'status': 'denied'},
    ]);
  });

  // The native side always sends a permission; a request without one is malformed input.
  test('a malformed request without a permission is answered denied without calling the handler', () async {
    AdaptyUI().setSystemRequestsHandler(_handler);

    await capturingLogs(() => sendEvent('flow_view_did_ask_permission', _request()..remove('permission')));

    expect(_handler.requests, isEmpty);
    expect(answerArguments(), [
      {'event_id': 'hr_1', 'status': 'denied'},
    ]);
  });

  test('a request without event_id is not answered', () async {
    AdaptyUI().setSystemRequestsHandler(_handler);
    final replies = <Object?>[];

    await capturingLogs(() async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        _channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('flow_view_did_ask_permission', jsonEncode(_request()..remove('event_id'))),
        ),
        (data) => replies.add(const StandardMethodCodec().decodeEnvelope(data!)),
      );
      await pumpEventQueue();
    });

    expect(replies, [null]);
    expect(_handler.requests, isEmpty);
    expect(answers(), isEmpty);
  });

  test('an empty permission reaches the handler as is and its result is answered', () async {
    AdaptyUI().setSystemRequestsHandler(_handler);

    await sendEvent('flow_view_did_ask_permission', _request()..['permission'] = '');

    expect(_handler.requests.map((request) => request.$2.value), ['']);
    expect(answerArguments(), [
      {'event_id': 'hr_1', 'status': 'granted'},
    ]);
  });

  test('a handler result is answered once with its status and detail', () async {
    AdaptyUI().setSystemRequestsHandler(_handler);
    _answer = (_) async => const AdaptyUIPermissionResult.granted('d');

    await sendEvent('flow_view_did_ask_permission', _request());

    expect(_handler.requests, hasLength(1));
    final (view, permission, customArgs) = _handler.requests.single;
    expect(view.id, 'view-1');
    expect(permission, AdaptyUIPermission.camera);
    expect(customArgs, isNull);
    expect(answers().map((call) => jsonDecode(call.arguments as String)), [
      {'event_id': 'hr_1', 'status': 'granted', 'detail': 'd'},
    ]);
  });

  test('the permission handler starts on the next event-loop turn', () async {
    AdaptyUI().setSystemRequestsHandler(_handler);

    final delivered = deliver('flow_view_did_ask_permission', _request());

    await Future.microtask(() {});
    expect(_handler.started, isFalse);

    await Future(() {});
    expect(_handler.started, isTrue);

    await delivered;
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

const _noHandlerWarning =
    "WARN: No AdaptyUISystemRequestsHandler set; answering denied for permission 'camera'. "
    'Set one with AdaptyUI().setSystemRequestsHandler().';
const _errorLine = 'ERROR: Error in Adapty._handleIncomingMethodCall:';

/// Answers each request with what [answer] returns or throws.
class _Handler extends AdaptyUISystemRequestsHandler {
  _Handler(this.answer);

  Future<AdaptyUIPermissionResult> Function() answer;
  final permissions = <String>[];

  @override
  Future<AdaptyUIPermissionResult> handlePermission(
    AdaptyUIFlowView view,
    AdaptyUIPermission permission,
    Map<String, String>? customArgs,
  ) {
    permissions.add(permission.value);
    return answer();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  final printed = <String>[];

  /// Delivers a permission request of a flow in a guarded zone that records what the SDK prints, and returns what
  /// escaped it uncaught.
  Future<List<Object>> askPermission(String eventId) async {
    final caught = <Object>[];
    await runZonedGuarded(
      () async {
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
          _channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(
              'flow_view_did_ask_permission',
              jsonEncode({
                'view': {'id': 'view-id', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
                'event_id': eventId,
                'permission': 'camera',
                'custom_args': {'reason': 'scan'},
              }),
            ),
          ),
          (_) {},
        );
        await pumpEventQueue();
      },
      (error, _) => caught.add(error),
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => printed.add(line)),
    );
    return caught;
  }

  List<Map<String, dynamic>> answers() => calls
      .where((call) => call.method == 'flow_view_did_answer_permission')
      .map((call) => jsonDecode(call.arguments as String) as Map<String, dynamic>)
      .toList();

  Iterable<String> errorLines() => printed.where((line) => line.contains(_errorLine));

  void mockNative() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return jsonEncode({'success': true});
    });
  }

  // A handler can't be unset, so the request without one is made before any test sets one.
  late List<Map<String, dynamic>> noHandlerAnswers;
  late List<String> noHandlerPrinted;
  late List<Object> noHandlerCaught;
  setUpAll(() async {
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    mockNative();
    noHandlerCaught = await askPermission('event-without-handler');
    noHandlerAnswers = answers();
    noHandlerPrinted = List.of(printed);
  });

  setUp(() {
    calls.clear();
    printed.clear();
    Adapty().setupAfterHotRestart();
    mockNative();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('without a handler the flow receives denied, without a detail, and the SDK warns', () {
    expect(noHandlerAnswers, [
      {'event_id': 'event-without-handler', 'status': 'denied'},
    ]);
    expect(noHandlerPrinted.where((line) => line.contains(_noHandlerWarning)), hasLength(1));
    expect(noHandlerPrinted.where((line) => line.contains(_errorLine)), isEmpty);
    expect(noHandlerCaught, isEmpty);
  });

  test('a handler that throws gives denied and one error line', () async {
    final handler = _Handler(() => throw StateError('the prompt failed'));
    AdaptyUI().setSystemRequestsHandler(handler);

    final caught = await askPermission('event-handler-throws');

    expect(handler.permissions, ['camera']);
    expect(answers(), [
      {'event_id': 'event-handler-throws', 'status': 'denied'},
    ]);
    expect(errorLines(), hasLength(1));
    expect(errorLines().single, contains('Bad state: the prompt failed'));
    expect(caught, isEmpty);
  });

  test('a handler whose future fails gives denied and one error line', () async {
    final handler = _Handler(() => Future.error(StateError('the prompt was interrupted')));
    AdaptyUI().setSystemRequestsHandler(handler);

    final caught = await askPermission('event-handler-fails');

    expect(handler.permissions, ['camera']);
    expect(answers(), [
      {'event_id': 'event-handler-fails', 'status': 'denied'},
    ]);
    expect(errorLines(), hasLength(1));
    expect(errorLines().single, contains('Bad state: the prompt was interrupted'));
    expect(caught, isEmpty);
  });

  test('the result of the handler, with its detail, goes back as it is', () async {
    final handler = _Handler(() async => const AdaptyUIPermissionResult.granted('limited'));
    AdaptyUI().setSystemRequestsHandler(handler);

    final caught = await askPermission('event-granted');

    expect(handler.permissions, ['camera']);
    expect(answers(), [
      {'event_id': 'event-granted', 'status': 'granted', 'detail': 'limited'},
    ]);
    expect(errorLines(), isEmpty);
    expect(caught, isEmpty);
  });
}

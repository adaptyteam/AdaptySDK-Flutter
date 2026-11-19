import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

// No system requests handler is ever set in this file: the setter takes no null, so a handler
// set by one test would stay for the rest of the file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];

  Future<void> sendEvent(String method, Map<String, dynamic> arguments) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, jsonEncode(arguments))),
      (_) {},
    );
    await pumpEventQueue();
  }

  setUp(() {
    calls.clear();
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return jsonEncode({'success': null});
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('without a handler a permission request gets no answer', () async {
    await sendEvent('flow_view_did_ask_permission', {
      'event_id': 'hr_1',
      'view': {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
      'permission': 'camera',
    });

    expect(calls.where((call) => call.method == 'flow_view_did_answer_permission'), isEmpty);
  });
}

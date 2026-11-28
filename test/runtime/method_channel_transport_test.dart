/// The transport over the adapty method channel: a JSON string goes out with each call and the reply string comes
/// back as it is; events reach the handler as their name and JSON string.
import 'package:adapty_flutter/src/runtime/adapty_native_transport.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const transport = MethodChannelTransport();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    _channel.setMethodCallHandler(null);
  });

  void answerWith(Future<Object?> Function(MethodCall call) handler) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, handler);

  /// Sends [call] from the native side and returns the decoded reply, or null when nothing handled it.
  Future<Object?> sendFromNative(MethodCall call) async {
    ByteData? reply;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(call),
      (data) => reply = data,
    );
    return reply == null ? null : const StandardMethodCodec().decodeEnvelope(reply!);
  }

  test('invoke sends the method name and the JSON string and returns the reply string', () async {
    final calls = <MethodCall>[];
    answerWith((call) async {
      calls.add(call);
      return '{"success":true}';
    });

    final reply = await transport.invoke('get_profile', '{"a":1}');

    expect(reply, '{"success":true}');
    expect(calls.single.method, 'get_profile');
    expect(calls.single.arguments, '{"a":1}');
  });

  test('a null reply is returned as null', () async {
    answerWith((call) async => null);

    expect(await transport.invoke('is_activated', '{}'), isNull);
  });

  test('native exceptions reach the caller unchanged', () async {
    answerWith((call) async => throw PlatformException(code: 'code-1', message: 'boom', details: 'details-1'));

    await expectLater(
      transport.invoke('is_activated', '{}'),
      throwsA(
        isA<PlatformException>()
            .having((e) => e.code, 'code', 'code-1')
            .having((e) => e.message, 'message', 'boom')
            .having((e) => e.details, 'details', 'details-1'),
      ),
    );

    answerWith((call) async => throw MissingPluginException('no plugin'));

    await expectLater(transport.invoke('is_activated', '{}'), throwsA(isA<MissingPluginException>()));
  });

  test('an incoming call reaches the handler as its name and JSON string and its result is the reply', () async {
    final events = <(String, String)>[];
    transport.setEventHandler((eventName, jsonPayload) async {
      events.add((eventName, jsonPayload));
      return 'handled';
    });

    final reply = await sendFromNative(const MethodCall('did_load_latest_profile', '{"profile":1}'));

    expect(events, [('did_load_latest_profile', '{"profile":1}')]);
    expect(reply, 'handled');
  });

  test('incoming arguments that are not a string reach the handler as the JSON null', () async {
    final payloads = <String>[];
    transport.setEventHandler((eventName, jsonPayload) async {
      payloads.add(jsonPayload);
      return null;
    });

    await sendFromNative(const MethodCall('did_load_latest_profile', {'profile': 1}));
    await sendFromNative(const MethodCall('did_load_latest_profile'));

    expect(payloads, ['null', 'null']);
  });

  test('setEventHandler with null stops the delivery', () async {
    final events = <String>[];
    transport.setEventHandler((eventName, jsonPayload) async {
      events.add(eventName);
      return 'handled';
    });
    transport.setEventHandler(null);

    final reply = await sendFromNative(const MethodCall('did_load_latest_profile', '{}'));

    expect(events, isEmpty);
    expect(reply, isNull);
  });
}

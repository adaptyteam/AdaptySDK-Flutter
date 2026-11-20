/// What the app learns today when the native side sends a payload that lacks a required field.
import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

/// The reply of the mocked native side per method; a method not listed answers `{"success": true}`,
/// as the native side answers a call without a result.
final _replies = <String, Map<String, dynamic>>{};

/// A profile without the required `profile_id`; every other required field is present.
const _profileWithoutId = {'segment_hash': 'segment-hash', 'timestamp': 1, 'is_test_user': false};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<String>> sendEventCapturingLogs(String method, Map<String, dynamic> arguments) async {
    final logs = <String>[];
    await runZoned(() async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        _channel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, jsonEncode(arguments))),
        (_) {},
      );
      await pumpEventQueue();
    }, zoneSpecification: ZoneSpecification(print: (_, _, _, line) => logs.add(line)));
    return logs;
  }

  setUp(() {
    _replies.clear();
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => jsonEncode(_replies[call.method] ?? {'success': true}),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('a missing required field gives a detail without the field name', () async {
    _replies['get_profile'] = {'success': _profileWithoutId};

    await expectLater(
      Adapty().getProfile(),
      throwsA(
        isA<AdaptyError>()
            .having((e) => e.code, 'code', AdaptyErrorCode.internalPluginError)
            .having((e) => e.detail, 'detail', contains("type 'Null' is not a subtype of type 'String'"))
            .having((e) => e.detail, 'detail', isNot(contains('profile_id'))),
      ),
    );
  });

  test('a profile event with a missing field is logged without the field name', () async {
    final profiles = <AdaptyProfile>[];
    final subscription = Adapty().didUpdateProfileStream.listen(profiles.add);
    addTearDown(subscription.cancel);

    final logs = await sendEventCapturingLogs('did_load_latest_profile', {'profile': _profileWithoutId});

    final errors = logs.where((line) => line.contains('ERROR:')).toList();
    expect(errors, hasLength(1));
    expect(errors.single, contains("type 'Null' is not a subtype of type 'String'"));
    expect(errors.single, isNot(contains('profile_id')));
    expect(profiles, isEmpty);
  });
}

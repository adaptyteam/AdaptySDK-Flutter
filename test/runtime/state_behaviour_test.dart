/// What the app sees of the state the SDK keeps between calls: the streams it hands out.
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

const _profile = {'profile_id': 'profile-1', 'segment_hash': 'segment-hash', 'timestamp': 1, 'is_test_user': false};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    final savedLogLevel = AdaptyLogger.logLevel;
    addTearDown(() => AdaptyLogger.logLevel = savedLogLevel);
    messenger.setMockMethodCallHandler(_channel, (call) async => jsonEncode({'success': null}));
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
    // activate installed the incoming handler on a channel shared by the whole isolate.
    _channel.setMethodCallHandler(null);
  });

  test('a profile stream taken before activate receives the profile event', () async {
    final stream = Adapty().didUpdateProfileStream;
    final profiles = <String>[];
    final subscription = stream.listen((profile) => profiles.add(profile.profileId));
    addTearDown(subscription.cancel);

    await Adapty().activate(configuration: AdaptyConfiguration(apiKey: 'test-api-key'));
    await messenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('did_load_latest_profile', jsonEncode({'profile': _profile})),
      ),
      (_) {},
    );
    await pumpEventQueue();

    expect(profiles, ['profile-1']);
  });
}

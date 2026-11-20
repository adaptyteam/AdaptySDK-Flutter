/// How the channel to the native side reads in errors and logs: calls and events appear under the
/// names they have on the channel.
import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

const _profile = {'profile_id': 'profile-1', 'segment_hash': 'segment-hash', 'timestamp': 1, 'is_test_user': false};

/// Records what an app callback sees of its zone; prints and throws later, as app code may.
class _ZoneObserver extends AdaptyUIFlowsEventsObserver {
  Object? zoneValue;

  @override
  void flowViewDidAppear(AdaptyUIFlowView view) {
    zoneValue = Zone.current[#appZoneValue];
    print('printed by the observer');
    Future<void>(() => throw StateError('thrown later by the observer'));
  }

  @override
  void flowViewDidFinishPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product, AdaptyPurchaseResult result) {}

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    // Some tests install an incoming handler on a channel shared by the whole isolate.
    _channel.setMethodCallHandler(null);
  });

  /// Runs [body] at the verbose level and returns what the SDK printed meanwhile.
  Future<List<String>> verboseLogs(Future<void> Function() body) async {
    final savedLogLevel = AdaptyLogger.logLevel;
    addTearDown(() => AdaptyLogger.logLevel = savedLogLevel);
    AdaptyLogger.logLevel = AdaptyLogLevel.verbose;

    final logs = <String>[];
    await runZoned(body, zoneSpecification: ZoneSpecification(print: (_, _, _, line) => logs.add(line)));
    return logs;
  }

  /// Delivers [event] from the native side and returns the encoded reply of the SDK.
  Future<ByteData?> sendEvent(String event, Map<String, dynamic> arguments) async {
    ByteData? reply;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(event, jsonEncode(arguments))),
      (data) => reply = data,
    );
    await pumpEventQueue();
    return reply;
  }

  test('a null reply fails with emptyResult', () async {
    final savedLogLevel = AdaptyLogger.logLevel;
    addTearDown(() => AdaptyLogger.logLevel = savedLogLevel);
    AdaptyLogger.logLevel = AdaptyLogLevel.verbose;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => null,
    );

    final logs = <String>[];
    Object? error;
    await runZoned(() async {
      try {
        await Adapty().isActivated();
      } catch (e) {
        error = e;
      }
    }, zoneSpecification: ZoneSpecification(print: (_, _, _, line) => logs.add(line)));

    expect(
      error,
      isA<AdaptyError>()
          .having((e) => e.code, 'code', AdaptyErrorCode.emptyResult)
          .having((e) => e.message, 'message', 'Adapty.is_activated() returned null'),
    );
    expect(logs, contains(contains('--> Adapty.is_activated()')));
    expect(logs, contains(contains('<-- Adapty.is_activated(), Result: null')));
    expect(logs, contains(contains('<-- Adapty.is_activated() Error: ')));
  });

  test('a successful reply is logged under the channel name with its raw and decoded result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => jsonEncode({'success': true}),
    );

    final logs = await verboseLogs(() => Adapty().isActivated());

    expect(logs, contains(contains('<-- Adapty.is_activated(), Result: {"success":true}')));
    expect(logs, contains(contains('<-- Adapty.is_activated(), Result: {success: true}')));
    expect(logs, contains(contains('<-- Adapty.is_activated(), Success Object: true')));
  });

  test('a native exception is logged under the channel name as an internal plugin error', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      throw PlatformException(code: 'error', message: 'boom');
    });

    final logs = await verboseLogs(() async {
      await expectLater(Adapty().isActivated(), throwsA(isA<AdaptyError>()));
    });

    expect(
      logs,
      contains(
        endsWith(
          '<-- Adapty.is_activated() Error: (code: 10002, '
          'message: Internal plugin error in Adapty.is_activated(), '
          'detail: PlatformException(error, boom, null, null))',
        ),
      ),
    );
  });

  test('an incoming event is logged under the name it arrived with, an unknown one included', () async {
    Adapty().setupAfterHotRestart();

    final logs = await verboseLogs(() async {
      await sendEvent('on_installation_details_fail', {
        'error': {'adapty_code': 2002, 'message': 'something failed'},
      });
      await sendEvent('not_an_event', {});
    });

    expect(logs, contains(contains('handleIncomingCall on_installation_details_fail Args: ')));
    expect(logs, contains(endsWith('handleIncomingCall not_an_event Args: {}')));
  });

  test('an unknown event is answered with null and logs no error', () async {
    Adapty().setupAfterHotRestart();

    ByteData? reply;
    final logs = await verboseLogs(() async {
      reply = await sendEvent('not_an_event', {});
    });

    expect(reply, isNotNull, reason: 'the SDK handles the event');
    expect(const StandardMethodCodec().decodeEnvelope(reply!), isNull);
    expect(logs.where((line) => line.contains(' - ERROR: ')), isEmpty);
  });

  test('a call sends its method name and JSON string arguments over the adapty channel', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return jsonEncode({'success': true});
    });

    await Adapty().isActivated();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'is_activated');
    expect(calls.single.arguments, isA<String>());
    expect(calls.single.arguments, '{}');
  });

  test('an event after setupAfterHotRestart reaches the profile stream', () async {
    final profiles = <String>[];
    final subscription = Adapty().didUpdateProfileStream.listen((profile) => profiles.add(profile.profileId));
    addTearDown(subscription.cancel);

    Adapty().setupAfterHotRestart();
    await sendEvent('did_load_latest_profile', {'profile': _profile});

    expect(profiles, ['profile-1']);
  });

  test('an event after activate reaches the profile stream', () async {
    final savedLogLevel = AdaptyLogger.logLevel;
    addTearDown(() => AdaptyLogger.logLevel = savedLogLevel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => jsonEncode({'success': true}),
    );
    final profiles = <String>[];
    final subscription = Adapty().didUpdateProfileStream.listen((profile) => profiles.add(profile.profileId));
    addTearDown(subscription.cancel);

    await Adapty().activate(configuration: AdaptyConfiguration(apiKey: 'test-api-key'));
    await sendEvent('did_load_latest_profile', {'profile': _profile});

    expect(profiles, ['profile-1']);
  });

  test('an event with non-string arguments is logged as an error and answered with null', () async {
    final profiles = <String>[];
    final subscription = Adapty().didUpdateProfileStream.listen((profile) => profiles.add(profile.profileId));
    addTearDown(subscription.cancel);
    Adapty().setupAfterHotRestart();

    ByteData? reply;
    final logs = <String>[];
    await runZoned(() async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        _channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('did_load_latest_profile', {'profile': _profile}),
        ),
        (data) => reply = data,
      );
      await pumpEventQueue();
    }, zoneSpecification: ZoneSpecification(print: (_, _, _, line) => logs.add(line)));

    expect(reply, isNotNull, reason: 'the SDK handles the event');
    expect(const StandardMethodCodec().decodeEnvelope(reply!), isNull);
    expect(logs, contains(contains('ERROR: Error in Adapty._handleIncomingMethodCall: ')));
    expect(profiles, isEmpty);
  });

  test(
    'an observer runs with the values, print and error handler of the zone that installed the event handler',
    () async {
      final observer = _ZoneObserver();
      AdaptyUI().setFlowsEventsObserver(observer);
      addTearDown(() => AdaptyUI().setFlowsEventsObserver(null));

      final caught = <Object>[];
      final prints = <String>[];
      runZonedGuarded(
        Adapty().setupAfterHotRestart,
        (error, _) => caught.add(error),
        zoneValues: {#appZoneValue: 'app'},
        zoneSpecification: ZoneSpecification(print: (_, _, _, line) => prints.add(line)),
      );

      // Not handlePlatformMessage, which runs the handler in the zone of its caller: the channel buffers run it in the
      // zone it was set in, as for a message from the native side.
      ServicesBinding.instance.channelBuffers.push(
        _channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(
            'flow_view_did_appear',
            jsonEncode({
              'view': {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
            }),
          ),
        ),
        (_) {},
      );
      await pumpEventQueue();

      expect(observer.zoneValue, 'app');
      expect(prints, contains('printed by the observer'));
      expect(caught, [isA<StateError>().having((e) => e.message, 'message', 'thrown later by the observer')]);
    },
  );

  test('an event the native side sends while activate is in flight reaches the profile stream', () async {
    final savedLogLevel = AdaptyLogger.logLevel;
    addTearDown(() => AdaptyLogger.logLevel = savedLogLevel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      // The native SDK loads the profile while it activates, before it answers the call.
      if (call.method == 'activate') await sendEvent('did_load_latest_profile', {'profile': _profile});
      return jsonEncode({'success': true});
    });
    final profiles = <String>[];
    final subscription = Adapty().didUpdateProfileStream.listen((profile) => profiles.add(profile.profileId));
    addTearDown(subscription.cancel);

    await Adapty().activate(configuration: AdaptyConfiguration(apiKey: 'test-api-key'));

    expect(profiles, ['profile-1']);
  });
}

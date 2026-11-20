/// The runtime the SDK runs on: which one is current, how a test puts its own in place, and that the handling of an
/// event stays on the runtime the event arrived on.
import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/runtime/adapty_native_transport.dart';
import 'package:adapty_flutter/src/runtime/adapty_runtime.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/capturing_log_sink.dart';
import '../support/fake_transport.dart';
import '../support/test_runtime.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

const _profile = {'profile_id': 'profile-1', 'segment_hash': 'segment-hash', 'timestamp': 1, 'is_test_user': false};

const _promotedProduct = {
  'vendor_product_id': 'promoted.product',
  'localized_description': 'Promoted product',
  'localized_title': 'Promoted',
  'price': {'amount': 9.99, 'currency_code': 'USD', 'currency_symbol': r'$', 'localized_string': r'$9.99'},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    // Some tests install the incoming handler of the production runtime on a channel shared by the whole isolate.
    _channel.setMethodCallHandler(null);
  });

  test('current is the production runtime over the adapty channel when nothing is installed', () {
    final transport = AdaptyRuntime.current.transport;

    expect(transport, isA<MethodChannelTransport>());
    expect((transport as MethodChannelTransport).channel.name, 'flutter.adapty.com/adapty');
  });

  test('after debugInstall Adapty() calls go to the installed transport', () async {
    final fake = FakeTransport()..reply('is_activated', false);
    installTestRuntime(transport: fake);

    expect(await Adapty().isActivated(), isFalse);
    expect(fake.calls.single.$1, 'is_activated');
  });

  test('debugDispose removes the event handler of its transport', () async {
    final fake = FakeTransport();
    final runtime = installTestRuntime(transport: fake);
    expect(fake.hasEventHandler, isTrue);

    await runtime.debugDispose();

    expect(fake.hasEventHandler, isFalse);
  });

  test('setupAfterHotRestart on a swapped runtime delivers events through the new transport', () async {
    final fakeB = FakeTransport();
    installTestRuntime(transport: fakeB, withEventHandler: false);
    expect(fakeB.hasEventHandler, isFalse);

    Adapty().setupAfterHotRestart();
    expect(fakeB.hasEventHandler, isTrue);

    final profiles = <String>[];
    final subscription = Adapty().didUpdateProfileStream.listen((profile) => profiles.add(profile.profileId));
    addTearDown(subscription.cancel);
    await fakeB.deliver('did_load_latest_profile', {'profile': _profile});
    await pumpEventQueue();

    expect(profiles, ['profile-1']);
  });

  test('a native call started while handling an event on A goes to A after B is installed', () async {
    final fakeA = FakeTransport()..reply('make_promoted_purchase', {'type': 'user_cancelled'});
    installTestRuntime(transport: fakeA);
    final fakeB = FakeTransport();
    installTestRuntime(transport: fakeB);

    // Nobody listens to the promoted purchase stream, so handling the event completes the purchase itself.
    await fakeA.deliver('did_receive_promoted_purchase', {'product': _promotedProduct});
    await pumpEventQueue();

    expect(fakeA.calls.map((call) => call.$1), ['make_promoted_purchase']);
    expect(fakeB.calls, isEmpty);
  });

  test('activate binds the event handler to the runtime current when it is called', () async {
    final savedLogLevel = AdaptyLogger.logLevel;
    addTearDown(() => AdaptyLogger.logLevel = savedLogLevel);
    final fakeA = FakeTransport()..reply('make_promoted_purchase', {'type': 'user_cancelled'});
    installTestRuntime(transport: fakeA, withEventHandler: false);
    await Adapty().activate(configuration: AdaptyConfiguration(apiKey: 'test-api-key'));
    final fakeB = FakeTransport();
    installTestRuntime(transport: fakeB);

    // Nobody listens to the promoted purchase stream, so handling the event completes the purchase itself.
    await fakeA.deliver('did_receive_promoted_purchase', {'product': _promotedProduct});
    await pumpEventQueue();

    expect(fakeA.calls.map((call) => call.$1), ['activate', 'make_promoted_purchase']);
    expect(fakeB.calls, isEmpty);
  });

  test('inside runBound current is the bound runtime, outside the installed one', () async {
    final installed = installTestRuntime(withEventHandler: false);
    expect(installed.transport, isA<FakeTransport>());
    final bound = AdaptyRuntime(transport: FakeTransport());

    expect(bound.runBound(() => AdaptyRuntime.current), same(bound));
    final afterAnAwait = await bound.runBound(() async {
      await Future<void>.delayed(Duration.zero);
      return AdaptyRuntime.current;
    });
    expect(afterAnAwait, same(bound));
    expect(AdaptyRuntime.current, same(installed));
  });

  test('the SDK ignores a value the app keeps in its zone under the symbol #adaptyRuntime', () async {
    final fake = FakeTransport()..reply('is_activated', true);
    installTestRuntime(transport: fake);

    // The value the call completes with, or the error it fails with.
    final outcome = await Future.sync(
      () => runZoned(() => Adapty().isActivated(), zoneValues: {#adaptyRuntime: 'app value'}),
    ).then<Object?>((value) => value, onError: (Object error) => error);

    expect(outcome, isTrue);
    expect(fake.calls.map((call) => call.$1), ['is_activated']);
  });

  test('a log line written in a zone where the app keeps #adaptyRuntime goes to the log of the current runtime', () {
    final savedLogLevel = AdaptyLogger.logLevel;
    addTearDown(() => AdaptyLogger.logLevel = savedLogLevel);
    AdaptyLogger.logLevel = AdaptyLogLevel.verbose;
    final logSink = CapturingLogSink();
    installTestRuntime(withEventHandler: false, logSink: logSink);

    expect(
      () => runZoned(() => Adapty().setupAfterHotRestart(), zoneValues: {#adaptyRuntime: 'app value'}),
      returnsNormally,
    );
    expect(logSink.lines, [(AdaptyLogLevel.verbose, 'Adapty.setupAfterHotRestart()')]);
  });

  test('debugInstall returns the previous runtime and null restores the production one', () {
    final productionBefore = AdaptyRuntime.current;
    addTearDown(() => AdaptyRuntime.debugInstall(null));
    final a = AdaptyRuntime(transport: FakeTransport());
    final b = AdaptyRuntime(transport: FakeTransport());

    expect(AdaptyRuntime.debugInstall(a), isNull);
    expect(AdaptyRuntime.current, same(a));
    expect(AdaptyRuntime.debugInstall(b), same(a));
    expect(AdaptyRuntime.debugInstall(null), same(b));
    expect(AdaptyRuntime.current, same(productionBefore));
  });

  test('debugDispose of the production runtime throws', () async {
    Adapty().setupAfterHotRestart();
    final profiles = <String>[];
    final subscription = Adapty().didUpdateProfileStream.listen((profile) => profiles.add(profile.profileId));
    addTearDown(subscription.cancel);

    expect(() => AdaptyRuntime.current.debugDispose(), throwsStateError);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('did_load_latest_profile', jsonEncode({'profile': _profile})),
      ),
      (_) {},
    );
    await pumpEventQueue();
    expect(profiles, ['profile-1'], reason: 'the incoming handler of the production runtime is still on the channel');
  });
}

/// The state the SDK keeps between calls belongs to a runtime: what is set or buffered on one runtime is neither seen
/// nor touched by another.
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_transport.dart';
import '../support/test_runtime.dart';

const _profile = {'profile_id': 'profile-1', 'segment_hash': 'segment-hash', 'timestamp': 1, 'is_test_user': false};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an event on runtime A reaches the streams of A and not of B', () async {
    final fakeA = FakeTransport();
    final a = installTestRuntime(transport: fakeA);
    final streamA = a.runBound(() => Adapty().didUpdateProfileStream);
    installTestRuntime();
    final profilesA = <String>[];
    final profilesB = <String>[];
    final subscriptionA = streamA.listen((profile) => profilesA.add(profile.profileId));
    addTearDown(subscriptionA.cancel);
    final subscriptionB = Adapty().didUpdateProfileStream.listen((profile) => profilesB.add(profile.profileId));
    addTearDown(subscriptionB.cancel);

    await fakeA.deliver('did_load_latest_profile', {'profile': _profile});
    await pumpEventQueue();

    expect(profilesA, ['profile-1']);
    expect(profilesB, isEmpty);
  });

  test('debugDispose closes the streams of its runtime', () async {
    final runtime = installTestRuntime();
    final done = <String>[];
    final subscriptions = [
      Adapty().didUpdateProfileStream.listen(null, onDone: () => done.add('profile')),
      Adapty().didReceivePromotedPurchaseStream.listen(null, onDone: () => done.add('promoted purchase')),
      Adapty().onUpdateInstallationDetailsSuccessStream.listen(null, onDone: () => done.add('installation details')),
      Adapty().onUpdateInstallationDetailsFailStream.listen(null, onDone: () => done.add('installation error')),
    ];
    addTearDown(() => Future.wait(subscriptions.map((subscription) => subscription.cancel())));

    await runtime.debugDispose();
    await pumpEventQueue();

    expect(done, unorderedEquals(['profile', 'promoted purchase', 'installation details', 'installation error']));
  });

  test('a second debugDispose leaves an event handler set after the first one in place', () async {
    final fake = FakeTransport();
    final runtime = installTestRuntime(transport: fake);
    await runtime.debugDispose();
    Adapty().setupAfterHotRestart();
    expect(fake.hasEventHandler, isTrue);

    await runtime.debugDispose();

    expect(fake.hasEventHandler, isTrue);
  });
}

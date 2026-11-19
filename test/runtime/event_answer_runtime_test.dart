/// An answer to a native event goes back to the runtime the event arrived on, even when the app gives it later,
/// outside the handling of the event. The resolver is set in this file only; other files run without one.
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_transport.dart';
import '../support/test_runtime.dart';

class _Resolver extends AdaptyUIObserverModeResolver {
  void Function()? onStartRestore;
  void Function()? onFinishRestore;

  @override
  void observerModeDidInitiatePurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    void Function() onStartPurchase,
    void Function() onFinishPurchase,
  ) {}

  @override
  void observerModeDidInitiateRestore(
    AdaptyUIFlowView view,
    void Function() onStartRestore,
    void Function() onFinishRestore,
  ) {
    this.onStartRestore = onStartRestore;
    this.onFinishRestore = onFinishRestore;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a restore the app reports after the event is answered on the runtime of the event', () async {
    final resolver = _Resolver();
    final fakeA = FakeTransport();
    installTestRuntime(transport: fakeA);
    AdaptyUI().setObserverModeResolver(resolver);
    final fakeB = FakeTransport();
    installTestRuntime(transport: fakeB);

    await fakeA.deliver('flow_view_observer_did_initiate_restore', {
      'event_id': 'e2',
      'view': {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
    });
    // The app reports the restore later, from its own code: B is current there.
    resolver.onStartRestore!();
    resolver.onFinishRestore!();
    await pumpEventQueue();

    expect(fakeA.calls.map((call) => call.$1), ['observer_restore_did_start', 'observer_restore_did_finish']);
    expect(fakeA.calls.map((call) => call.$2), [
      {'event_id': 'e2'},
      {'event_id': 'e2'},
    ]);
    expect(fakeB.calls, isEmpty);
  });
}

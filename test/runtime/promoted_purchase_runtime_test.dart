/// A promoted product that no subscription received goes back to the SDK when the last subscription is cancelled: on
/// the runtime the event arrived on, and never once that runtime is disposed.
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_transport.dart';
import '../support/test_runtime.dart';

const _promotedProduct = {
  'vendor_product_id': 'promoted.product',
  'localized_description': 'Promoted product',
  'localized_title': 'Promoted',
  'price': {'amount': 9.99, 'currency_code': 'USD', 'currency_symbol': r'$', 'localized_string': r'$9.99'},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a promoted purchase no subscription received is completed in the runtime of its event', () async {
    final fakeA = FakeTransport()..reply('make_promoted_purchase', {'type': 'user_cancelled'});
    installTestRuntime(transport: fakeA);
    final subscription = Adapty().didReceivePromotedPurchaseStream.listen(null);
    addTearDown(subscription.cancel);
    subscription.pause();
    await fakeA.deliver('did_receive_promoted_purchase', {'product': _promotedProduct});
    final fakeB = FakeTransport();
    installTestRuntime(transport: fakeB);

    await subscription.cancel();
    await pumpEventQueue();

    expect(fakeA.calls.map((call) => call.$1), ['make_promoted_purchase']);
    expect(fakeB.calls, isEmpty);
  });

  test('a promoted purchase a paused subscription holds when the runtime is disposed is not completed', () async {
    final fake = FakeTransport()..reply('make_promoted_purchase', {'type': 'user_cancelled'});
    final runtime = installTestRuntime(transport: fake);
    final subscription = Adapty().didReceivePromotedPurchaseStream.listen(null);
    addTearDown(subscription.cancel);
    subscription.pause();
    await fake.deliver('did_receive_promoted_purchase', {'product': _promotedProduct});

    final disposed = runtime.debugDispose();
    // Disposing waits for the paused subscription, so it has to go first.
    await subscription.cancel();
    await disposed;
    await pumpEventQueue();

    expect(fake.calls.map((call) => call.$1), isNot(contains('make_promoted_purchase')));
  });
}

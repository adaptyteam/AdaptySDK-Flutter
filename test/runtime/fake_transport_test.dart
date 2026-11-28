/// The contract of the in-memory native side the runtime tests build on.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../support/fake_transport.dart';

void main() {
  test('a reply holds for every following call of its method until it is replaced', () async {
    final fake = FakeTransport()..reply('is_activated', true);

    expect(jsonDecode((await fake.invoke('is_activated', '{}'))!), {'success': true});
    expect(jsonDecode((await fake.invoke('is_activated', '{}'))!), {'success': true});

    fake.replyError('is_activated', code: 2002);

    final error = {
      'error': {'adapty_code': 2002, 'message': 'x'},
    };
    expect(jsonDecode((await fake.invoke('is_activated', '{}'))!), error);
    expect(jsonDecode((await fake.invoke('is_activated', '{}'))!), error);
  });

  test('a method without a reply is answered as the native side answers a call without a result', () async {
    expect(await FakeTransport().invoke('get_profile', '{}'), '{"success":true}');
  });

  test('a held method is answered only once its completer completes', () async {
    final fake = FakeTransport()..reply('is_activated', true);
    final hold = fake.hold('is_activated');

    String? reply;
    final call = fake.invoke('is_activated', '{}').then((value) => reply = value);
    await pumpEventQueue();
    expect(reply, isNull);

    hold.complete();
    await call;
    expect(jsonDecode(reply!), {'success': true});
  });

  test('deliver without an event handler names the calls that install one', () {
    expect(
      () => FakeTransport().deliver('did_load_latest_profile', {}),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'no event handler: call Adapty().activate() or setupAfterHotRestart() first',
        ),
      ),
    );
  });
}

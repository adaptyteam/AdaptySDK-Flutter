/// Work the SDK starts and nobody awaits is counted while it runs, and its failure goes to the error sink instead of
/// surfacing as an uncaught error.
import 'dart:async';

import 'package:adapty_flutter/src/runtime/adapty_internal_error_sink.dart';
import 'package:adapty_flutter/src/runtime/background_work.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/collecting_error_sink.dart';
import '../support/fake_transport.dart';
import '../support/test_runtime.dart';

const _promotedProduct = {
  'vendor_product_id': 'promoted.product',
  'localized_description': 'Promoted product',
  'localized_title': 'Promoted',
  'is_family_shareable': true,
  'region_code': 'US',
  'price': {'amount': 9.99, 'currency_code': 'USD', 'currency_symbol': r'$', 'localized_string': r'$9.99'},
};

final class _ThrowingSink implements AdaptyInternalErrorSink {
  @override
  void report(AdaptyInternalErrorRecord record) => throw StateError('the sink failed');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('track counts pending work and idle completes when it drains', () async {
    final sink = CollectingErrorSink();
    final work = BackgroundWork(sink);
    final first = Completer<void>();
    final second = Completer<void>();

    work.track('first', first.future, onError: AdaptyInternalErrorKind.replyFailed);
    work.track('second', second.future, onError: AdaptyInternalErrorKind.replyFailed);
    var idle = false;
    unawaited(work.idle.then((_) => idle = true));

    expect(work.pending, 2);
    first.complete();
    await pumpEventQueue();
    expect(work.pending, 1);
    expect(idle, isFalse);

    second.complete();
    await pumpEventQueue();
    expect(work.pending, 0);
    expect(idle, isTrue);
    expect(sink.records, isEmpty);
  });

  test('a failing tracked future is reported with its label and kind', () async {
    final sink = CollectingErrorSink();
    final work = BackgroundWork(sink);

    work.track('some.label', Future<void>.error(StateError('boom')), onError: AdaptyInternalErrorKind.replyFailed);
    await work.idle;

    expect(work.pending, 0);
    expect(sink.records, hasLength(1));
    final record = sink.records.single;
    expect(record.kind, AdaptyInternalErrorKind.replyFailed);
    expect(record.context, 'some.label');
    expect(record.correlationId, isNull);
    expect(record.error, isA<StateError>().having((e) => e.message, 'message', 'boom'));
    expect(record.stack, isNotNull);
  });

  test('a failing tracked future is reported with the correlation id it was tracked with', () async {
    final sink = CollectingErrorSink();
    final work = BackgroundWork(sink);

    work.track(
      'some.label',
      Future<void>.error(StateError('boom')),
      onError: AdaptyInternalErrorKind.replyFailed,
      correlationId: 'e7',
    );
    await work.idle;

    expect(sink.records, hasLength(1));
    expect(sink.records.single.context, 'some.label');
    expect(sink.records.single.correlationId, 'e7');
  });

  test('a failing tracked future is reported with the place it was tracked with', () async {
    final sink = CollectingErrorSink();
    final work = BackgroundWork(sink);

    work.track(
      'some.label',
      Future<void>.error(StateError('boom')),
      onError: AdaptyInternalErrorKind.replyFailed,
      correlationId: 'e7',
      where: 'Adapty.some_call()',
    );
    await work.idle;

    expect(sink.records, hasLength(1));
    final record = sink.records.single;
    expect(record.where, 'Adapty.some_call()');
    expect(record.kind, AdaptyInternalErrorKind.replyFailed);
    expect(record.context, 'some.label');
    expect(record.correlationId, 'e7');
    expect(record.error, isA<StateError>().having((e) => e.message, 'message', 'boom'));
    expect(record.stack, isNotNull);
  });

  test('a failing tracked future tracked without a place is reported at the place of event handling', () async {
    final sink = CollectingErrorSink();
    final work = BackgroundWork(sink);

    work.track('some.label', Future<void>.error(StateError('boom')), onError: AdaptyInternalErrorKind.replyFailed);
    await work.idle;

    expect(sink.records, hasLength(1));
    expect(sink.records.single.where, 'Adapty._handleIncomingMethodCall');
  });

  test('a sink that throws while reporting a failure does not surface as an uncaught error', () async {
    final work = BackgroundWork(_ThrowingSink());
    final caught = <Object>[];

    await runZonedGuarded(() async {
      work.track('some.label', Future<void>.error(StateError('boom')), onError: AdaptyInternalErrorKind.replyFailed);
      await pumpEventQueue();
    }, (error, _) => caught.add(error));

    expect(caught, isEmpty);
    expect(work.pending, 0);
  });

  test('the promoted auto-completion is pending until its call completes', () async {
    final sink = CollectingErrorSink();
    final fake = FakeTransport()..reply('make_promoted_purchase', {'type': 'user_cancelled'});
    final rt = installTestRuntime(transport: fake, errorSink: sink);
    final held = fake.hold('make_promoted_purchase');

    await fake.deliver('did_receive_promoted_purchase', {'product': _promotedProduct});
    await pumpEventQueue();

    expect(fake.calls.map((call) => call.$1), ['make_promoted_purchase']);
    expect(rt.diagnostics.background.pending, 1);

    held.complete();
    await settle(rt);

    expect(rt.diagnostics.background.pending, 0);
    expect(sink.records, isEmpty);
  });
}

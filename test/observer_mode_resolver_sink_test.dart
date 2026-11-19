/// What the SDK logs and reports when a flow in Observer mode starts a purchase or a restore: a warning when no resolver
/// is set, a report to the error sink when the resolver throws or the event can't be read. The native side gets nothing
/// in any of these cases.
///
/// A test that needs the resolver sets it in its body, right after it installs its runtime; whether it throws is set by
/// [_throwing].
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/runtime/adapty_internal_error_sink.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/capturing_log_sink.dart';
import 'support/collecting_error_sink.dart';
import 'support/fake_transport.dart';
import 'support/test_runtime.dart';

const _view = {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'};

/// A yearly subscription as the iOS SDK reports it.
const _product = {
  'vendor_product_id': 'com.app.yearly',
  'flow_product_id': 'p1',
  'adapty_product_id': 'adapty-yearly',
  'access_level_id': 'premium',
  'product_type': 'annual',
  'paywall_product_index': 0,
  'paywall_variation_id': 'variation-id',
  'paywall_ab_test_name': 'ab-test',
  'paywall_name': 'Paywall',
  'localized_description': 'Premium for a year',
  'localized_title': 'Premium',
  'is_family_shareable': false,
  'region_code': 'DE',
  'price': {'amount': 119.88, 'currency_code': 'EUR', 'currency_symbol': '€', 'localized_string': '119,88 €'},
  'subscription': {
    'group_identifier': '21345678',
    'period': {'unit': 'year', 'number_of_units': 1},
    'localized_period': '1 year',
  },
};

/// Whether the resolver throws.
bool _throwing = false;

void setThrowing(bool value) {
  _throwing = value;
  addTearDown(() => _throwing = false);
}

class _Resolver extends AdaptyUIObserverModeResolver {
  final initiated = <String>[];

  @override
  void observerModeDidInitiatePurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    void Function() onStartPurchase,
    void Function() onFinishPurchase,
  ) {
    initiated.add('purchase ${view.id}');
    if (_throwing) throw StateError('boom');
  }

  @override
  void observerModeDidInitiateRestore(
    AdaptyUIFlowView view,
    void Function() onStartRestore,
    void Function() onFinishRestore,
  ) {
    initiated.add('restore ${view.id}');
    if (_throwing) throw StateError('boom');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('without a resolver only a warning is logged', () async {
    final sink = CollectingErrorSink();
    final logSink = CapturingLogSink();
    final fake = FakeTransport();
    installTestRuntime(transport: fake, errorSink: sink, logSink: logSink);

    await fake.deliver('flow_view_observer_did_initiate_purchase', {
      'event_id': 'e1',
      'view': _view,
      'product': _product,
    });

    expect(logSink.lines, hasLength(1));
    expect(logSink.lines.single.$1, AdaptyLogLevel.warn);
    expect(
      logSink.lines.single.$2,
      allOf(contains("the flow's purchase will not complete"), contains('setObserverModeResolver')),
    );
    expect(sink.records, isEmpty);
    expect(fake.calls, isEmpty);
  });

  test('without a resolver a restore logs only a warning about the restore', () async {
    final sink = CollectingErrorSink();
    final logSink = CapturingLogSink();
    final fake = FakeTransport();
    installTestRuntime(transport: fake, errorSink: sink, logSink: logSink);

    await fake.deliver('flow_view_observer_did_initiate_restore', {'event_id': 'e2', 'view': _view});

    expect(logSink.lines, hasLength(1));
    expect(logSink.lines.single.$1, AdaptyLogLevel.warn);
    expect(
      logSink.lines.single.$2,
      allOf(contains("the flow's restore will not complete"), contains('setObserverModeResolver')),
    );
    expect(sink.records, isEmpty);
    expect(fake.calls, isEmpty);
  });

  test('without a resolver a purchase whose product can\'t be read is reported, not warned about', () async {
    final sink = CollectingErrorSink();
    final logSink = CapturingLogSink();
    final fake = FakeTransport();
    installTestRuntime(transport: fake, errorSink: sink, logSink: logSink);

    await fake.deliver('flow_view_observer_did_initiate_purchase', {'event_id': 'e1', 'view': _view, 'product': 1});

    expect(sink.records, hasLength(1));
    final record = sink.records.single;
    expect(record.kind, AdaptyInternalErrorKind.eventDecodeFailed);
    expect(record.context, 'flow_view_observer_did_initiate_purchase');
    expect(record.correlationId, 'e1');
    expect(logSink.lines.where((line) => line.$1 == AdaptyLogLevel.warn), isEmpty);
    expect(fake.calls, isEmpty);
  });

  test('a throwing resolver is reported as handlerThrew and sends nothing', () async {
    final sink = CollectingErrorSink();
    final logSink = CapturingLogSink();
    final fake = FakeTransport();
    installTestRuntime(transport: fake, errorSink: sink, logSink: logSink);
    final resolver = _Resolver();
    AdaptyUI().setObserverModeResolver(resolver);
    setThrowing(true);

    await fake.deliver('flow_view_observer_did_initiate_purchase', {
      'event_id': 'e1',
      'view': _view,
      'product': _product,
    });

    expect(resolver.initiated, ['purchase view-1']);
    expect(sink.records, hasLength(1));
    final record = sink.records.single;
    expect(record.kind, AdaptyInternalErrorKind.handlerThrew);
    expect(record.context, 'flow_view_observer_did_initiate_purchase');
    expect(record.correlationId, 'e1');
    expect(record.error, isA<StateError>().having((e) => e.message, 'message', 'boom'));
    expect(logSink.lines.where((line) => line.$1 == AdaptyLogLevel.warn), isEmpty);
    expect(fake.calls, isEmpty);
  });

  test('a broken observer-mode restore with a resolver is reported with its event id and skips the resolver', () async {
    final sink = CollectingErrorSink();
    final logSink = CapturingLogSink();
    final fake = FakeTransport();
    installTestRuntime(transport: fake, errorSink: sink, logSink: logSink);
    final resolver = _Resolver();
    AdaptyUI().setObserverModeResolver(resolver);

    await fake.deliver('flow_view_observer_did_initiate_restore', {'event_id': 'e2', 'view': 1});

    expect(resolver.initiated, isEmpty);
    expect(sink.records, hasLength(1));
    final record = sink.records.single;
    expect(record.kind, AdaptyInternalErrorKind.eventDecodeFailed);
    expect(record.context, 'flow_view_observer_did_initiate_restore');
    expect(record.correlationId, 'e2');
    expect(record.error, isA<TypeError>());
    expect(logSink.lines.where((line) => line.$1 == AdaptyLogLevel.warn), isEmpty);
    expect(fake.calls, isEmpty);
  });
}

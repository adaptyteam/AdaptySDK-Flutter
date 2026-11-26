/// A value the native side sends that this SDK version doesn't know, and reads anyway — a purchase result type as
/// pending, an installation status as not determined — is one warning in the log sink of the runtime the answer or the
/// event belongs to: never printed past that sink, never written to another runtime, never an error record.
import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_paywall_product.dart';
import 'package:adapty_flutter/src/runtime/adapty_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/capturing_log_sink.dart';
import 'support/fake_transport.dart';
import 'support/test_runtime.dart';

const _view = {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'};

const _product = {
  'vendor_product_id': 'com.app.yearly',
  'adapty_product_id': 'adapty-yearly',
  'access_level_id': 'premium',
  'product_type': 'annual',
  'paywall_product_index': 0,
  'paywall_variation_id': 'variation-id',
  'paywall_ab_test_name': 'ab-test',
  'paywall_name': 'Paywall',
  'localized_description': 'Premium for a year',
  'localized_title': 'Premium',
  'price': {'amount': 119.88, 'currency_code': 'EUR', 'currency_symbol': '€', 'localized_string': '119,88 €'},
};

String _purchaseWarning(String type) =>
    'Adapty received a purchase result type this SDK version doesn\'t know, "$type", and reads it as pending.';

String _statusWarning(String status) =>
    'Adapty received an installation status this SDK version doesn\'t know, "$status", and reads it as not determined.';

/// Keeps the purchase results of the flows that reach it.
class _FlowObserver extends AdaptyUIFlowsEventsObserver {
  final purchases = <AdaptyPurchaseResult>[];

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) => purchases.add(purchaseResult);

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) {}
}

/// The warning lines of [sink].
List<(AdaptyLogLevel, String)> _warnings(CapturingLogSink sink) =>
    sink.lines.where((line) => line.$1 == AdaptyLogLevel.warn).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AdaptyLogLevel savedLogLevel;
  setUp(() {
    savedLogLevel = AdaptyLogger.logLevel;
    AdaptyLogger.logLevel = AdaptyLogLevel.info;
  });
  tearDown(() => AdaptyLogger.logLevel = savedLogLevel);

  /// Runs [body] where nothing may be printed, and returns what was printed.
  Future<List<String>> printedBy(Future<void> Function() body) async {
    final printed = <String>[];
    await runZoned(body, zoneSpecification: ZoneSpecification(print: (_, _, _, line) => printed.add(line)));
    return printed;
  }

  /// Installs the runtime A over [fake], with the event handler on it, and then the runtime B, which stays current: a
  /// line that belongs to A and goes to the current runtime instead lands in B. Returns the log sinks of A and B.
  (AdaptyRuntime, CapturingLogSink, CapturingLogSink) twoRuntimes(FakeTransport fake) {
    final sinkA = CapturingLogSink();
    final sinkB = CapturingLogSink();
    final a = installTestRuntime(transport: fake, logSink: sinkA);
    installTestRuntime(logSink: sinkB, withEventHandler: false);
    return (a, sinkA, sinkB);
  }

  test('an installation status it does not know is one warning in the log of the runtime of the call', () async {
    final fake = FakeTransport()..reply('get_current_installation_status', {'status': 'future_status'});
    final (a, sinkA, sinkB) = twoRuntimes(fake);

    late AdaptyInstallationStatus status;
    final printed = await printedBy(() async {
      status = await a.runBound(() => Adapty().getCurrentInstallationStatus());
    });

    expect(status, isA<AdaptyInstallationStatusNotDetermined>());
    expect(_warnings(sinkA), [(AdaptyLogLevel.warn, _statusWarning('future_status'))]);
    expect(_warnings(sinkB), isEmpty);
    expect(printed, isEmpty);
  });

  test('a purchase result type it does not know is one warning in the log of the runtime of the call', () async {
    final fake = FakeTransport()..reply('make_purchase', {'type': 'future_result'});
    final (a, sinkA, sinkB) = twoRuntimes(fake);

    late AdaptyPurchaseResult result;
    final printed = await printedBy(() async {
      result = await a.runBound(
        () => Adapty().makePurchase(product: AdaptyPaywallProductJSONBuilder.fromJsonValue(_product)),
      );
    });

    expect(result, isA<AdaptyPurchaseResultPending>());
    expect(_warnings(sinkA), [(AdaptyLogLevel.warn, _purchaseWarning('future_result'))]);
    expect(_warnings(sinkB), isEmpty);
    expect(printed, isEmpty);
  });

  test('a flow purchase with a result type it does not know is one warning in the log of the runtime of the '
      'event', () async {
    final fake = FakeTransport();
    final (a, sinkA, sinkB) = twoRuntimes(fake);
    final observer = _FlowObserver();
    a.runBound(() => AdaptyUI().setFlowsEventsObserver(observer));

    final printed = await printedBy(() async {
      await fake.deliver('flow_view_did_finish_purchase', {
        'view': _view,
        'product': _product,
        'purchased_result': {'type': 'future_result'},
      });
      await pumpEventQueue();
    });

    expect(observer.purchases, [isA<AdaptyPurchaseResultPending>()]);
    expect(_warnings(sinkA), [(AdaptyLogLevel.warn, _purchaseWarning('future_result'))]);
    expect(_warnings(sinkB), isEmpty);
    expect(printed, isEmpty);
  });

  test('each value it reads anyway is a warning of its own', () async {
    final fake = FakeTransport();
    final sink = CapturingLogSink();
    installTestRuntime(transport: fake, logSink: sink);
    final observer = _FlowObserver();
    AdaptyUI().setFlowsEventsObserver(observer);

    for (final type in ['deferred', 'future_result']) {
      await fake.deliver('flow_view_did_finish_purchase', {
        'view': _view,
        'product': _product,
        'purchased_result': {'type': type},
      });
    }
    fake.reply('get_current_installation_status', {'status': 'future_status'});
    await Adapty().getCurrentInstallationStatus();

    expect(observer.purchases, [isA<AdaptyPurchaseResultPending>(), isA<AdaptyPurchaseResultPending>()]);
    expect(_warnings(sink), [
      (AdaptyLogLevel.warn, _purchaseWarning('deferred')),
      (AdaptyLogLevel.warn, _purchaseWarning('future_result')),
      (AdaptyLogLevel.warn, _statusWarning('future_status')),
    ]);
  });
}

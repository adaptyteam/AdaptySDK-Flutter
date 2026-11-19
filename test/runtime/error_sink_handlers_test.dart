/// The errors the SDK swallows around the system requests handler and the observer mode resolver go to the error
/// sink of the runtime, with their kind, the event or call they came from and the request id.
///
/// Every test sets the handler and the resolver in its body, right after it installs its runtime; what they do is set
/// by [_throwing]. The cases without them are in `error_sink_without_handlers_test.dart`.
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/runtime/adapty_internal_error_sink.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/collecting_error_sink.dart';
import '../support/fake_transport.dart';
import '../support/test_runtime.dart';

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

/// Whether the handler and the resolver throw; otherwise the handler grants every permission.
bool _throwing = false;

class _Recording extends AdaptyUISystemRequestsHandler implements AdaptyUIObserverModeResolver {
  @override
  Future<AdaptyUIPermissionResult> handlePermission(
    AdaptyUIFlowView view,
    AdaptyUIPermission permission,
    Map<String, String>? customArgs,
  ) async {
    if (_throwing) throw StateError('boom');
    return const AdaptyUIPermissionResult.granted();
  }

  @override
  void observerModeDidInitiatePurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    void Function() onStartPurchase,
    void Function() onFinishPurchase,
  ) {
    if (_throwing) throw StateError('boom');
  }

  @override
  void observerModeDidInitiateRestore(
    AdaptyUIFlowView view,
    void Function() onStartRestore,
    void Function() onFinishRestore,
  ) {
    if (_throwing) throw StateError('boom');
  }
}

final _recording = _Recording();

class _ThrowingObserver extends AdaptyUIFlowsEventsObserver {
  @override
  void flowViewDidAppear(AdaptyUIFlowView view) => throw StateError('observer boom');

  @override
  void flowViewDidFinishPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product, AdaptyPurchaseResult result) {}

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) {}
}

void setThrowing(bool value) {
  _throwing = value;
  addTearDown(() => _throwing = false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a decode failure, a throwing observer, a throwing handler and a failed permission answer are reported with their '
    'kinds',
    () async {
      final sink = CollectingErrorSink();
      final fake = FakeTransport();
      installTestRuntime(transport: fake, errorSink: sink);
      AdaptyUI().setSystemRequestsHandler(_recording);
      AdaptyUI().setObserverModeResolver(_recording);
      AdaptyUI().registerFlowEventsListener(_ThrowingObserver(), 'view-2');
      addTearDown(() => AdaptyUI().unregisterFlowEventsListener('view-2'));
      final request = {'event_id': 'hr_1', 'view': _view, 'permission': 'camera'};

      await fake.deliver('flow_view_did_appear', {'view': 1});
      await fake.deliver('flow_view_did_appear', {
        'view': {'id': 'view-2', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
      });
      setThrowing(true);
      await fake.deliver('flow_view_did_ask_permission', request);
      _throwing = false;
      fake.replyError('flow_view_did_answer_permission', code: 2002);
      await fake.deliver('flow_view_did_ask_permission', request);

      expect(sink.records.map((record) => record.kind), [
        AdaptyInternalErrorKind.eventDecodeFailed,
        AdaptyInternalErrorKind.observerThrew,
        AdaptyInternalErrorKind.handlerThrew,
        AdaptyInternalErrorKind.replyFailed,
      ]);
      expect(sink.records.map((record) => record.context), [
        'flow_view_did_appear',
        'flow_view_did_appear',
        'flow_view_did_ask_permission',
        'flow_view_did_answer_permission',
      ]);
      expect(sink.records.map((record) => record.correlationId), [null, null, 'hr_1', 'hr_1']);
      expect(sink.records[1].error, isA<StateError>().having((e) => e.message, 'message', 'observer boom'));
      expect(sink.records[2].error, isA<StateError>().having((e) => e.message, 'message', 'boom'));
      expect(sink.records[3].error, isA<AdaptyError>().having((e) => e.code, 'code', 2002));
      expect(fake.calls.map((call) => call.$1), ['flow_view_did_answer_permission']);
    },
  );

  test('a throwing resolver is reported as handlerThrew', () async {
    final sink = CollectingErrorSink();
    final fake = FakeTransport();
    installTestRuntime(transport: fake, errorSink: sink);
    AdaptyUI().setSystemRequestsHandler(_recording);
    AdaptyUI().setObserverModeResolver(_recording);
    setThrowing(true);

    await fake.deliver('flow_view_observer_did_initiate_purchase', {
      'event_id': 'e1',
      'view': _view,
      'product': _product,
    });

    expect(sink.records, hasLength(1));
    final record = sink.records.single;
    expect(record.kind, AdaptyInternalErrorKind.handlerThrew);
    expect(record.context, 'flow_view_observer_did_initiate_purchase');
    expect(record.correlationId, 'e1');
    expect(record.error, isA<StateError>().having((e) => e.message, 'message', 'boom'));
    expect(fake.calls, isEmpty);
  });
}

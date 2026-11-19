/// The state the SDK keeps between calls belongs to a runtime: what is set or buffered on one runtime is neither seen
/// nor touched by another.
import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adaptyui/adaptyui_flow_view.dart' show AdaptyUIFlowViewJSONBuilder;
import 'package:adapty_flutter/src/runtime/adapty_internal_error_sink.dart';
import 'package:adapty_flutter/src/runtime/adapty_platform_info.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/collecting_error_sink.dart';
import '../support/fake_transport.dart';
import '../support/test_platform_info.dart';
import '../support/test_runtime.dart';

const _profile = {'profile_id': 'profile-1', 'segment_hash': 'segment-hash', 'timestamp': 1, 'is_test_user': false};

const _view = {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'};

const _embeddedView = {'id': 'flutter_native_7', 'placement_id': 'placement-id', 'variation_id': 'variation-id'};

const _notSupported = {'adapty_code': 4001, 'message': 'not supported'};

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

/// Records the system requests and observer-mode events that reach it in [events].
class _Handlers extends AdaptyUISystemRequestsHandler implements AdaptyUIObserverModeResolver {
  _Handlers([List<String>? events]) : events = events ?? [];

  final List<String> events;
  void Function()? onStartPurchase;

  @override
  Future<AdaptyUIPermissionResult> handlePermission(
    AdaptyUIFlowView view,
    AdaptyUIPermission permission,
    Map<String, String>? customArgs,
  ) async {
    events.add('permission');
    return const AdaptyUIPermissionResult.granted();
  }

  @override
  Future<void> handleAppReviewRequest(AdaptyUIFlowView view) async => events.add('app review');

  @override
  void observerModeDidInitiatePurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    void Function() onStartPurchase,
    void Function() onFinishPurchase,
  ) {
    events.add('observer purchase');
    this.onStartPurchase = onStartPurchase;
  }

  @override
  void observerModeDidInitiateRestore(
    AdaptyUIFlowView view,
    void Function() onStartRestore,
    void Function() onFinishRestore,
  ) => events.add('observer restore');
}

/// Records the appearing views that reach it in [events].
class _Observer extends AdaptyUIFlowsEventsObserver {
  _Observer([List<String>? events]) : events = events ?? [];

  final List<String> events;

  @override
  void flowViewDidAppear(AdaptyUIFlowView view) => events.add('appear ${view.id}');

  @override
  void flowViewDidFinishPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product, AdaptyPurchaseResult result) {}

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) {}
}

class _ThrowingWidget extends AdaptyUIFlowsEventsObserver {
  @override
  void flowViewDidFinishPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product, AdaptyPurchaseResult result) {}

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) => throw StateError('widget boom');
}

class _Widget extends AdaptyUIFlowsEventsObserver {
  final errors = <String>[];

  @override
  void flowViewDidFinishPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product, AdaptyPurchaseResult result) {}

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) => errors.add(view.id);
}

TestPlatformInfo _platformWithLogTag(String logTag) => TestPlatformInfo(
  isIOS: logTag == 'i',
  isAndroid: logTag == 'a',
  viewKind: AdaptyPlatformViewKind.none,
  logTag: logTag,
);

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

  test('observers, handler and resolver set on one runtime are absent from a fresh one', () async {
    installTestRuntime();
    final events = <String>[];
    final handlers = _Handlers(events);
    AdaptyUI().setSystemRequestsHandler(handlers);
    AdaptyUI().setObserverModeResolver(handlers);
    AdaptyUI().setFlowsEventsObserver(_Observer(events));
    final fakeB = FakeTransport();
    installTestRuntime(transport: fakeB);

    await fakeB.deliver('flow_view_did_ask_permission', {'event_id': 'hr_1', 'view': _view, 'permission': 'camera'});
    await fakeB.deliver('flow_view_observer_did_initiate_purchase', {
      'event_id': 'e1',
      'view': _view,
      'product': _product,
    });
    await fakeB.deliver('flow_view_did_appear', {'view': _view});
    await pumpEventQueue();

    expect(events, isEmpty);
    expect(fakeB.calls, isEmpty, reason: 'without a handler the permission request is left unanswered');
  });

  test('an event on runtime A reaches the observer set on A, not the one set on B', () async {
    final fakeA = FakeTransport();
    installTestRuntime(transport: fakeA);
    final observerA = _Observer();
    AdaptyUI().setFlowsEventsObserver(observerA);
    installTestRuntime();
    final observerB = _Observer();
    AdaptyUI().setFlowsEventsObserver(observerB);

    await fakeA.deliver('flow_view_did_appear', {'view': _view});

    expect(observerA.events, ['appear view-1']);
    expect(observerB.events, isEmpty);
  });

  test('an embedded view error buffered in runtime A is not replayed to a widget registering in runtime B', () async {
    final fakeA = FakeTransport();
    installTestRuntime(transport: fakeA);
    await fakeA.deliver('flow_view_did_receive_error', {'view': _embeddedView, 'error': _notSupported});
    installTestRuntime();
    final widget = _Widget();

    AdaptyUI().registerFlowEventsListener(widget, 'flutter_native_7');

    expect(widget.errors, isEmpty);
  });

  test('a widget that throws on a replayed error is reported to the sink of the runtime that kept the error', () async {
    final sinkA = CollectingErrorSink();
    final fakeA = FakeTransport();
    final a = installTestRuntime(transport: fakeA, errorSink: sinkA);
    await fakeA.deliver('flow_view_did_receive_error', {'view': _embeddedView, 'error': _notSupported});
    final sinkB = CollectingErrorSink();
    installTestRuntime(errorSink: sinkB);

    // An embedded view registers with the runtime it was created in, whichever runtime is current by then.
    a.ui.eventsProxy.registerFlowEventsListener(_ThrowingWidget(), 'flutter_native_7');

    expect(sinkA.records.map((record) => record.kind), [AdaptyInternalErrorKind.observerThrew]);
    expect(sinkB.records, isEmpty);
  });

  test('an observer-mode answer the app reports after B is installed is logged by the runtime of the event', () async {
    final savedLogLevel = AdaptyLogger.logLevel;
    addTearDown(() => AdaptyLogger.logLevel = savedLogLevel);
    final fakeA = FakeTransport();
    installTestRuntime(transport: fakeA, platform: _platformWithLogTag('a'));
    final resolver = _Handlers();
    AdaptyUI().setObserverModeResolver(resolver);
    installTestRuntime(platform: _platformWithLogTag('i'));
    await fakeA.deliver('flow_view_observer_did_initiate_purchase', {
      'event_id': 'e1',
      'view': _view,
      'product': _product,
    });
    AdaptyLogger.logLevel = AdaptyLogLevel.verbose;

    final lines = <String>[];
    await runZoned(() async {
      resolver.onStartPurchase!();
      await pumpEventQueue();
    }, zoneSpecification: ZoneSpecification(print: (_, _, _, line) => lines.add(line)));

    expect(fakeA.calls.map((call) => call.$1), ['observer_purchase_did_start']);
    expect(lines, isNotEmpty);
    expect(lines, everyElement(startsWith('[AdaptyFlutter a')));
  });

  test('sendAppMessage takes its message_id from the runtime', () async {
    final fake = FakeTransport();
    installTestRuntime(transport: fake, newMessageId: () => 'id-1');

    await AdaptyUI().sendAppMessage(AdaptyUIFlowViewJSONBuilder.fromJsonValue(_view), {'a': 1});

    expect(fake.calls.single.$1, 'adapty_ui_send_app_message');
    expect(fake.calls.single.$2['message_id'], 'id-1');
  });
}

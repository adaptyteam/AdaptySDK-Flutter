import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

const _message =
    'AdaptyUIError.platformNotSupported (Code: 4001): The current platform does not meet the minimum requirements '
    'for AdaptyUI SDK. This error typically occurs when trying to use AdaptyUI on an unsupported platform '
    'or OS version.';
const _detail = 'AdaptyUI SDK is not supported on this platform. Please check the platform compatibility requirements.';

class _Observer extends AdaptyUIFlowsEventsObserver {
  _Observer({this.throwOnError = false});

  final bool throwOnError;
  final errors = <(AdaptyUIFlowView, AdaptyError)>[];

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) {}

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) {
    errors.add((view, error));
    if (throwOnError) throw StateError('the app failed to handle the error');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  final usedIds = <String>{};

  Map<String, dynamic> viewJson(String viewId) => {
    'id': viewId,
    'placement_id': 'placement-id',
    'variation_id': 'variation-id',
  };

  Future<void> sendEvent(String method, Map<String, dynamic> arguments) async {
    usedIds.add((arguments['view'] as Map<String, dynamic>)['id'] as String);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, jsonEncode(arguments))),
      (_) {},
    );
    await pumpEventQueue();
  }

  // The event the iOS platform view sends below iOS 16.
  Future<void> sendPlatformNotSupported(String viewId) => sendEvent('flow_view_did_receive_error', {
    'id': 'flow_view_did_receive_error',
    'view': viewJson(viewId),
    'error': {'adapty_code': 4001, 'message': _message, 'detail': _detail},
  });

  void register(AdaptyUIFlowsEventsObserver observer, String viewId) {
    usedIds.add(viewId);
    AdaptyUI().registerFlowEventsListener(observer, viewId);
  }

  Iterable<MethodCall> dismissCalls() => calls.where((call) => call.method == 'adapty_ui_dismiss_flow_view');

  String requestedViewId(MethodCall call) =>
      (jsonDecode(call.arguments as String) as Map<String, dynamic>)['id'] as String;

  setUp(() {
    calls.clear();
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      if (call.method == 'adapty_ui_dismiss_flow_view') return jsonEncode({'success': true});
      return null;
    });
  });

  tearDown(() {
    AdaptyUI().setFlowsEventsObserver(null);
    for (final id in usedIds) {
      AdaptyUI().unregisterFlowEventsListener(id);
    }
    usedIds.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('an embedded view error that arrives before the widget listens reaches the widget when it does', () async {
    final observer = _Observer();
    final widget = _Observer();
    AdaptyUI().setFlowsEventsObserver(observer);

    await sendPlatformNotSupported('flutter_native_10');

    expect(observer.errors, hasLength(1));
    expect(widget.errors, isEmpty);

    register(widget, 'flutter_native_10');

    expect(widget.errors, hasLength(1));
    final (view, error) = widget.errors.single;
    expect(error.code, AdaptyErrorCode.platformNotSupported);
    expect(error.message, _message);
    expect(error.detail, _detail);
    expect(view.id, 'flutter_native_10');
    expect(view.placementId, 'placement-id');
    expect(view.variationId, 'variation-id');
    expect(view.locale, isNull);
    expect(observer.errors, hasLength(1));

    register(widget, 'flutter_native_10');

    expect(widget.errors, hasLength(1));
    expect(calls, isEmpty);
  });

  test(
    'an embedded view error that arrives after the widget listens reaches the widget and the observer once',
    () async {
      final observer = _Observer();
      final widget = _Observer();
      AdaptyUI().setFlowsEventsObserver(observer);
      register(widget, 'flutter_native_11');

      await sendPlatformNotSupported('flutter_native_11');

      expect(widget.errors, hasLength(1));
      expect(widget.errors.single.$2.code, AdaptyErrorCode.platformNotSupported);
      expect(observer.errors, hasLength(1));
      expect(observer.errors.single.$2.code, AdaptyErrorCode.platformNotSupported);
      expect(calls, isEmpty);
    },
  );

  test('without an observer set, an early embedded view error is not dismissed', () async {
    final widget = _Observer();

    await sendPlatformNotSupported('flutter_native_12');

    expect(dismissCalls(), isEmpty);

    register(widget, 'flutter_native_12');

    expect(widget.errors, hasLength(1));
    expect(widget.errors.single.$2.code, AdaptyErrorCode.platformNotSupported);
    expect(dismissCalls(), isEmpty);
  });

  test('unregistering a view drops its pending error', () async {
    final widget = _Observer();

    await sendPlatformNotSupported('flutter_native_13');
    AdaptyUI().unregisterFlowEventsListener('flutter_native_13');
    register(widget, 'flutter_native_13');

    expect(widget.errors, isEmpty);
  });

  test('a modal view error without an observer still goes to the default observer', () async {
    const viewId = '6f1c2a8e-3b4d-4e5f-8a9b-0c1d2e3f4a5b';

    await sendPlatformNotSupported(viewId);

    expect(dismissCalls().map(requestedViewId), [viewId]);
  });

  test('the pending embedded view errors are capped', () async {
    for (var i = 100; i <= 116; i++) {
      await sendPlatformNotSupported('flutter_native_$i');
    }

    final oldest = _Observer();
    final oldestKept = _Observer();
    final newest = _Observer();
    register(oldest, 'flutter_native_100');
    register(oldestKept, 'flutter_native_101');
    register(newest, 'flutter_native_116');

    expect(oldest.errors, isEmpty);
    expect(oldestKept.errors, hasLength(1));
    expect(newest.errors, hasLength(1));
  });

  test('an error thrown by the widget on a pending error is logged, not rethrown', () async {
    final widget = _Observer(throwOnError: true);

    await sendPlatformNotSupported('flutter_native_17');

    final printed = <String>[];
    runZoned(
      () => expect(() => register(widget, 'flutter_native_17'), returnsNormally),
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => printed.add(line)),
    );

    expect(widget.errors, hasLength(1));
    expect(printed.where((line) => line.contains('ERROR: Error in flowViewDidReceiveError: Bad state')), hasLength(1));
  });

  test('close of an embedded view nobody listens to is left to its widget', () async {
    await sendEvent('flow_view_did_perform_action', {
      'id': 'flow_view_did_perform_action',
      'view': viewJson('flutter_native_18'),
      'action': {'type': 'close'},
    });

    expect(dismissCalls().map(requestedViewId), isEmpty);
  });

  test('an observer that throws on an early embedded view error does not take it from the widget', () async {
    final observer = _Observer(throwOnError: true);
    final widget = _Observer();
    AdaptyUI().setFlowsEventsObserver(observer);

    await sendPlatformNotSupported('flutter_native_19');

    expect(observer.errors, hasLength(1));

    register(widget, 'flutter_native_19');

    expect(widget.errors, hasLength(1));
    expect(widget.errors.single.$2.code, AdaptyErrorCode.platformNotSupported);
  });
}

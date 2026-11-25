import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

class _Observer extends AdaptyUIFlowsEventsObserver {
  final errors = <(AdaptyUIFlowView, AdaptyError)>[];
  final actions = <(AdaptyUIFlowView, AdaptyUIAction)>[];

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) {}

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) => errors.add((view, error));

  @override
  void flowViewDidPerformAction(AdaptyUIFlowView view, AdaptyUIAction action) => actions.add((view, action));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  final printed = <String>[];
  final usedIds = <String>{};

  Map<String, dynamic> errorEvent(String viewId, int code) => {
    'id': 'flow_view_did_receive_error',
    'view': {'id': viewId, 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
    'error': {'adapty_code': code, 'message': 'the flow reported an error'},
  };

  /// Delivers the event in a guarded zone and returns what escaped it uncaught.
  Future<List<Object>> sendEvent(String viewId, Map<String, dynamic> event) async {
    usedIds.add(viewId);
    final caught = <Object>[];
    await runZonedGuarded(
      () async {
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
          _channel.name,
          const StandardMethodCodec().encodeMethodCall(MethodCall(event['id'] as String, jsonEncode(event))),
          (_) {},
        );
        await pumpEventQueue();
      },
      (error, _) => caught.add(error),
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => printed.add(line)),
    );
    return caught;
  }

  Future<List<Object>> sendError(String viewId, int code) => sendEvent(viewId, errorEvent(viewId, code));

  /// What the Android SDK sends when the user presses the system Back button in a flow.
  Future<List<Object>> sendSystemBack(String viewId) => sendEvent(viewId, {
    'id': 'flow_view_did_perform_action',
    'view': {'id': viewId, 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
    'action': {'type': 'system_back'},
  });

  /// Sends each code, without an observer, to a presented view of its own and returns, per code,
  /// every native call, uncaught error and printed log line it caused.
  Future<Map<int, List<String>>> effectsOfErrorsWithoutObserver(List<int> codes) async {
    final effects = <int, List<String>>{};
    for (final code in codes) {
      calls.clear();
      printed.clear();
      final caught = await sendError('presented-view-$code', code);
      final found = [
        ...calls.map((call) => 'native call ${call.method}'),
        ...caught.map((error) => 'uncaught $error'),
        ...printed.map((line) => 'log $line'),
      ];
      if (found.isNotEmpty) effects[code] = found;
    }
    return effects;
  }

  void register(AdaptyUIFlowsEventsObserver observer, String viewId) {
    usedIds.add(viewId);
    AdaptyUI().registerFlowEventsListener(observer, viewId);
  }

  setUp(() {
    calls.clear();
    printed.clear();
    // The SDK default, restated so the suite does not depend on what ran before it: `info`, `warn`
    // and `error` lines print at this level, `verbose` ones do not.
    AdaptyLogger.logLevel = AdaptyLogLevel.info;
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return jsonEncode({
        'error': {'adapty_code': 3001, 'message': 'the view is not found'},
      });
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

  test('without an observer, a runtime error code both native SDKs define leaves a presented flow on screen', () async {
    final effects = await effectsOfErrorsWithoutObserver([
      AdaptyErrorCode.wrongAssetType,
      AdaptyErrorCode.jsException,
      AdaptyErrorCode.navigatorNotFound,
      AdaptyErrorCode.invalidActionURL,
    ]);

    expect(effects, isEmpty);
  });

  test('without an observer, an iOS runtime error leaves a presented flow on screen', () async {
    final effects = await effectsOfErrorsWithoutObserver([
      AdaptyErrorCode.wrongComponentType,
      AdaptyErrorCode.unsupportedURLScheme,
    ]);

    expect(effects, isEmpty);
  });

  test('without an observer, an error with an unknown code leaves a presented flow on screen', () async {
    final effects = await effectsOfErrorsWithoutObserver([4999, AdaptyErrorCode.unknown]);

    expect(effects, isEmpty);
  });

  test('an observer set by the app gets the error once, and the SDK makes no call', () async {
    final observer = _Observer();
    AdaptyUI().setFlowsEventsObserver(observer);

    final caught = await sendError('presented-view', AdaptyErrorCode.jsException);

    expect(observer.errors, hasLength(1));
    expect(observer.errors.single.$1.id, 'presented-view');
    expect(observer.errors.single.$2.code, AdaptyErrorCode.jsException);
    expect(calls, isEmpty);
    expect(caught, isEmpty);
  });

  test('without an observer, a runtime error of a mounted embedded flow reaches its widget with no SDK call', () async {
    final widget = _Observer();
    register(widget, 'flutter_native_30');

    final caught = await sendError('flutter_native_30', AdaptyErrorCode.jsException);

    expect(widget.errors, hasLength(1));
    expect(widget.errors.single.$2.code, AdaptyErrorCode.jsException);
    expect(calls, isEmpty);
    expect(caught, isEmpty);
  });

  test('without an observer, a runtime error of an embedded flow nobody listens to waits for its widget', () async {
    final widget = _Observer();

    final caught = await sendError('flutter_native_31', AdaptyErrorCode.jsException);

    expect(calls, isEmpty);
    expect(caught, isEmpty);

    register(widget, 'flutter_native_31');

    expect(widget.errors, hasLength(1));
    expect(widget.errors.single.$2.code, AdaptyErrorCode.jsException);
    expect(calls, isEmpty);
  });

  test('without an observer, the Android system back action leaves a presented flow on screen', () async {
    final caught = await sendSystemBack('presented-view');

    expect(calls.map((call) => call.method), isEmpty);
    expect(caught, isEmpty);
    expect(printed, isEmpty);
  });

  test('an observer set by the app gets the Android system back action once, and the SDK makes no call', () async {
    final observer = _Observer();
    AdaptyUI().setFlowsEventsObserver(observer);

    final caught = await sendSystemBack('presented-view');

    expect(observer.actions, hasLength(1));
    expect(observer.actions.single.$1.id, 'presented-view');
    expect(observer.actions.single.$2, isA<AndroidSystemBackAction>());
    expect(calls, isEmpty);
    expect(caught, isEmpty);
  });
}

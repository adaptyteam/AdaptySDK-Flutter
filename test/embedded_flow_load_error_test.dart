import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

const _notActivatedMessage =
    'AdaptyUIError.adaptyUINotActivated (Code: 4003): AdaptyUI SDK is not initialized. '
    'Ensure AdaptyUI.activate() is called before any UI-related operations.';
const _notActivatedDetail =
    'AdaptyUI SDK must be initialized before using its methods. Please call AdaptyUI.activate() first.';
const _unknownMessage =
    'Unknown: The operation couldn\u2019t be completed. (AdaptyPlugin.AdaptyPluginInternalError error 1.)';
const _unknownDetail = 'AdaptyPluginError.unknown: notExist("Asset assets/missing.png not found")';
const _noLayoutMessage = 'AdaptyFlow.viewConfiguration is nil';
const _noLayoutDetail =
    'AdaptyError.wrongParam([4.4.1]: Adapty/Adapty+UIBuilder.swift#42, AdaptyFlow.viewConfiguration is nil)';

class _Observer extends AdaptyUIFlowsEventsObserver {
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

  // The event the iOS platform view sends when the flow fails to load into it.
  Future<void> sendLoadError(String viewId, int code, String message, String detail) =>
      sendEvent('flow_view_did_receive_error', {
        'id': 'flow_view_did_receive_error',
        'view': viewJson(viewId),
        'error': {'adapty_code': code, 'message': message, 'detail': detail},
      });

  void register(AdaptyUIFlowsEventsObserver observer, String viewId) {
    usedIds.add(viewId);
    AdaptyUI().registerFlowEventsListener(observer, viewId);
  }

  Iterable<MethodCall> dismissCalls() => calls.where((call) => call.method == 'adapty_ui_dismiss_flow_view');

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

  test('a load error that arrives before the widget listens reaches the widget when it does', () async {
    final observer = _Observer();
    final widget = _Observer();
    AdaptyUI().setFlowsEventsObserver(observer);

    await sendLoadError('flutter_native_30', 4003, _notActivatedMessage, _notActivatedDetail);
    expect(observer.errors, hasLength(1));
    expect(widget.errors, isEmpty);

    register(widget, 'flutter_native_30');

    expect(widget.errors, hasLength(1));
    final (view, error) = widget.errors.single;
    expect(error.code, AdaptyErrorCode.adaptyUINotActivated);
    expect(error.message, _notActivatedMessage);
    expect(error.detail, _notActivatedDetail);
    expect(view.id, 'flutter_native_30');
    expect(view.placementId, 'placement-id');
    expect(view.variationId, 'variation-id');
    expect(view.locale, isNull);
    expect(observer.errors, hasLength(1));
    expect(calls, isEmpty);
  });

  test('a load error that arrives after the widget listens reaches the widget and the observer once', () async {
    final observer = _Observer();
    final widget = _Observer();
    AdaptyUI().setFlowsEventsObserver(observer);
    register(widget, 'flutter_native_31');

    await sendLoadError('flutter_native_31', 3001, _noLayoutMessage, _noLayoutDetail);

    expect(widget.errors, hasLength(1));
    expect(widget.errors.single.$2.code, AdaptyErrorCode.wrongParam);
    expect(widget.errors.single.$2.message, _noLayoutMessage);
    expect(widget.errors.single.$1.locale, isNull);
    expect(observer.errors, hasLength(1));
    expect(calls, isEmpty);
  });

  test('a load error that arrives after the widget is removed goes only to the observer', () async {
    final observer = _Observer();
    final widget = _Observer();
    final nextWidget = _Observer();
    AdaptyUI().setFlowsEventsObserver(observer);
    register(widget, 'flutter_native_32');
    AdaptyUI().unregisterFlowEventsListener('flutter_native_32');

    await sendLoadError('flutter_native_32', 3001, _noLayoutMessage, _noLayoutDetail);
    register(nextWidget, 'flutter_native_33');

    expect(observer.errors, hasLength(1));
    expect(widget.errors, isEmpty);
    expect(nextWidget.errors, isEmpty);
    expect(dismissCalls(), isEmpty);
  });

  test('without an observer set, a load error of a removed widget is not dismissed', () async {
    final widget = _Observer();
    register(widget, 'flutter_native_34');
    AdaptyUI().unregisterFlowEventsListener('flutter_native_34');

    await sendLoadError('flutter_native_34', 4003, _notActivatedMessage, _notActivatedDetail);

    expect(widget.errors, isEmpty);
    expect(dismissCalls(), isEmpty);
  });

  test('a load error the bridge reports as unknown keeps its code, message and detail', () async {
    final widget = _Observer();
    register(widget, 'flutter_native_35');

    await sendLoadError('flutter_native_35', 0, _unknownMessage, _unknownDetail);

    expect(widget.errors, hasLength(1));
    final (view, error) = widget.errors.single;
    expect(error.code, AdaptyErrorCode.unknown);
    expect(error.message, _unknownMessage);
    expect(error.detail, _unknownDetail);
    expect(view.locale, isNull);
  });

  test('without an observer set, a load error of a listening widget is not dismissed', () async {
    final widget = _Observer();
    register(widget, 'flutter_native_36');

    await sendLoadError('flutter_native_36', 3001, _noLayoutMessage, _noLayoutDetail);

    expect(widget.errors, hasLength(1));
    expect(dismissCalls(), isEmpty);
  });
}

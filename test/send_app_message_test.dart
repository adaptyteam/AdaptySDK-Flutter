import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_flow.dart';
import 'package:adapty_flutter/src/models/adapty_sdk_native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

/// A lowercase version 4 UUID.
final _messageId = matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'));

class _WithToJson {
  Map<String, dynamic> toJson() => {'a': 1};
}

class _PlatformViewObserver extends AdaptyUIFlowsEventsObserver {
  AdaptyUIFlowView? view;

  @override
  void flowViewDidAppear(AdaptyUIFlowView view) {
    this.view = view;
  }

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) {}

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  tearDown(() {
    AdaptySDKNative.debugPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  group('on iOS', () {
    setUp(() {
      AdaptySDKNative.debugPlatformOverride = TargetPlatform.iOS;
      calls = <MethodCall>[];
    });

    test('sendAppMessage and AdaptyUIFlowView.sendAppMessage send the view id, a message id and the payload', () async {
      _mockNative(calls, (call) => {'success': true});

      final view = await AdaptyUI().createFlowView(flow: _flow());
      await AdaptyUI().sendAppMessage(view, {'step': 'welcome'});
      await view.sendAppMessage({'step': 'paywall'});

      expect(calls.map((call) => call.method), ['adapty_ui_send_app_message', 'adapty_ui_send_app_message']);
      expect(calls.map((call) => jsonDecode(call.arguments as String)), [
        {
          'id': 'view-id',
          'message_id': _messageId,
          'payload': {'step': 'welcome'},
        },
        {
          'id': 'view-id',
          'message_id': _messageId,
          'payload': {'step': 'paywall'},
        },
      ]);
    });

    test('each message gets a message id of its own', () async {
      _mockNative(calls, (call) => {'success': true});

      final view = await AdaptyUI().createFlowView(flow: _flow());
      for (var i = 0; i < 50; i++) {
        await view.sendAppMessage({'n': i});
      }
      await AdaptyUI().sendAppMessage(view, {'n': 50});

      final ids = [for (final call in calls) (jsonDecode(call.arguments as String) as Map)['message_id']];
      expect(ids, hasLength(51));
      expect(ids, everyElement(_messageId));
      expect(ids.toSet(), hasLength(51));
    });

    test('the payload reaches the native side unchanged, nested values and nulls included', () async {
      _mockNative(calls, (call) => {'success': true});

      final view = await AdaptyUI().createFlowView(flow: _flow());
      await view.sendAppMessage({
        'n': null,
        'i': 1,
        'd': 2.5,
        'b': false,
        'list': [1, null, 'x'],
        'obj': {
          'k': {'deep': true},
        },
        't': _WithToJson(),
      });

      final arguments = jsonDecode(calls.single.arguments as String) as Map<String, dynamic>;
      final payload = arguments['payload'] as Map<String, dynamic>;
      expect(payload, {
        'n': null,
        'i': 1,
        'd': 2.5,
        'b': false,
        'list': [1, null, 'x'],
        'obj': {
          'k': {'deep': true},
        },
        't': {'a': 1},
      });
      expect(payload.containsKey('n'), isTrue);
    });

    test('an embedded flow view sends its own id', () async {
      _mockNative(calls, (call) => {'success': true});
      final observer = _PlatformViewObserver();
      // Installs the incoming method call handler without going through the native side.
      Adapty().setupAfterHotRestart();
      AdaptyUI().setFlowsEventsObserver(null);
      AdaptyUI().registerFlowEventsListener(observer, 'flutter_native_0');
      addTearDown(() => AdaptyUI().unregisterFlowEventsListener('flutter_native_0'));

      final arguments = jsonEncode({
        'id': 'flow_view_did_appear',
        'view': {'id': 'flutter_native_0', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
      });
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        _channel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall('flow_view_did_appear', arguments)),
        (_) {},
      );

      expect(observer.view?.id, 'flutter_native_0');
      await observer.view!.sendAppMessage({'step': 'welcome'});

      expect(calls.single.method, 'adapty_ui_send_app_message');
      expect(jsonDecode(calls.single.arguments as String), {
        'id': 'flutter_native_0',
        'message_id': _messageId,
        'payload': {'step': 'welcome'},
      });
    });

    test('a view the native side no longer holds fails with wrongParam', () async {
      _mockNative(
        calls,
        (call) => {
          'error': {'adapty_code': 3001, 'message': 'AdaptyUIError.viewNotFound(view-id)'},
        },
      );

      final view = await AdaptyUI().createFlowView(flow: _flow());

      for (final send in [
        () => AdaptyUI().sendAppMessage(view, {'step': 'welcome'}),
        () => view.sendAppMessage({'step': 'welcome'}),
      ]) {
        await expectLater(
          send(),
          throwsA(
            isA<AdaptyError>()
                .having((error) => error.code, 'code', AdaptyErrorCode.wrongParam)
                .having((error) => error.message, 'message', 'AdaptyUIError.viewNotFound(view-id)'),
          ),
        );
      }
    });

    test('a native platformNotSupported reaches the caller', () async {
      const message = 'AdaptyUIError.platformNotSupported (Code: 4001): AdaptyUI is not supported on this platform.';
      _mockNative(
        calls,
        (call) => {
          'error': {'adapty_code': 4001, 'message': message},
        },
      );

      final view = await AdaptyUI().createFlowView(flow: _flow());

      await expectLater(
        view.sendAppMessage({'step': 'welcome'}),
        throwsA(
          isA<AdaptyError>()
              .having((error) => error.code, 'code', AdaptyErrorCode.platformNotSupported)
              .having((error) => error.message, 'message', message),
        ),
      );
    });

    test('a payload that cannot be encoded fails with wrongParam and sends nothing', () async {
      _mockNative(calls, (call) => {'success': true});

      final view = await AdaptyUI().createFlowView(flow: _flow());

      for (final payload in <Map<String, dynamic>>[
        {'x': double.nan},
        {'x': Object()},
      ]) {
        await expectLater(
          AdaptyUI().sendAppMessage(view, payload),
          throwsA(
            isA<AdaptyError>()
                .having((error) => error.code, 'code', AdaptyErrorCode.wrongParam)
                .having((error) => error.message, 'message', 'Failed to encode the app message payload'),
          ),
        );
        await expectLater(
          view.sendAppMessage(payload),
          throwsA(isA<AdaptyError>().having((error) => error.code, 'code', AdaptyErrorCode.wrongParam)),
        );
      }

      expect(calls.map((call) => call.method), isNot(contains('adapty_ui_send_app_message')));
    });

    test('an empty payload is sent like any other', () async {
      _mockNative(calls, (call) => {'success': true});

      final view = await AdaptyUI().createFlowView(flow: _flow());
      await view.sendAppMessage({});

      expect(calls.single.method, 'adapty_ui_send_app_message');
      final arguments = jsonDecode(calls.single.arguments as String) as Map<String, dynamic>;
      expect(arguments, {'id': 'view-id', 'message_id': _messageId, 'payload': <String, dynamic>{}});
      expect(arguments.containsKey('payload'), isTrue);
    });
  });

  group('on Android', () {
    setUp(() {
      AdaptySDKNative.debugPlatformOverride = TargetPlatform.android;
      calls = <MethodCall>[];
    });

    test('both calls send the request with the view id, a message id and the payload, as on iOS', () async {
      _mockNative(calls, (call) => {'success': true});

      final view = await AdaptyUI().createFlowView(flow: _flow());
      await AdaptyUI().sendAppMessage(view, {'step': 'welcome'});
      await view.sendAppMessage({'step': 'paywall'});

      expect(calls.map((call) => call.method), ['adapty_ui_send_app_message', 'adapty_ui_send_app_message']);
      expect(calls.map((call) => jsonDecode(call.arguments as String)), [
        {
          'id': 'view-id',
          'message_id': _messageId,
          'payload': {'step': 'welcome'},
        },
        {
          'id': 'view-id',
          'message_id': _messageId,
          'payload': {'step': 'paywall'},
        },
      ]);
    });

    test('a view the native side does not hold, released or not loaded yet, fails with wrongParam', () async {
      const message = 'AdaptyUIError.viewNotFound(view-id)';
      _mockNative(
        calls,
        (call) => {
          'error': {'adapty_code': 3001, 'message': message},
        },
      );

      final view = await AdaptyUI().createFlowView(flow: _flow());

      for (final send in [
        () => AdaptyUI().sendAppMessage(view, {'step': 'welcome'}),
        () => view.sendAppMessage({'step': 'welcome'}),
      ]) {
        await expectLater(
          send(),
          throwsA(
            isA<AdaptyError>()
                .having((error) => error.code, 'code', AdaptyErrorCode.wrongParam)
                .having((error) => error.message, 'message', message),
          ),
        );
      }
      expect(calls.map((call) => call.method), ['adapty_ui_send_app_message', 'adapty_ui_send_app_message']);
    });
  });
}

/// Answers `adapty_ui_create_flow_view` with a view and records every other call in [calls] before
/// handing it to [reply].
void _mockNative(List<MethodCall> calls, Map<String, dynamic> Function(MethodCall call) reply) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
    if (call.method == 'adapty_ui_create_flow_view') {
      return jsonEncode({
        'success': {'id': 'view-id', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
      });
    }
    calls.add(call);
    return jsonEncode(reply(call));
  });
}

AdaptyFlow _flow() => AdaptyFlowJSONBuilder.fromJsonValue({
  'placement': {
    'developer_id': 'placement-id',
    'audience_name': 'Audience',
    'revision': 1,
    'ab_test_name': 'Experiment',
    'placement_audience_version_id': 'placement-audience-version-id',
  },
  'flow_id': 'flow-id',
  'flow_name': 'Flow',
  'variation_id': 'variation-id',
  'variations': <dynamic>[],
  'response_created_at': 0,
});

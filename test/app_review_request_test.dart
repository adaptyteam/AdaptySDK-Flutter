import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

class _Handler extends AdaptyUISystemRequestsHandler {
  bool started = false;

  @override
  Future<AdaptyUIPermissionResult> handlePermission(
    AdaptyUIFlowView view,
    AdaptyUIPermission permission,
    Map<String, String>? customArgs,
  ) async => const AdaptyUIPermissionResult.denied();

  @override
  Future<void> handleAppReviewRequest(AdaptyUIFlowView view) async {
    started = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => jsonEncode({'success': true}),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('the app review handler starts on the next event-loop turn', () async {
    final handler = _Handler();
    AdaptyUI().setSystemRequestsHandler(handler);

    final delivered = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(
          'flow_view_did_request_app_review',
          jsonEncode({
            'view': {'id': 'view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
          }),
        ),
      ),
      (_) {},
    );

    await Future.microtask(() {});
    expect(handler.started, isFalse);

    await Future(() {});
    expect(handler.started, isTrue);

    await delivered;
  });
}

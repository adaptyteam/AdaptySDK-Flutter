import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_flow.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('destroyFlowView and AdaptyUIFlowView.destroy send only the view id, on every call', () async {
    final calls = <MethodCall>[];
    _mockNative((call) {
      calls.add(call);
      return {'success': true};
    });

    final view = await AdaptyUI().createFlowView(flow: _flow());
    await AdaptyUI().destroyFlowView(view);
    await view.destroy();

    expect(calls.map((call) => call.method), ['adapty_ui_destroy_flow_view', 'adapty_ui_destroy_flow_view']);
    expect(calls.map((call) => jsonDecode(call.arguments as String)), [
      {'id': 'view-id'},
      {'id': 'view-id'},
    ]);
  });

  test('destroying a view the native side no longer holds fails with the native AdaptyError', () async {
    _mockNative(
      (call) => {
        'error': {'adapty_code': 3001, 'message': 'AdaptyUIError.viewNotFound(view-id)'},
      },
    );

    final view = await AdaptyUI().createFlowView(flow: _flow());

    for (final destroy in [() => AdaptyUI().destroyFlowView(view), view.destroy]) {
      await expectLater(
        destroy(),
        throwsA(
          isA<AdaptyError>()
              .having((error) => error.code, 'code', AdaptyErrorCode.wrongParam)
              .having((error) => error.message, 'message', 'AdaptyUIError.viewNotFound(view-id)'),
        ),
      );
    }
  });
}

/// Answers `adapty_ui_create_flow_view` with a view and hands every other call to [reply].
void _mockNative(Map<String, dynamic> Function(MethodCall call) reply) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
    if (call.method == 'adapty_ui_create_flow_view') {
      return jsonEncode({
        'success': {'id': 'view-id', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
      });
    }
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

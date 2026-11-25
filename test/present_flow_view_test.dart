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

  test('present sends the view id and the iOS presentation style, full screen by default', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      if (call.method == 'adapty_ui_create_flow_view') {
        return jsonEncode({
          'success': {'id': 'view-id', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
        });
      }
      return jsonEncode({'success': true});
    });

    final view = await AdaptyUI().createFlowView(flow: _flow());
    calls.clear();

    await view.present();
    await view.present(iosPresentationStyle: AdaptyUIIOSPresentationStyle.pageSheet);
    await AdaptyUI().presentFlowView(view);

    expect(calls.map((call) => call.method), everyElement('adapty_ui_present_flow_view'));
    expect(calls.map((call) => jsonDecode(call.arguments as String)), [
      {'id': 'view-id', 'ios_presentation_style': 'full_screen'},
      {'id': 'view-id', 'ios_presentation_style': 'page_sheet'},
      {'id': 'view-id', 'ios_presentation_style': 'full_screen'},
    ]);
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
  'remote_configs': <dynamic>[],
  'variations': <dynamic>[],
  'response_created_at': 0,
});

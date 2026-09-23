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

  test('dismissFlowView destroys the view unless asked to keep it', () async {
    final requests = <Map<String, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      final request = jsonDecode(call.arguments as String) as Map<String, dynamic>;
      if (call.method == 'adapty_ui_create_flow_view') {
        return jsonEncode({
          'success': {'id': 'view-id', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
        });
      }
      expect(call.method, 'adapty_ui_dismiss_flow_view');
      requests.add(request);
      return jsonEncode({'success': true});
    });

    final view = await AdaptyUI().createFlowView(flow: _flow());

    await AdaptyUI().dismissFlowView(view);
    await AdaptyUI().dismissFlowView(view, destroy: false);
    await view.dismiss();
    await view.dismiss(destroy: false);

    expect(requests.map((request) => request['id']), everyElement('view-id'));
    expect(requests.map((request) => request['destroy']), [true, false, true, false]);
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
  'ui_schema': {
    'layouts': [
      {'flow_layout_id': 'flow-layout-id'},
    ],
    'grids': [
      {'platforms': 'all', 'devices': 'all', 'custom_id': 'configured-grid-id', 'cells': <dynamic>[]},
    ],
  },
  'response_created_at': 0,
});

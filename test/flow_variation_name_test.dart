import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_flow.dart';
import 'package:adapty_flutter/src/platform_views/adaptyui_flow_platform_view.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('a flow keeps its variation name, an empty one included, and sends it back unchanged', () {
    for (final variationName in ['Variant B', '']) {
      final flow = _flow({'variation_name': variationName});

      expect(flow.variationName, variationName);
      expect(flow.jsonValue, containsPair('variation_name', variationName));
    }
  });

  test('a flow without a variation name has none and sends none back, not even a null', () {
    final withoutKey = _flow();
    final withNull = _flow({'variation_name': null});

    for (final flow in [withoutKey, withNull]) {
      expect(flow.variationName, isNull);
      expect(flow.jsonValue, isNot(contains('variation_name')));
    }
  });

  test('a flow from getFlow carries its variation name on every call that hands it back to the native side', () async {
    final requests = <String, dynamic>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      requests[call.method] = jsonDecode(call.arguments as String);
      return jsonEncode({
        'success': switch (call.method) {
          'get_flow' => _flowJson({'variation_name': 'Variant B'}),
          'get_paywall_products' => <dynamic>[],
          'adapty_ui_create_flow_view' => {
            'id': 'view-id',
            'placement_id': 'placement-id',
            'variation_id': 'variation-id',
          },
          _ => true,
        },
      });
    });

    final flow = await Adapty().getFlow(placementId: 'placement-id');
    await Adapty().getPaywallProducts(flow: flow);
    await Adapty().logShowFlow(flow: flow);
    await AdaptyUI().createFlowView(flow: flow);
    final params = buildFlowPlatformViewCreationParams(flow: flow, androidEnableSafeArea: true);

    for (final method in ['get_paywall_products', 'log_show_flow', 'adapty_ui_create_flow_view']) {
      expect(requests[method]?['flow']?['variation_name'], 'Variant B', reason: method);
    }
    expect(params['flow']['variation_name'], 'Variant B', reason: 'buildFlowPlatformViewCreationParams');
  });
}

Map<String, dynamic> _flowJson([Map<String, dynamic> extra = const {}]) => {
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
  ...extra,
};

AdaptyFlow _flow([Map<String, dynamic> extra = const {}]) => AdaptyFlowJSONBuilder.fromJsonValue(_flowJson(extra));

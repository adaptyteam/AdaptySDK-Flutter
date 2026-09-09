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

  test('createFlowView encodes a trimmed custom grid id without changing flow ui_schema', () async {
    Map<String, dynamic>? request;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      expect(call.method, 'adapty_ui_create_flow_view');
      request = jsonDecode(call.arguments as String) as Map<String, dynamic>;
      return jsonEncode({
        'success': {'id': 'view-id', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
      });
    });

    final view = await AdaptyUI().createFlowView(flow: _flow(), customLayoutId: ' unknown custom id ');

    expect(view.id, 'view-id');
    expect(request?['custom_layout_id'], 'unknown custom id');
    expect((request?['flow'] as Map<String, dynamic>)['ui_schema'], {
      'layouts': [
        {'flow_layout_id': 'flow-layout-id'},
      ],
      'grids': [
        {'platforms': 'all', 'devices': 'all', 'custom_id': 'configured-grid-id', 'cells': <dynamic>[]},
      ],
    });
  });

  test('createFlowView omits custom grid id when none is selected', () async {
    Map<String, dynamic>? request;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      expect(call.method, 'adapty_ui_create_flow_view');
      request = jsonDecode(call.arguments as String) as Map<String, dynamic>;
      return jsonEncode({
        'success': {'id': 'view-id', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
      });
    });

    await AdaptyUI().createFlowView(flow: _flow());

    expect(request, isNotNull);
    expect(request, isNot(contains('custom_layout_id')));
  });

  test('embedded creation params trim the custom grid id and forward the safe area flag', () {
    final params = buildFlowPlatformViewCreationParams(
      flow: _flow(),
      customLayoutId: ' unknown custom id ',
      androidEnableSafeArea: false,
    );

    expect(params['custom_layout_id'], 'unknown custom id');
    expect(params['enable_safe_area_paddings'], isFalse);
    expect((params['flow'] as Map<String, dynamic>)['ui_schema'], isNotNull);

    final paramsWithoutCustomLayoutId = buildFlowPlatformViewCreationParams(
      flow: _flow(),
      androidEnableSafeArea: false,
    );

    expect(paramsWithoutCustomLayoutId, isNot(contains('custom_layout_id')));
  });

  test('createFlowView omits a blank custom grid id', () async {
    final requests = <Map<String, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      requests.add(jsonDecode(call.arguments as String) as Map<String, dynamic>);
      return jsonEncode({
        'success': {'id': 'view-id', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
      });
    });

    await AdaptyUI().createFlowView(flow: _flow(), customLayoutId: '');
    await AdaptyUI().createFlowView(flow: _flow(), customLayoutId: '   ');

    expect(requests, hasLength(2));
    for (final request in requests) {
      expect(request, isNot(contains('custom_layout_id')));
    }
  });

  test('embedded creation params omit a blank custom grid id', () {
    for (final blank in ['', '   ']) {
      final params = buildFlowPlatformViewCreationParams(
        flow: _flow(),
        customLayoutId: blank,
        androidEnableSafeArea: false,
      );

      expect(params, isNot(contains('custom_layout_id')));
    }
  });

  test('embedded creation params serialize custom tags', () {
    final params = buildFlowPlatformViewCreationParams(
      flow: _flow(),
      androidEnableSafeArea: false,
      customTags: {'audience': 'paid'},
    );

    expect(params['custom_tags'], {'audience': 'paid'});
  });

  test('embedded creation params serialize custom timers as UTC strings', () {
    final params = buildFlowPlatformViewCreationParams(
      flow: _flow(),
      androidEnableSafeArea: false,
      customTimers: {'sale_ends_at': DateTime.utc(2025, 1, 2, 3, 4, 5)},
    );

    expect(params['custom_timers'], {'sale_ends_at': '2025-01-02T03:04:05.000Z'});
  });

  test('embedded creation params serialize custom assets', () {
    final params = buildFlowPlatformViewCreationParams(
      flow: _flow(),
      androidEnableSafeArea: false,
      customAssets: {'hero_image': const AdaptyCustomAsset.localImageAsset(assetId: 'assets/hero.png')},
    );

    expect(params['custom_assets'], [
      {'id': 'hero_image', 'type': 'image', 'asset_id': 'assets/hero.png'},
    ]);
  });

  test('embedded creation params serialize product purchase parameters', () {
    final params = buildFlowPlatformViewCreationParams(
      flow: _flow(),
      androidEnableSafeArea: false,
      productPurchaseParams: {
        const AdaptyProductIdentifier(vendorProductId: 'premium_monthly', adaptyProductId: 'adapty-premium-monthly'):
            AdaptyPurchaseParameters(isOfferPersonalized: true),
      },
    );

    expect(params['product_purchase_parameters'], {
      'adapty-premium-monthly': {'is_offer_personalized': true},
    });
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

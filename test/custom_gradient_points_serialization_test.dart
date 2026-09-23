import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_flow.dart';
import 'package:adapty_flutter/src/platform_views/adaptyui_flow_platform_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdaptyCustomAsset linear gradient point serialization', () {
    test('default centerLeft -> centerRight maps to element fractions', () {
      final asset = AdaptyCustomAsset.linearGradient(
        gradient: const LinearGradient(
          colors: [Color(0xFF0000FF), Color(0x80010203)],
        ),
      );

      expect(asset.jsonValue['points'], {
        'x0': closeTo(0.0, 1e-9),
        'y0': closeTo(0.5, 1e-9),
        'x1': closeTo(1.0, 1e-9),
        'y1': closeTo(0.5, 1e-9),
      });
    });

    test('topCenter -> bottomCenter maps to element fractions', () {
      final asset = AdaptyCustomAsset.linearGradient(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0000FF), Color(0x80010203)],
        ),
      );

      expect(asset.jsonValue['points'], {
        'x0': closeTo(0.5, 1e-9),
        'y0': closeTo(0.0, 1e-9),
        'x1': closeTo(0.5, 1e-9),
        'y1': closeTo(1.0, 1e-9),
      });
    });

    test('topLeft -> bottomRight maps to element fractions', () {
      final asset = AdaptyCustomAsset.linearGradient(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0000FF), Color(0x80010203)],
        ),
      );

      expect(asset.jsonValue['points'], {
        'x0': closeTo(0.0, 1e-9),
        'y0': closeTo(0.0, 1e-9),
        'x1': closeTo(1.0, 1e-9),
        'y1': closeTo(1.0, 1e-9),
      });
    });

    test('arbitrary alignments map to element fractions', () {
      final asset = AdaptyCustomAsset.linearGradient(
        gradient: const LinearGradient(
          begin: Alignment(0.5, -0.5),
          end: Alignment.center,
          colors: [Color(0xFF0000FF), Color(0x80010203)],
        ),
      );

      expect(asset.jsonValue['points'], {
        'x0': closeTo(0.75, 1e-9),
        'y0': closeTo(0.25, 1e-9),
        'x1': closeTo(0.5, 1e-9),
        'y1': closeTo(0.5, 1e-9),
      });
    });

    test('embedded platform-view creation params carry element-fraction points', () {
      final params = buildFlowPlatformViewCreationParams(
        flow: _flow(),
        androidEnableSafeArea: false,
        customAssets: {
          'bg': AdaptyCustomAsset.linearGradient(
            gradient: const LinearGradient(
              colors: [Color(0xFF0000FF), Color(0x80010203)],
            ),
          ),
        },
      );

      final customAssets = params['custom_assets'] as List<dynamic>;
      final bg = customAssets.cast<Map<String, dynamic>>().singleWhere((entry) => entry['id'] == 'bg');

      expect(bg['points'], {
        'x0': closeTo(0.0, 1e-9),
        'y0': closeTo(0.5, 1e-9),
        'x1': closeTo(1.0, 1e-9),
        'y1': closeTo(0.5, 1e-9),
      });
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
    'grids': <dynamic>[],
  },
  'response_created_at': 0,
});

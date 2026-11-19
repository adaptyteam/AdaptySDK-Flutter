/// What a flow fetch puts on the wire when the caller still passes a locale: neither native side reads a locale for
/// a flow, so the request carries only what the native side uses.
// The locale is deprecated; passing it is exactly what these tests do.
// ignore_for_file: deprecated_member_use_from_same_package
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

Map<String, dynamic> _flowJson() => {
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
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return jsonEncode({'success': _flowJson()});
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('getFlow with a locale sends only the placement id', () async {
    await Adapty().getFlow(placementId: 'placement-id', locale: 'en');

    expect(calls.single.method, 'get_flow');
    expect(jsonDecode(calls.single.arguments as String), {'placement_id': 'placement-id'});
  });

  test('getFlowForDefaultAudience with a locale sends only the placement id', () async {
    await Adapty().getFlowForDefaultAudience(placementId: 'placement-id', locale: 'en');

    expect(calls.single.method, 'get_flow_for_default_audience');
    expect(jsonDecode(calls.single.arguments as String), {'placement_id': 'placement-id'});
  });
}

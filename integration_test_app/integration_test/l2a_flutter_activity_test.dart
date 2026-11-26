import 'dart:convert';

import 'package:adapty_flutter/src/adaptyui_events_proxy.dart' show adaptyEmbeddedViewIdPrefix;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/l2a_cases.g.dart';
import 'support/l2a_probe.dart';

/// Runs on Android in an app whose activity is a plain FlutterActivity (the Gradle property l2aActivity is
/// `flutter`), which owns no view models. The plugin registers its flow view there too: creating one succeeds, and
/// the view stays empty and reports, as its only event, that it needs an activity that extends
/// FlutterFragmentActivity. The onboarding view is not registered, so creating one fails as a view of an
/// unregistered type. The plugin keeps answering on its channel.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final viewTypes = {for (final view in l2aViews['android']!) view.viewType: view.params};
  final events = <MethodCall>[];

  setUpAll(() {
    l2aChannel.setMethodCallHandler((call) async {
      events.add(call);
      return null;
    });
  });

  testWidgets('the plugin answers on its channel in a plain FlutterActivity', l2aReadinessBarrier);

  for (final MapEntry(key: viewType, value: params) in viewTypes.entries) {
    final id = 1000 + viewTypes.keys.toList().indexOf(viewType);
    AndroidViewController viewController() => PlatformViewsService.initAndroidView(
      id: id,
      viewType: viewType,
      layoutDirection: TextDirection.ltr,
      creationParams: params,
      creationParamsCodec: const StandardMessageCodec(),
    );

    if (viewType == 'adaptyui_flow_platform_view') {
      testWidgets('creating $viewType succeeds and the view reports, once, that it needs another activity', (
        tester,
      ) async {
        await l2aReadinessBarrier(tester);
        events.clear();
        final controller = viewController();
        try {
          await controller.create(size: const Size(300, 500));
          for (var i = 0; i < 50 && events.isEmpty; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          // A second event of the view would arrive in this window.
          await tester.pump(const Duration(seconds: 2));
        } finally {
          await controller.dispose();
        }
        await tester.pump(const Duration(seconds: 1));

        final received = [for (final e in events) '${e.method} ${e.arguments}'];
        expect(events.map((e) => e.method), ['flow_view_did_receive_error'], reason: '$received');
        final event = jsonDecode(events.single.arguments as String) as Map<String, Object?>;
        final flow = (jsonDecode(params) as Map<String, Object?>)['flow']! as Map<String, Object?>;
        expect(event['view'], {
          'id': '$adaptyEmbeddedViewIdPrefix$id',
          'placement_id': (flow['placement']! as Map<String, Object?>)['developer_id'],
          'variation_id': flow['variation_id'],
        });
        expect(event['error'], {
          'adapty_code': 4001,
          'message': 'AdaptyUIFlowPlatformView needs an activity that extends FlutterFragmentActivity',
          'detail': 'activity: com.adapty.flutter.adapty_l2a.MainActivity',
        });
        expect((await l2aCall('is_activated', '{}')).kind, 'success', reason: 'the plugin stopped answering');
      });
    } else {
      testWidgets('creating $viewType fails as a view of an unregistered type', (tester) async {
        await l2aReadinessBarrier(tester);
        final controller = viewController();
        try {
          await expectLater(
            controller.create(size: const Size(300, 500)),
            throwsA(isA<PlatformException>().having((e) => e.message, 'message', contains('unregistered type'))),
          );
        } finally {
          await controller.dispose();
        }

        expect((await l2aCall('is_activated', '{}')).kind, 'success', reason: 'the plugin stopped answering');
      });
    }
  }
}

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:adapty_flutter/src/adaptyui_events_proxy.dart' show adaptyEmbeddedViewIdPrefix;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/l2a_cases.g.dart';
import 'support/l2a_probe.dart';

/// Creates each embedded view of the corpus before activation, one test per view, and checks that the native
/// side takes its creation params. iOS reports a flow view it cannot build as an event; before activation a
/// flow view whose params decode fails as AdaptyUI not activated (4003). On Android a flow view whose params
/// parse asks for its configuration, which fails before activation as the SDK not activated (20), and reports
/// that once as an event of the view, with the id, placement and variation of the view, and never again after the
/// view is removed; an onboarding view reports nothing there.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final events = <MethodCall>[];

  setUpAll(() async {
    l2aChannel.setMethodCallHandler((call) async {
      events.add(call);
      return null;
    });
    // On Android the SDK says in its log, and only there, whether it parsed the creation params of a view; it logs
    // nothing at its default level.
    if (!Platform.isIOS) {
      final observed = await l2aCall('set_log_level', '{"value":"verbose"}');
      expect(observed.kind, 'success', reason: 'set_log_level: ${observed.toJson()}');
    }
  });

  test('the bundle has embedded views to create', () {
    expect(l2aViews[l2aPlatform], isNotEmpty);
  });

  for (final view in l2aViews[l2aPlatform]!) {
    testWidgets('the native side creates ${view.id} before activation', (tester) async {
      events.clear();
      int? createdId;
      final params = view.params;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 500,
              child: Platform.isIOS
                  ? UiKitView(
                      viewType: view.viewType,
                      creationParams: params,
                      creationParamsCodec: const StandardMessageCodec(),
                      onPlatformViewCreated: (id) => createdId = id,
                    )
                  : AndroidView(
                      viewType: view.viewType,
                      creationParams: params,
                      creationParamsCodec: const StandardMessageCodec(),
                      onPlatformViewCreated: (id) => createdId = id,
                    ),
            ),
          ),
        ),
      );
      final isFlow = view.viewType == 'adaptyui_flow_platform_view';
      final isIosFlow = Platform.isIOS && isFlow;
      for (var i = 0; i < 30 && !(isFlow && events.isNotEmpty); i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final created = createdId;
      final received = [...events];
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));

      print(
        'L2A_VIEW ${jsonEncode({
          'id': view.id,
          'platform': l2aPlatform,
          'created': created,
          'events': [
            for (final e in received) {'event': e.method, 'args': '${e.arguments}'},
          ],
        })}',
      );
      expect(tester.takeException(), isNull);
      expect(created, isNotNull, reason: '${view.id}: the platform view was not created');
      if (isIosFlow) {
        final errors = [
          for (final e in received)
            if (e.method == 'flow_view_did_receive_error') jsonDecode(e.arguments as String) as Map<String, Object?>,
        ];
        final codes = [for (final e in errors) (e['error']! as Map<String, Object?>)['adapty_code']];
        expect(codes, [4003], reason: '${view.id}: the flow view reports ${jsonEncode(errors)}');
        final ids = [for (final e in errors) (e['view']! as Map<String, Object?>)['id']];
        expect(ids, ['$adaptyEmbeddedViewIdPrefix$created'], reason: '${view.id}: the events of the view carry its id');
      }
      if (!Platform.isIOS) {
        // Every event from the creation of the view to the end of the window after its removal.
        final all = [...events];
        final listed = [for (final e in all) '${e.method} ${e.arguments}'];
        if (isFlow) {
          expect(all.map((e) => e.method), [
            'flow_view_did_receive_error',
          ], reason: '${view.id}: the flow view reports one error and nothing after it: $listed');
          final error = jsonDecode(all.single.arguments as String) as Map<String, Object?>;
          expect(
            (error['error']! as Map<String, Object?>)['adapty_code'],
            20,
            reason: '${view.id}: the flow view reports ${jsonEncode(error)}',
          );
          final flow = (jsonDecode(params) as Map<String, Object?>)['flow']! as Map<String, Object?>;
          expect(error['view'], {
            'id': '$adaptyEmbeddedViewIdPrefix$created',
            'placement_id': (flow['placement']! as Map<String, Object?>)['developer_id'],
            'variation_id': flow['variation_id'],
          }, reason: '${view.id}: the event of the view carries its id, placement and variation');
        } else {
          expect(all, isEmpty, reason: '${view.id}: the onboarding view reports nothing: $listed');
        }
      }
    });
  }
}

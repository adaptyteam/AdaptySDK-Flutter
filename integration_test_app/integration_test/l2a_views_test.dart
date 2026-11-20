import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/l2a_cases.g.dart';
import 'support/l2a_probe.dart';

/// Creates each embedded view of the corpus before activation, one test per view, and checks that the native
/// side takes its creation params. iOS reports a flow view it cannot build as an event; before activation a
/// flow view whose params decode fails as AdaptyUI not activated (4003). Android does not read the params
/// before activation, so there only the creation is checked.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final events = <MethodCall>[];

  setUpAll(() {
    l2aChannel.setMethodCallHandler((call) async {
      events.add(call);
      return null;
    });
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
      final isIosFlow = Platform.isIOS && view.viewType == 'adaptyui_flow_platform_view';
      for (var i = 0; i < 30 && !(isIosFlow && events.isNotEmpty); i++) {
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
      }
    });
  }
}

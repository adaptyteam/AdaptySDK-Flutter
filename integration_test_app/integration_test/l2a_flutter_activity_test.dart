import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/l2a_cases.g.dart';
import 'support/l2a_probe.dart';

/// Runs on Android in an app whose activity is a plain FlutterActivity (the Gradle property l2aActivity is
/// `flutter`), which owns no view models: the plugin attaches to it without registering its embedded views, so
/// creating one fails as a view of an unregistered type, and the plugin keeps answering on its channel.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final viewTypes = {for (final view in l2aViews['android']!) view.viewType: view.params};

  testWidgets('the plugin answers on its channel in a plain FlutterActivity', l2aReadinessBarrier);

  for (final MapEntry(key: viewType, value: params) in viewTypes.entries) {
    testWidgets('creating $viewType fails as a view of an unregistered type', (tester) async {
      await l2aReadinessBarrier(tester);
      final controller = PlatformViewsService.initAndroidView(
        id: 1000 + viewTypes.keys.toList().indexOf(viewType),
        viewType: viewType,
        layoutDirection: TextDirection.ltr,
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
      );
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

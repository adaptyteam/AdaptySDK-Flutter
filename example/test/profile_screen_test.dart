import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adapty_recipes/app/app_controller.dart';
import 'package:adapty_recipes/app/user_manager.dart';
import 'package:adapty_recipes/ui/adaptive.dart';
import 'package:adapty_recipes/ui/profile_screen.dart';

void main() {
  late AppController controller;

  setUp(() {
    controller = AppController(userManager: UserManager())..isInitialized = true;
  });

  tearDown(() {
    controller.dispose();
  });

  testWidgets('terminal profile failure shows Unavailable without a spinner', (tester) async {
    controller.errorMessage = 'Profile: offline';

    await _pumpProfileScreen(tester, controller);

    final premiumRow = find.byWidgetPredicate(
      (widget) => widget is InfoRow && widget.title == 'Premium' && widget.subtitle == 'Unavailable',
    );
    expect(premiumRow, findsOneWidget);
    expect(find.descendant(of: premiumRow, matching: find.byType(CircularProgressIndicator)), findsNothing);
  });

  testWidgets('identity update without a profile shows Loading with a spinner', (tester) async {
    controller.isUpdatingIdentity = true;

    await _pumpProfileScreen(tester, controller);

    final premiumRow = find.byWidgetPredicate(
      (widget) => widget is InfoRow && widget.title == 'Premium' && widget.subtitle == 'Loading',
    );
    expect(premiumRow, findsOneWidget);
    expect(find.descendant(of: premiumRow, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
  });

  testWidgets('purchase restore without a profile shows Loading with a spinner', (tester) async {
    controller.isRestoringPurchases = true;

    await _pumpProfileScreen(tester, controller);

    final premiumRow = find.byWidgetPredicate(
      (widget) => widget is InfoRow && widget.title == 'Premium' && widget.subtitle == 'Loading',
    );
    expect(premiumRow, findsOneWidget);
    expect(find.descendant(of: premiumRow, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
  });
}

Future<void> _pumpProfileScreen(WidgetTester tester, AppController controller) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ProfileScreen(controller: controller)),
    ),
  );
}

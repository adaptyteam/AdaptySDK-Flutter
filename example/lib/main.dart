import 'package:adapty_flutter_example/purchase_observer.dart';
import 'package:flutter/cupertino.dart';

import 'screens/main_screen.dart';
import 'screens/onboardings_view.dart';
import 'screens/paywalls_view.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    PurchasesObserver().initialize();

    super.initState();
  }

  Future<void> _showErrorDialog(BuildContext context, String title, String message, String? details) {
    return showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Column(
          children: [
            Text(message),
            if (details != null) Text(details),
          ],
        ),
        actions: [
          CupertinoButton(
              child: const Text('OK'),
              onPressed: () {
                // close dialog
                Navigator.pop(ctx);
                // Navigator.of(context).pop();
              }),
        ],
      ),
    );
  }

  Widget build(BuildContext context) {
    return CupertinoApp(
        theme: CupertinoThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
        ),
        home: CupertinoTabScaffold(
          tabBar: CupertinoTabBar(
            items: [
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.home),
                label: 'General',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.money_dollar_circle_fill),
                label: 'Paywalls',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.doc_on_clipboard),
                label: 'Onboardings',
              ),
            ],
          ),
          tabBuilder: (context, index) {
            switch (index) {
              case 0:
                return CupertinoTabView(
                  builder: (context) {
                    return CupertinoPageScaffold(
                      child: MainScreen(adaptyErrorCallback: (e) => _showErrorDialog(context, 'Error code ${e.code}!', e.message, e.detail), customErrorCallback: (e) => _showErrorDialog(context, 'Unknown error!', e.toString(), null)),
                    );
                  },
                );
              case 1:
                return CupertinoTabView(
                  builder: (context) {
                    return CupertinoPageScaffold(
                      child: PaywallsView(
                        adaptyErrorCallback: (e) => _showErrorDialog(context, 'Error code ${e.code}!', e.message, e.detail),
                        customErrorCallback: (e) => _showErrorDialog(context, 'Unknown error!', e.toString(), null),
                      ),
                    );
                  },
                );
              case 2:
                return CupertinoTabView(
                  builder: (context) {
                    return CupertinoPageScaffold(
                      child: OnboardingsView(
                        adaptyErrorCallback: (e) => _showErrorDialog(context, 'Error code ${e.code}!', e.message, e.detail),
                        customErrorCallback: (e) => _showErrorDialog(context, 'Unknown error!', e.toString(), null),
                      ),
                    );
                  },
                );
              default:
                return const SizedBox.shrink();
            }
          },
        ));
  }
}

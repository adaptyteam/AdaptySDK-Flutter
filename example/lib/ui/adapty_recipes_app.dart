import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app/app_constants.dart';
import '../app/app_controller.dart';
import 'adaptive.dart';
import 'configuration_screen.dart';
import 'profile_screen.dart';
import 'recipes_screen.dart';

class AdaptyRecipesApp extends StatefulWidget {
  const AdaptyRecipesApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<AdaptyRecipesApp> createState() => _AdaptyRecipesAppState();
}

class _AdaptyRecipesAppState extends State<AdaptyRecipesApp> {
  @override
  void initState() {
    super.initState();
    widget.controller.initialize();
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (usesCupertino) {
      return CupertinoApp(
        title: 'Adapty Recipes',
        theme: const CupertinoThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
        ),
        home: AppConstants.hasValidConfiguration
            ? _CupertinoRoot(controller: widget.controller)
            : const ConfigurationScreen(),
      );
    }

    return MaterialApp(
      title: 'Adapty Recipes',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: AppConstants.hasValidConfiguration
          ? _MaterialRoot(controller: widget.controller)
          : const ConfigurationScreen(),
    );
  }
}

class _CupertinoRoot extends StatelessWidget {
  const _CupertinoRoot({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.list_bullet), label: 'Recipes'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.person), label: 'Profile'),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) {
            switch (index) {
              case 0:
                return CupertinoPageScaffold(
                  navigationBar: const CupertinoNavigationBar(middle: Text('Adapty Recipes')),
                  child: SafeArea(child: RecipesScreen(controller: controller)),
                );
              case 1:
                return CupertinoPageScaffold(
                  navigationBar: const CupertinoNavigationBar(middle: Text('Profile')),
                  child: SafeArea(child: ProfileScreen(controller: controller)),
                );
              default:
                return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }
}

class _MaterialRoot extends StatefulWidget {
  const _MaterialRoot({required this.controller});

  final AppController controller;

  @override
  State<_MaterialRoot> createState() => _MaterialRootState();
}

class _MaterialRootState extends State<_MaterialRoot> {
  var _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final title = _selectedIndex == 0 ? 'Adapty Recipes' : 'Profile';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            RecipesScreen(controller: widget.controller),
            ProfileScreen(controller: widget.controller),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Recipes'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

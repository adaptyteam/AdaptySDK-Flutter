import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app/app_constants.dart';
import 'adaptive.dart';

class ConfigurationScreen extends StatelessWidget {
  const ConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Adapty Recipes',
                textAlign: TextAlign.center,
                style: usesCupertino
                    ? CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle
                    : Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                AppConstants.configurationErrorMessage,
                textAlign: TextAlign.center,
                style: usesCupertino
                    ? CupertinoTheme.of(context).textTheme.textStyle
                    : Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );

    if (usesCupertino) {
      return CupertinoPageScaffold(child: SafeArea(child: content));
    }

    return Scaffold(body: SafeArea(child: content));
  }
}

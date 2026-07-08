import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../models/recipe_category.dart';
import 'adaptive.dart';
import 'embedded_flow_screen.dart';

class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (controller.errorMessage != null)
              AppErrorBanner(message: controller.errorMessage!, onDismiss: controller.clearError),
            if (controller.isInitializing)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(child: adaptiveActivityIndicator()),
              )
            else ...[
              const SectionHeader('Basic Recipes'),
              GroupedSection(
                children: [
                  for (final category in RecipeCategory.basic)
                    RecipeCategoryRow(
                      category: category,
                      locked: false,
                      onTap: () => _openRecipeDetails(context, category),
                    ),
                ],
              ),
              const SectionHeader('Premium Recipes'),
              GroupedSection(
                children: [
                  for (final category in RecipeCategory.premium)
                    RecipeCategoryRow(
                      category: category,
                      locked: !controller.isPremiumUser,
                      onTap: () => _openPremiumCategory(context, category),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _openPremiumCategory(BuildContext context, RecipeCategory category) async {
    if (controller.isPremiumUser) {
      _openRecipeDetails(context, category);
      return;
    }

    switch (category.presentationStyle) {
      case RecipePresentationStyle.modal:
        await controller.presentFlowModally();
        break;
      case RecipePresentationStyle.navigation:
        if (!context.mounted) {
          return;
        }

        await Navigator.of(context).push(
          adaptivePageRoute(
            builder: (_) => EmbeddedFlowScreen(title: category.title, controller: controller),
          ),
        );
        break;
    }
  }

  void _openRecipeDetails(BuildContext context, RecipeCategory category) {
    Navigator.of(context).push(adaptivePageRoute(builder: (_) => RecipeDetailsScreen(category: category)));
  }
}

class RecipeCategoryRow extends StatelessWidget {
  const RecipeCategoryRow({super.key, required this.category, required this.locked, required this.onTap});

  final RecipeCategory category;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final presentationLabel = category.presentationStyle.name;

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(category.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category.title,
              style: usesCupertino
                  ? CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontWeight: FontWeight.w600)
                  : Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (locked) ...[
            Icon(
              usesCupertino ? CupertinoIcons.lock_fill : Icons.lock,
              size: 16,
              color: usesCupertino
                  ? CupertinoColors.secondaryLabel.resolveFrom(context)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            '($presentationLabel)',
            style: TextStyle(
              color: usesCupertino
                  ? CupertinoColors.secondaryLabel.resolveFrom(context)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          if (usesCupertino)
            Icon(CupertinoIcons.chevron_forward, size: 18, color: CupertinoColors.tertiaryLabel.resolveFrom(context))
          else
            Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ],
      ),
    );

    if (usesCupertino) {
      return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row);
    }

    return InkWell(onTap: onTap, child: row);
  }
}

class RecipeDetailsScreen extends StatelessWidget {
  const RecipeDetailsScreen({super.key, required this.category});

  final RecipeCategory category;

  @override
  Widget build(BuildContext context) {
    final content = ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        GroupedSection(
          children: [
            InfoRow(title: 'Recipe 1 for ${category.title}'),
            InfoRow(title: 'Recipe 2 for ${category.title}'),
          ],
        ),
      ],
    );

    if (usesCupertino) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text(category.title)),
        child: SafeArea(child: content),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(category.title)),
      body: SafeArea(child: content),
    );
  }
}

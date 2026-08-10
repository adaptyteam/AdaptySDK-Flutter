enum RecipePresentationStyle { modal, navigation }

enum RecipeCategory {
  simpleSalads(
    title: 'Simple Salads',
    emoji: '🥗',
    isPremium: false,
    presentationStyle: RecipePresentationStyle.navigation,
  ),
  pastaDishes(
    title: 'Pasta Dishes',
    emoji: '🍝',
    isPremium: false,
    presentationStyle: RecipePresentationStyle.navigation,
  ),
  soups(title: 'Soups', emoji: '🍲', isPremium: false, presentationStyle: RecipePresentationStyle.navigation),
  breakfasts(title: 'Breakfasts', emoji: '🍳', isPremium: false, presentationStyle: RecipePresentationStyle.navigation),
  snacks(title: 'Snacks', emoji: '🍌', isPremium: false, presentationStyle: RecipePresentationStyle.navigation),
  wrapsAndSandwiches(
    title: 'Wraps and Sandwiches',
    emoji: '🥙',
    isPremium: false,
    presentationStyle: RecipePresentationStyle.navigation,
  ),
  gourmetDishes(
    title: 'Gourmet Dishes',
    emoji: '🍣',
    isPremium: true,
    presentationStyle: RecipePresentationStyle.modal,
  ),
  desserts(title: 'Desserts', emoji: '🍰', isPremium: true, presentationStyle: RecipePresentationStyle.navigation),
  internationalCuisine(
    title: 'International Cuisine',
    emoji: '🍛',
    isPremium: true,
    presentationStyle: RecipePresentationStyle.modal,
  ),
  seafoodSpecials(
    title: 'Seafood Specials',
    emoji: '🍤',
    isPremium: true,
    presentationStyle: RecipePresentationStyle.navigation,
  ),
  pairings(title: 'Pairings', emoji: '🍷', isPremium: true, presentationStyle: RecipePresentationStyle.modal),
  superfoodRecipes(
    title: 'Superfood Recipes',
    emoji: '🥑',
    isPremium: true,
    presentationStyle: RecipePresentationStyle.navigation,
  );

  const RecipeCategory({
    required this.title,
    required this.emoji,
    required this.isPremium,
    required this.presentationStyle,
  });

  final String title;
  final String emoji;
  final bool isPremium;
  final RecipePresentationStyle presentationStyle;

  static List<RecipeCategory> get basic => values.where((category) => !category.isPremium).toList(growable: false);

  static List<RecipeCategory> get premium => values.where((category) => category.isPremium).toList(growable: false);
}

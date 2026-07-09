abstract final class AppConstants {
  static const accessLevelId = 'premium';

  static const adaptyApiKey = 'YOUR_API_KEY';
  static const placementId = 'YOUR_PLACEMENT_ID';

  static bool get hasValidConfiguration => isConfiguredValue(adaptyApiKey) && isConfiguredValue(placementId);

  static const configurationErrorMessage =
      'Replace YOUR_API_KEY and YOUR_PLACEMENT_ID in lib/app/app_constants.dart before running the demo.';

  static bool debugAssertValidConfiguration() {
    assert(hasValidConfiguration, 'AdaptyRecipes-Flutter configuration error: $configurationErrorMessage');

    return hasValidConfiguration;
  }

  static bool isConfiguredValue(String value) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty && !trimmed.startsWith('YOUR_');
  }
}

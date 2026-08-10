abstract final class AppConstants {
  static const accessLevelId = 'premium';
  static const _apiKeyPrefix = 'public_live_';
  static const _minimumApiKeyLength = 41;

  static const adaptyApiKey = 'YOUR_API_KEY';
  static const placementId = 'YOUR_PLACEMENT_ID';

  static bool get hasValidConfiguration => isValidAdaptyApiKey(adaptyApiKey) && isValidPlacementId(placementId);

  static const configurationErrorMessage =
      'Set a complete public_live_ API key and placement ID in lib/app/app_constants.dart before running the demo.';

  static bool debugAssertValidConfiguration() {
    assert(hasValidConfiguration, 'Adapty Recipes configuration error: $configurationErrorMessage');

    return hasValidConfiguration;
  }

  static bool isValidAdaptyApiKey(String value) {
    final trimmed = value.trim();
    return _isConfiguredValue(trimmed) && trimmed.startsWith(_apiKeyPrefix) && trimmed.length >= _minimumApiKeyLength;
  }

  static bool isValidPlacementId(String value) => _isConfiguredValue(value.trim());

  static bool _isConfiguredValue(String value) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty && !trimmed.startsWith('YOUR_');
  }
}

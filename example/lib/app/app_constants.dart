abstract final class AppConstants {
  static const accessLevelId = 'premium';
  static const _apiKeyPrefix = 'public_live_';
  static const _minimumApiKeyLength = 41;

  static const adaptyApiKey = 'YOUR_API_KEY';
  static const placementId = 'YOUR_PLACEMENT_ID';

  /// The initial localization for flow views, e.g. `en`, `es`, `fr`; it can be
  /// changed at runtime on the profile screen.
  ///
  /// Starting with Adapty SDK 4.0.0 a flow is localized when its view is built,
  /// so the value goes to `AdaptyUI.createFlowView` / `AdaptyUIFlowPlatformView`
  /// rather than to `getFlow`. `null` renders the flow in `en`, falling back to
  /// the flow's default localization. The view reports the localization it was
  /// actually built with in `AdaptyUIFlowView.locale`.
  static const String? flowLocale = null;

  /// Sample conversion data sent by the "Send External Attribution" row.
  /// A real app passes what its attribution SDK reports.
  static const demoAttribution = <String, dynamic>{'network': 'adapty_recipes', 'campaign': 'demo'};

  static bool get hasValidConfiguration => isValidAdaptyApiKey(adaptyApiKey) && isValidPlacementId(placementId);

  static const configurationErrorMessage =
      'Set a complete public_live_ API key and placement ID in lib/app/app_constants.dart before running the demo.';

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

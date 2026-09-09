import 'package:flutter_test/flutter_test.dart';

import '../lib/app/app_constants.dart';

void main() {
  group('AppConstants configuration validation', () {
    test('rejects blank and placeholder API keys', () {
      expect(AppConstants.isValidAdaptyApiKey(''), isFalse);
      expect(AppConstants.isValidAdaptyApiKey('   '), isFalse);
      expect(AppConstants.isValidAdaptyApiKey('YOUR_API_KEY'), isFalse);
    });

    test('rejects wrong-prefix and truncated API keys', () {
      expect(AppConstants.isValidAdaptyApiKey('secret_live_${'a' * 40}'), isFalse);
      expect(AppConstants.isValidAdaptyApiKey('public_live_short'), isFalse);
    });

    test('accepts a configured live API key at the native minimum length', () {
      final key = 'public_live_${'a' * 29}';

      expect(key.length, 41);
      expect(AppConstants.isValidAdaptyApiKey(key), isTrue);
      expect(AppConstants.isValidAdaptyApiKey('  $key  '), isTrue);
    });

    test('validates placement independently from API key format', () {
      expect(AppConstants.isValidPlacementId('YOUR_PLACEMENT_ID'), isFalse);
      expect(AppConstants.isValidPlacementId('  '), isFalse);
      expect(AppConstants.isValidPlacementId('recipes-placement'), isTrue);
    });
  });
}

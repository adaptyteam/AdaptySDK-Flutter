import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_configuration.dart';
import 'package:adapty_flutter/src/models/adapty_profile.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdaptyExternalAttributionProvider', () {
    test('normalizes known and future provider identifiers', () {
      final knownProviders = <AdaptyExternalAttributionProvider, String>{
        AdaptyExternalAttributionProvider.appleAds: 'apple_search_ads',
        AdaptyExternalAttributionProvider.adjust: 'adjust',
        AdaptyExternalAttributionProvider.appsflyer: 'appsflyer',
        AdaptyExternalAttributionProvider.branch: 'branch',
        AdaptyExternalAttributionProvider.tenjin: 'tenjin',
        AdaptyExternalAttributionProvider.custom: 'custom',
      };

      for (final MapEntry(key: provider, value: rawValue) in knownProviders.entries) {
        expect(provider.rawValue, rawValue);
      }

      final futureProvider = AdaptyExternalAttributionProvider('  future_provider  ');
      expect(futureProvider.rawValue, 'future_provider');
      expect(futureProvider, AdaptyExternalAttributionProvider('future_provider'));
      expect(futureProvider.hashCode, AdaptyExternalAttributionProvider('future_provider').hashCode);
      expect(futureProvider.toString(), 'future_provider');
    });
  });

  test('configuration serializes the renamed attribution flag', () {
    final configuration = AdaptyConfiguration(apiKey: 'test-api-key')..withAdaptyAttributionEnabled(true);

    final json = configuration.jsonValue as Map<String, dynamic>;
    expect(json['adapty_attribution_enabled'], isTrue);
    expect(json, isNot(contains('user_acquisition_enabled')));
  });

  group('AdaptyProfile external attribution providers', () {
    const requiredProfileFields = <String, dynamic>{
      'profile_id': 'profile-1',
      'segment_hash': 'segment-1',
      'timestamp': 1,
      'is_test_user': false,
    };

    test('decodes the stable wire key into the renamed property', () {
      final profile = AdaptyProfileJSONBuilder.fromJsonValue(<String, dynamic>{
        ...requiredProfileFields,
        'applied_attribution_sources': <String>['adjust', '  future_provider  '],
      });

      expect(profile.appliedExternalAttributionProviders, <AdaptyExternalAttributionProvider>[
        AdaptyExternalAttributionProvider.adjust,
        AdaptyExternalAttributionProvider('future_provider'),
      ]);
    });

    test('defaults the renamed property to an empty list', () {
      final profile = AdaptyProfileJSONBuilder.fromJsonValue(requiredProfileFields);

      expect(profile.appliedExternalAttributionProviders, isEmpty);
    });
  });

  group('Adapty.updateExternalAttribution', () {
    const channel = MethodChannel('flutter.adapty.com/adapty');
    late List<MethodCall> calls;

    setUp(() {
      calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return jsonEncode(<String, dynamic>{'success': true});
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    test('uses the renamed method and provider argument', () async {
      await Adapty().updateExternalAttribution(<String, dynamic>{
        'campaign': 'summer',
      }, provider: AdaptyExternalAttributionProvider.custom);

      expect(calls, hasLength(1));
      expect(calls.single.method, 'update_external_attribution_data');

      final arguments = jsonDecode(calls.single.arguments as String) as Map<String, dynamic>;
      expect(arguments['provider'], 'custom');
      expect(arguments, isNot(contains('source')));
      expect(jsonDecode(arguments['attribution'] as String), <String, dynamic>{'campaign': 'summer'});
    });

    test('preserves native Adapty errors', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        return jsonEncode(<String, dynamic>{
          'error': <String, dynamic>{
            'adapty_code': AdaptyErrorCode.badRequest,
            'message': 'bad request',
            'detail': 'native',
          },
        });
      });

      await expectLater(
        Adapty().updateExternalAttribution(
          const <String, dynamic>{},
          provider: AdaptyExternalAttributionProvider.adjust,
        ),
        throwsA(
          isA<AdaptyError>()
              .having((error) => error.code, 'code', AdaptyErrorCode.badRequest)
              .having((error) => error.message, 'message', 'bad request')
              .having((error) => error.detail, 'detail', 'native'),
        ),
      );
    });

    test('reports a wrong parameter before invoking native code', () async {
      await expectLater(
        Adapty().updateExternalAttribution(<String, dynamic>{
          'invalid': Object(),
        }, provider: AdaptyExternalAttributionProvider.custom),
        throwsA(isA<AdaptyError>().having((error) => error.code, 'code', AdaptyErrorCode.wrongParam)),
      );

      expect(calls, isEmpty);
    });
  });
}

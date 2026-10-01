import 'dart:convert';
import 'dart:io' show Platform;

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_configuration.dart' show AdaptyConfigurationJSONBuilder;
import 'package:adapty_flutter/src/models/adapty_sdk_native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Read before any test sets the override: no default may leak into an app's debug build.
  final defaultPlatformOverride = AdaptySDKNative.debugPlatformOverride;
  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    _mockNative(calls, {'success': true});
  });

  tearDown(() {
    AdaptySDKNative.debugPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  group('on iOS', () {
    setUp(() {
      AdaptySDKNative.debugPlatformOverride = TargetPlatform.iOS;
    });

    test('getPendingStoreMessageTypes sends an empty request and returns the native types in order', () async {
      _mockNative(calls, {
        'success': ['billing_issue', 'storekit_-42'],
      });

      final types = await Adapty().getPendingStoreMessageTypes();

      expect(calls.single.method, 'get_pending_store_message_types');
      expect(jsonDecode(calls.single.arguments as String), <String, dynamic>{});
      expect(types, [AdaptyStoreMessageType.billingIssue, AdaptyStoreMessageType('storekit_-42')]);
    });

    test('getPendingStoreMessageTypes returns an empty list, not null, when nothing is pending', () async {
      _mockNative(calls, {'success': <String>[]});

      expect(await Adapty().getPendingStoreMessageTypes(), <AdaptyStoreMessageType>[]);
    });

    test('getPendingStoreMessageTypes keeps the native order and duplicates', () async {
      _mockNative(calls, {
        'success': ['storekit_7', 'billing_issue', 'storekit_7'],
      });

      expect(await Adapty().getPendingStoreMessageTypes(), [
        AdaptyStoreMessageType('storekit_7'),
        AdaptyStoreMessageType.billingIssue,
        AdaptyStoreMessageType('storekit_7'),
      ]);
    });

    test('getPendingStoreMessageTypes fails with the native AdaptyError instead of returning null', () async {
      _mockNative(calls, {
        'error': {'adapty_code': 2006, 'message': 'Decoding failed: unknown request'},
      });

      await expectLater(
        Adapty().getPendingStoreMessageTypes(),
        _throwsAdaptyError(AdaptyErrorCode.decodingFailed, 'Decoding failed: unknown request'),
      );
    });

    test('showStoreMessages sends a filter only when one is given, an empty one included', () async {
      await Adapty().showStoreMessages();
      await Adapty().showStoreMessages(
        iosFilter: [AdaptyStoreMessageType.priceIncreaseConsent, AdaptyStoreMessageType('storekit_7')],
      );
      await Adapty().showStoreMessages(iosFilter: []);

      expect(calls.map((call) => call.method), ['show_store_messages', 'show_store_messages', 'show_store_messages']);
      expect(calls.map((call) => jsonDecode(call.arguments as String)), [
        <String, dynamic>{},
        {
          'filter': ['price_increase_consent', 'storekit_7'],
        },
        {'filter': []},
      ]);
    });

    test('showStoreMessages forwards the filter as given: duplicates, padded and unknown values included', () async {
      await Adapty().showStoreMessages(
        iosFilter: [
          AdaptyStoreMessageType.billingIssue,
          AdaptyStoreMessageType(' generic '),
          AdaptyStoreMessageType('foo'),
          AdaptyStoreMessageType.billingIssue,
        ],
      );

      expect(jsonDecode(calls.single.arguments as String), {
        'filter': ['billing_issue', ' generic ', 'foo', 'billing_issue'],
      });
    });

    test('showStoreMessages fails with the native AdaptyError, code and message unchanged', () async {
      _mockNative(calls, {
        'error': {'adapty_code': 3201, 'message': 'Another store message show operation is already in progress.'},
      });
      await expectLater(
        Adapty().showStoreMessages(),
        _throwsAdaptyError(
          AdaptyErrorCode.operationInProgress,
          'Another store message show operation is already in progress.',
        ),
      );

      _mockNative(calls, {
        'error': {
          'adapty_code': 3202,
          'message': 'No foreground-active UIWindowScene is available to display store messages.',
        },
      });
      await expectLater(
        Adapty().showStoreMessages(),
        _throwsAdaptyError(
          AdaptyErrorCode.resolverFailure,
          'No foreground-active UIWindowScene is available to display store messages.',
        ),
      );
    });
  });

  group('on Android', () {
    setUp(() {
      AdaptySDKNative.debugPlatformOverride = TargetPlatform.android;
    });

    test('getPendingStoreMessageTypes returns null without calling the native side', () async {
      _mockNative(calls, {'success': <String>[]});

      final types = await Adapty().getPendingStoreMessageTypes();

      expect(calls, isEmpty);
      expect(types, isNull);
    });

    test('showStoreMessages calls the native side without a filter, even when one is given', () async {
      await Adapty().showStoreMessages();
      await Adapty().showStoreMessages(iosFilter: [AdaptyStoreMessageType.billingIssue]);
      await Adapty().showStoreMessages(iosFilter: []);

      expect(calls.map((call) => call.method), ['show_store_messages', 'show_store_messages', 'show_store_messages']);
      expect(calls.map((call) => jsonDecode(call.arguments as String)), [
        <String, dynamic>{},
        <String, dynamic>{},
        <String, dynamic>{},
      ]);
    });
  });

  test('on any other platform, getPendingStoreMessageTypes returns null and no filter is sent', () async {
    AdaptySDKNative.debugPlatformOverride = TargetPlatform.linux;
    _mockNative(calls, {'success': <String>[]});

    final types = await Adapty().getPendingStoreMessageTypes();
    await Adapty().showStoreMessages(iosFilter: [AdaptyStoreMessageType.billingIssue]);

    expect(types, isNull);
    expect(calls.single.method, 'show_store_messages');
    expect(jsonDecode(calls.single.arguments as String), <String, dynamic>{});
  });

  test('the configuration leaves store_messages_handling out unless it is set', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      AdaptySDKNative.debugPlatformOverride = platform;

      final json = AdaptyConfiguration(apiKey: 'test-api-key').jsonValue as Map<String, dynamic>;

      expect(json, isNot(contains('store_messages_handling')), reason: '$platform');
    }
  });

  test('the configuration sends the chosen store messages handling on both platforms', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      AdaptySDKNative.debugPlatformOverride = platform;

      final manual = AdaptyConfiguration(apiKey: 'test-api-key')
        ..withStoreMessagesHandling(AdaptyStoreMessagesHandling.manual);
      final auto = AdaptyConfiguration(apiKey: 'test-api-key')
        ..withStoreMessagesHandling(AdaptyStoreMessagesHandling.auto);

      expect((manual.jsonValue as Map<String, dynamic>)['store_messages_handling'], 'manual', reason: '$platform');
      expect((auto.jsonValue as Map<String, dynamic>)['store_messages_handling'], 'auto', reason: '$platform');
    }
  });

  test('AdaptyStoreMessageType carries the wire value of each known reason', () {
    expect(AdaptyStoreMessageType.generic.value, 'generic');
    expect(AdaptyStoreMessageType.priceIncreaseConsent.value, 'price_increase_consent');
    expect(AdaptyStoreMessageType.billingIssue.value, 'billing_issue');
    expect(AdaptyStoreMessageType.winBackOffer.value, 'win_back_offer');
  });

  test('AdaptyStoreMessageType compares by value, so a built value matches the known one', () {
    final billingIssue = AdaptyStoreMessageType('billing_issue');

    expect(billingIssue, AdaptyStoreMessageType.billingIssue);
    expect(billingIssue.hashCode, AdaptyStoreMessageType.billingIssue.hashCode);
    expect({AdaptyStoreMessageType.billingIssue}.contains(billingIssue), isTrue);
    expect(AdaptyStoreMessageType('storekit_1'), isNot(AdaptyStoreMessageType('storekit_2')));
    expect(AdaptyStoreMessageType.priceIncreaseConsent.toString(), 'AdaptyStoreMessageType(price_increase_consent)');
  });

  test('AdaptySDKNative reports the overridden platform, and the host one without an override', () {
    expect(defaultPlatformOverride, isNull);

    (bool, bool) reportedFor(TargetPlatform? platform) {
      AdaptySDKNative.debugPlatformOverride = platform;
      return (AdaptySDKNative.isIOS, AdaptySDKNative.isAndroid);
    }

    expect(reportedFor(TargetPlatform.iOS), (true, false));
    expect(reportedFor(TargetPlatform.macOS), (true, false));
    expect(reportedFor(TargetPlatform.android), (false, true));
    expect(reportedFor(TargetPlatform.linux), (false, false));
    expect(reportedFor(null), (Platform.isIOS || Platform.isMacOS, Platform.isAndroid));
  });
}

/// Records every call into [calls] and answers each one with [reply].
void _mockNative(List<MethodCall> calls, Map<String, dynamic> reply) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
    calls.add(call);
    return jsonEncode(reply);
  });
}

/// Matches a future that fails with an [AdaptyError] carrying [code] and [message].
Matcher _throwsAdaptyError(int code, String message) {
  return throwsA(
    isA<AdaptyError>().having((error) => error.code, 'code', code).having((error) => error.message, 'message', message),
  );
}

/// What a call does when its arguments can't be encoded as JSON, as a NaN or infinite custom attribute: the encoding
/// error is thrown as it is, not as an [AdaptyError], and nothing reaches the native side.
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  for (final (name, value) in [
    ('a NaN', double.nan),
    ('an infinite', double.infinity),
    ('a negative infinite', double.negativeInfinity),
  ]) {
    test('updateProfile with $name custom attribute throws the JSON encoding error and calls nothing', () async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
        call,
      ) async {
        calls.add(call.method);
        return jsonEncode({'success': true});
      });

      final params = (AdaptyProfileParametersBuilder()..setCustomDoubleAttribute(value, 'score')).build();

      await expectLater(
        Adapty().updateProfile(params),
        throwsA(
          isA<JsonUnsupportedObjectError>().having((e) => e.unsupportedObject, 'unsupportedObject', _isNaNOr(value)),
        ),
      );
      expect(calls, isEmpty);
    });
  }

  test('the same arguments without the unencodable value reach the native side', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return jsonEncode({'success': true});
    });

    await Adapty().updateProfile((AdaptyProfileParametersBuilder()..setCustomDoubleAttribute(1.5, 'score')).build());

    expect(calls.map((call) => call.method), ['update_profile']);
    expect(jsonDecode(calls.single.arguments as String), {
      'params': {
        'custom_attributes': {'score': 1.5},
      },
    });
  });
}

/// Matches [value], or any NaN when [value] is NaN (a NaN is not equal to itself).
Matcher _isNaNOr(double value) => value.isNaN ? isNaN : equals(value);

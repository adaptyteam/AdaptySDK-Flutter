/// The `report_transaction` request: on iOS the signed StoreKit 2 transaction goes to the native
/// side as `apple_jws_transaction`, exactly as given; on every other platform it is left out, and
/// without it the request is the same as before.
///
/// Every test sets `AdaptySDKNative.debugPlatformOverride`, so the result does not depend on the
/// host: `isIOS` is false on the Linux CI runner and true on a macOS host.
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_sdk_native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

/// A compact JWS of the StoreKit 2 shape (header, payload and signature, base64url-encoded).
const _jws = 'eyJhbGciOiJFUzI1NiJ9.eyJ0cmFuc2FjdGlvbklkIjoiMjAwMDAwMDAwMDAwMDAwMSJ9.c2lnbmF0dXJl';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return jsonEncode({'success': true});
    });
  });

  tearDown(() {
    AdaptySDKNative.debugPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  List<Object?> requests() {
    expect(AdaptySDKNative.debugPlatformOverride, isNotNull, reason: 'every test sets the platform');
    expect(calls.map((call) => call.method), everyElement('report_transaction'));
    return calls.map((call) => jsonDecode(call.arguments as String)).toList();
  }

  group('on iOS', () {
    setUp(() {
      AdaptySDKNative.debugPlatformOverride = TargetPlatform.iOS;
    });

    test('sends the JWS as apple_jws_transaction next to the transaction and variation ids', () async {
      await Adapty().reportTransaction(
        transactionId: '2000000000000001',
        variationId: 'variation-id',
        appleJwsTransaction: _jws,
      );

      expect(requests(), [
        {'transaction_id': '2000000000000001', 'variation_id': 'variation-id', 'apple_jws_transaction': _jws},
      ]);
    });

    test('sends the JWS without a variation id, which stays out of the request', () async {
      await Adapty().reportTransaction(transactionId: '2000000000000001', appleJwsTransaction: _jws);

      expect(requests(), [
        {'transaction_id': '2000000000000001', 'apple_jws_transaction': _jws},
      ]);
    });

    test('leaves apple_jws_transaction out when no JWS is given', () async {
      await Adapty().reportTransaction(transactionId: '2000000000000001', variationId: 'variation-id');
      await Adapty().reportTransaction(transactionId: '2000000000000001');

      expect(requests(), [
        {'transaction_id': '2000000000000001', 'variation_id': 'variation-id'},
        {'transaction_id': '2000000000000001'},
      ]);
    });

    test('sends the JWS as given: an empty or padded value is not trimmed or dropped', () async {
      await Adapty().reportTransaction(transactionId: '2000000000000001', appleJwsTransaction: '');
      await Adapty().reportTransaction(transactionId: '2000000000000001', appleJwsTransaction: ' $_jws\n');

      expect(requests(), [
        {'transaction_id': '2000000000000001', 'apple_jws_transaction': ''},
        {'transaction_id': '2000000000000001', 'apple_jws_transaction': ' $_jws\n'},
      ]);
    });
  });

  test('on Android, the JWS is left out and the request is the same as without it', () async {
    AdaptySDKNative.debugPlatformOverride = TargetPlatform.android;

    await Adapty().reportTransaction(
      transactionId: 'GPA.3333-4444-5555-66666',
      variationId: 'variation-id',
      appleJwsTransaction: _jws,
    );
    await Adapty().reportTransaction(transactionId: 'GPA.3333-4444-5555-66666', appleJwsTransaction: _jws);

    expect(requests(), [
      {'transaction_id': 'GPA.3333-4444-5555-66666', 'variation_id': 'variation-id'},
      {'transaction_id': 'GPA.3333-4444-5555-66666'},
    ]);
  });

  test('on any other platform, the JWS is left out', () async {
    AdaptySDKNative.debugPlatformOverride = TargetPlatform.linux;

    await Adapty().reportTransaction(transactionId: '2000000000000001', appleJwsTransaction: _jws);

    expect(requests(), [
      {'transaction_id': '2000000000000001'},
    ]);
  });
}

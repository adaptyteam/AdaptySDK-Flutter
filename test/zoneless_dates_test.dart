/// Dates without a time zone, which the native contract does not allow: a date always comes with
/// `Z` or `+0000`. A defensive case: how such a date decodes today.
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

/// The reply of the mocked native side per method; a method not listed answers `{"success": true}`.
final _replies = <String, Map<String, dynamic>>{};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _replies.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => jsonEncode(_replies[call.method] ?? {'success': true}),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('a date without a zone is read as local time', () async {
    _replies['get_profile'] = {'success': _profile(accessLevel: _accessLevel(activatedAt: '2026-08-24T09:34:24.727'))};

    final profile = await Adapty().getProfile();

    final activatedAt = profile.accessLevels['premium']!.activatedAt;
    expect(activatedAt.isUtc, isFalse);
    expect(
      [
        activatedAt.year,
        activatedAt.month,
        activatedAt.day,
        activatedAt.hour,
        activatedAt.minute,
        activatedAt.second,
        activatedAt.millisecond,
      ],
      [2026, 8, 24, 9, 34, 24, 727],
    );
  });
}

Map<String, dynamic> _profile({required Map<String, dynamic> accessLevel}) => {
  'profile_id': 'profile-id',
  'segment_hash': 'segment-hash',
  'timestamp': 1760436000000,
  'is_test_user': false,
  'paid_access_levels': {'premium': accessLevel},
};

Map<String, dynamic> _accessLevel({required String activatedAt}) => {
  'id': 'premium',
  'is_active': true,
  'vendor_product_id': 'weekly.premium.599',
  'store': 'app_store',
  'activated_at': activatedAt,
  'is_lifetime': false,
  'will_renew': true,
  'is_in_grace_period': false,
  'is_refund': false,
};

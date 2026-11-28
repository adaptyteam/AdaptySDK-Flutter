/// How a call reads a reply that has neither `success` nor `error` at its top level.
///
/// Both native SDKs wrap every reply in one of the two keys. Two replies can still reach a call without them: an empty
/// object, which no native SDK sends, and the error the iOS plugin writes on its own when it fails to encode a reply,
/// `{"adapty_code":2009,"message":…,"detail":…}`. A call reads either one as a success with no value: a call without a
/// result completes, and a call whose result is read fails with an internal plugin error from reading the missing
/// value.
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

/// The reply of the iOS plugin when it fails to encode the reply of a call: its plugin error at the top level.
const _encodingFailedReply = {
  'adapty_code': 2009,
  'message': 'Encoding failed: The data couldn’t be written because it isn’t in the correct format.',
  'detail': 'AdaptyPluginError.encodingFailed: Encoding failed invalidValue',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  void replyWith(Map<String, dynamic> reply) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => jsonEncode(reply),
    );
  }

  Matcher internalPluginErrorOf(String method, String detail) => isA<AdaptyError>()
      .having((e) => e.code, 'code', AdaptyErrorCode.internalPluginError)
      .having((e) => e.message, 'message', 'Internal plugin error in Adapty.$method()')
      .having((e) => e.detail, 'detail', contains(detail));

  group('an empty reply', () {
    test('completes a call without a result', () async {
      replyWith({});

      await expectLater(Adapty().logout(), completes);
    });

    test('fails a call whose result is read with an internal plugin error', () async {
      replyWith({});

      await expectLater(
        Adapty().getProfile(),
        throwsA(internalPluginErrorOf('get_profile', "type 'Null' is not a subtype of type 'Map<String, dynamic>'")),
      );
    });
  });

  group('the encoding error of the iOS plugin without an error key', () {
    test('completes a call without a result', () async {
      replyWith(_encodingFailedReply);

      await expectLater(Adapty().logout(), completes);
    });

    test('fails a call whose result is a model with an internal plugin error', () async {
      replyWith(_encodingFailedReply);

      await expectLater(
        Adapty().getProfile(),
        throwsA(internalPluginErrorOf('get_profile', "type 'Null' is not a subtype of type 'Map<String, dynamic>'")),
      );
    });

    test('fails a call whose result is a value with an internal plugin error', () async {
      replyWith(_encodingFailedReply);

      await expectLater(
        Adapty().isActivated(),
        throwsA(internalPluginErrorOf('is_activated', "type 'Null' is not a subtype of type 'bool'")),
      );
    });
  });
}

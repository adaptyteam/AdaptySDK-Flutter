// A call of the SDK checked against the bridge contract without a channel or a runtime: the request it is, what is
// wrong with it on a platform, what the baseline takes away, and what the native answers when it does not get to the
// call proper, in the words the plugins use on a device.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/baseline.dart';
import '../../tool/contract/src/contract_schema.dart';
import '../../tool/contract/src/corpus.dart';
import '../../tool/contract/src/request_check.dart';

const ios = ContractPlatform.ios;
const android = ContractPlatform.android;

final _schema = ContractSchema.load('.');

/// The items of a baseline of single entries, each with the fields given over those of an extra key of `get_profile`.
List<BaselineItem> _baseline(List<Map<String, Object?>> entries) => baselineItems([
  for (final fields in entries)
    BaselineEntry(
      id: fields['id']! as String,
      decision: (fields['decision'] ?? 'accepted') as String,
      reason: 'r',
      fields: {
        'direction': 'request',
        'entry': 'GetProfile.Request',
        'keyword': 'additionalProperties',
        'platform': 'android',
        'decision': 'accepted',
        'reason': 'r',
        ...fields,
      },
    ),
]);

/// The kept violations of [check] as `<path> <keyword>`.
List<String> _kept(RequestCheck check) => [for (final v in check.kept) '${v.instancePath} ${v.keyword}'];

/// The taken violations of [check] as `<path> <keyword> <id of the item>`.
List<String> _taken(RequestCheck check) => [
  for (final (v, item) in check.taken) '${v.instancePath} ${v.keyword} ${item.id}',
];

void main() {
  group('normalizing a request', () {
    test('the SDK version is replaced at any depth and nothing else is', () {
      expect(
        normalizedRequest({
          'api_key': 'key',
          'cross_platform_sdk_version': '1.0.0',
          'nested': [
            {'cross_platform_sdk_version': '1.0.0', 'version': '1.0.0'},
          ],
        }),
        {
          'api_key': 'key',
          'cross_platform_sdk_version': '<sdk-version>',
          'nested': [
            {'cross_platform_sdk_version': '<sdk-version>', 'version': '1.0.0'},
          ],
        },
      );
    });

    test('a version that is not a text stays what it is', () {
      expect(normalizedRequest({'cross_platform_sdk_version': 4}), {'cross_platform_sdk_version': 4});
    });

    test('app message ids count up in the last group of a version 4 UUID', () {
      expect(contractMessageId(1), '00000000-0000-4000-8000-000000000001');
      expect(contractMessageId(26), '00000000-0000-4000-8000-00000000001a');
    });
  });

  test('the answers to events are the requests of the contract that require an event id', () {
    expect(eventAnswerMethods(_schema), {
      'flow_view_did_answer_permission',
      'observer_purchase_did_start',
      'observer_purchase_did_finish',
      'observer_restore_did_start',
      'observer_restore_did_finish',
    });
  });

  group('checking a call', () {
    test('a request the contract accepts has nothing kept or taken', () {
      final check = checkRequest(_schema, const [], method: 'get_profile', arguments: {}, platform: ios)!;
      expect((check.entry.name, check.handled), ('GetProfile.Request', true));
      expect(check.kept, isEmpty);
      expect(check.taken, isEmpty);
    });

    test('a key the contract does not know is kept with its path', () {
      final check = checkRequest(_schema, const [], method: 'get_profile', arguments: {'bogus': 1}, platform: android)!;
      expect(_kept(check), ['/bogus additionalProperties']);
    });

    test('a method the platform does not handle is a platform_method violation of the whole payload', () {
      final check = checkRequest(_schema, const [], method: 'get_log_level', arguments: {}, platform: android)!;
      expect(check.handled, isFalse);
      expect(_kept(check), [' platform_method']);
      expect(check.kept.single.detail, 'android does not handle get_log_level');
    });

    test('arguments that are not a JSON object are not validated', () {
      final check = checkRequest(_schema, const [], method: 'get_log_level', arguments: null, platform: android)!;
      expect(_kept(check), [' platform_method']);
    });

    test('a method outside the contract is no request', () {
      expect(checkRequest(_schema, const [], method: 'get_flows', arguments: {}, platform: ios), isNull);
    });

    test('an item takes away exactly its violation, the first matching item takes it', () {
      final baseline = _baseline([
        {'id': 'bogus', 'path': '/bogus', 'case': 'get_profile/bogus'},
        {'id': 'other', 'path': '/other', 'case': 'get_profile/other'},
        {'id': 'other-again', 'path': '/other', 'case': 'get_profile/again'},
      ]);

      final check = checkRequest(
        _schema,
        baseline,
        method: 'get_profile',
        arguments: {'other': 2, 'third': 3},
        platform: android,
      )!;

      expect(_kept(check), ['/third additionalProperties']);
      expect(_taken(check), ['/other additionalProperties other']);
    });

    test('an item of the other platform takes nothing away', () {
      final baseline = _baseline([
        {'id': 'bogus', 'path': '/bogus', 'case': 'get_profile/bogus'},
      ]);
      final check = checkRequest(_schema, baseline, method: 'get_profile', arguments: {'bogus': 1}, platform: ios)!;
      expect(_kept(check), ['/bogus additionalProperties']);
      expect(check.taken, isEmpty);
    });

    test('an item takes away a method the platform does not handle, which stays unhandled', () {
      final baseline = _baseline([
        {
          'id': 'unhandled',
          'entry': 'GetLogLevel.Request',
          'path': '',
          'keyword': 'platform_method',
          'case': 'get_log_level/default',
        },
      ]);
      final check = checkRequest(_schema, baseline, method: 'get_log_level', arguments: {}, platform: android)!;
      expect(check.handled, isFalse);
      expect(check.kept, isEmpty);
      expect(_taken(check), [' platform_method unhandled']);
    });
  });

  group('an entry of the baseline that is not accepted', () {
    final pending = _baseline([
      {'id': 'pending', 'path': '/bogus', 'case': 'get_profile/bogus', 'decision': 'ask_native'},
    ]);
    RequestCheck check(List<BaselineItem> baseline, {String? declaredCase}) => checkRequest(
      _schema,
      baseline,
      method: 'get_profile',
      arguments: {'bogus': 1},
      platform: android,
      declaredCase: declaredCase,
    )!;

    test('takes nothing away from a call that is not declared as a case', () {
      expect(_kept(check(pending)), ['/bogus additionalProperties']);
      expect(check(pending).taken, isEmpty);
    });

    test('takes its violation away in a call declared as its case', () {
      final declared = check(pending, declaredCase: 'get_profile/bogus');
      expect(declared.kept, isEmpty);
      expect(_taken(declared), ['/bogus additionalProperties pending']);
    });

    test('takes nothing away from a call declared as another case', () {
      expect(_kept(check(pending, declaredCase: 'get_profile/other')), ['/bogus additionalProperties']);
    });

    test('of a batch has the cases of its items', () {
      final batch = baselineItems([
        const BaselineEntry(
          id: 'pending-batch',
          decision: 'fix_dart',
          reason: 'r',
          fields: {
            'id': 'pending-batch',
            'direction': 'request',
            'keyword': 'additionalProperties',
            'items': [
              {'entry': 'GetProfile.Request', 'path': '/bogus', 'platform': 'android', 'case': 'get_profile/a'},
              {'entry': 'GetProfile.Request', 'path': '/bogus', 'platform': 'android', 'case': 'get_profile/b'},
            ],
            'reason': 'r',
            'decision': 'fix_dart',
            'source': ['s'],
          },
        ),
      ]);
      for (final declared in ['get_profile/a', 'get_profile/b']) {
        expect(_taken(check(batch, declaredCase: declared)), [
          '/bogus additionalProperties pending-batch',
        ], reason: declared);
      }
      expect(_kept(check(batch, declaredCase: 'get_profile/c')), ['/bogus additionalProperties']);
      expect(_kept(check(batch)), ['/bogus additionalProperties']);
    });

    test(
      'an accepted entry takes its violation away in a call not declared, and in a declared one only in its case',
      () {
        final accepted = _baseline([
          {'id': 'accepted', 'path': '/bogus', 'case': 'get_profile/bogus'},
        ]);
        expect(_taken(check(accepted)), ['/bogus additionalProperties accepted']);
        expect(_taken(check(accepted, declaredCase: 'get_profile/bogus')), ['/bogus additionalProperties accepted']);
        expect(_kept(check(accepted, declaredCase: 'get_profile/other')), ['/bogus additionalProperties']);
      },
    );
  });

  group('in a call declared as a case', () {
    RequestCheck check(List<BaselineItem> baseline) => checkRequest(
      _schema,
      baseline,
      method: 'get_profile',
      arguments: {'bogus': 1},
      platform: android,
      declaredCase: 'get_profile/bogus',
    )!;

    test('an accepted item of an embedded view takes nothing away', () {
      final view = _baseline([
        {'id': 'view', 'path': '/bogus', 'case': 'pseudo/flow_platform_view/default'},
      ]);
      expect(_kept(check(view)), ['/bogus additionalProperties']);
    });

    test('an accepted item of a case of another method takes nothing away', () {
      final other = _baseline([
        {'id': 'other', 'path': '/bogus', 'case': 'get_flow/default'},
      ]);
      expect(_kept(check(other)), ['/bogus additionalProperties']);
    });

    test('an accepted item of another case of the same method takes nothing away', () {
      final sibling = _baseline([
        {'id': 'sibling', 'path': '/bogus', 'case': 'get_profile/other'},
      ]);
      expect(_kept(check(sibling)), ['/bogus additionalProperties']);
    });

    test('the item of the case takes the violation away before any other', () {
      final both = _baseline([
        {'id': 'sibling', 'path': '/bogus', 'case': 'get_profile/other'},
        {'id': 'own', 'path': '/bogus', 'case': 'get_profile/bogus'},
      ]);
      expect(_taken(check(both)), ['/bogus additionalProperties own']);
    });
  });

  // The answers as the plugins sent them to the probe app on a simulator and an emulator: iOS 4.4.1, Android
  // 4.4.0, with the SDK not activated.
  group('what the native answers', () {
    Object? decoded(String reply) => jsonDecode(reply);

    test('to a method it has no request for', () {
      expect(decoded(methodNotFoundReply('no_such_method_l2a', ios)), {
        'error': {
          'adapty_code': 2006,
          'message':
              'Decoding failed: The operation couldn’t be completed. (AdaptyPlugin.AdaptyPluginInternalError error 0.)',
          'detail': 'AdaptyPluginError.decodingFailed: Decoding failed unknownRequest("no_such_method_l2a")',
        },
      });
      expect(decoded(methodNotFoundReply('no_such_method_l2a', android)), {
        'error': {'adapty_code': 2006, 'message': 'Method no_such_method_l2a not found'},
      });
    });

    test('to a view it does not know', () {
      expect(decoded(viewNotFoundReply('l2a-nope', ios)), {
        'error': {
          'adapty_code': 3001,
          'message': 'AdaptyUIError.viewNotFound(l2a-nope)',
          'detail': jsonEncode({
            'detail': 'AdaptyUIError.viewNotFound(l2a-nope)',
            'adapty_code': 3001,
            'message': 'AdaptyUIError.viewNotFound(l2a-nope)',
          }),
        },
      });
      expect(decoded(viewNotFoundReply('l2a-nope', android)), {
        'error': {'adapty_code': 3001, 'message': 'AdaptyUIError.viewNotFound(l2a-nope)'},
      });
    });

    test('on iOS to creating a flow view before AdaptyUI is activated', () {
      const message =
          'AdaptyUIError.adaptyUINotActivated (Code: 4003): AdaptyUI SDK is not initialized. '
          'Ensure AdaptyUI.activate() is called before any UI-related operations.';
      final reply = decoded(adaptyUINotActivatedReply)! as Map<String, Object?>;
      final error = reply['error']! as Map<String, Object?>;
      expect((error['adapty_code'], error['message']), (4003, message));
      expect(jsonDecode(error['detail']! as String), {
        'detail': 'AdaptyUI SDK must be initialized before using its methods. Please call AdaptyUI.activate() first.',
        'adapty_code': 4003,
        'message': message,
      });
    });

    test('on iOS to a call of the SDK proper names the version of the SDK it is given', () {
      final error =
          (decoded(notActivatedReply(ios, version: '9.9.9'))! as Map<String, Object?>)['error']!
              as Map<String, Object?>;
      expect(
        (jsonDecode(error['detail']! as String) as Map<String, Object?>)['detail'],
        'AdaptyError.notActivated([9.9.9]: Adapty/Adapty+Shared.swift#43)',
      );
    });

    test('to a call of the SDK proper before it is activated', () {
      const message = 'Adapty SDK is not initialized. You need to activate the SDK before using its methods.';
      final error =
          (decoded(notActivatedReply(ios, version: '4.4.1'))! as Map<String, Object?>)['error']!
              as Map<String, Object?>;
      expect((error['adapty_code'], error['message']), (2002, message));
      expect(jsonDecode(error['detail']! as String), {
        'adapty_code': 2002,
        'message': message,
        'detail': 'AdaptyError.notActivated([4.4.1]: Adapty/Adapty+Shared.swift#43)',
      });
      expect(decoded(notActivatedReply(android, version: '4.4.1')), {
        'error': {'adapty_code': 20, 'message': 'Adapty was not initialized'},
      });
    });
  });
}

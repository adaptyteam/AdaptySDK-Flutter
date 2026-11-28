/// A call of the SDK on the adapty channel checked against the bridge contract of one platform, and
/// what the native side of that platform answers when it does not get to the call proper.
library;

import 'dart:convert';

import 'baseline.dart';
import 'contract_schema.dart';

/// What a cross-platform SDK version is replaced with by [normalizedRequest].
const sdkVersionPlaceholder = '<sdk-version>';

/// [value] with every value that changes from one release of the SDK to the next replaced by a
/// placeholder: a cross-platform SDK version, at any depth, becomes [sdkVersionPlaceholder].
Object? normalizedRequest(Object? value) => switch (value) {
  Map<String, Object?>() => {
    for (final MapEntry(:key, :value) in value.entries)
      key: key == 'cross_platform_sdk_version' && value is String ? sdkVersionPlaceholder : normalizedRequest(value),
  },
  List<Object?>() => [for (final item in value) normalizedRequest(item)],
  _ => value,
};

/// The app message id the contract runtime gives its [n]th message, counting from 1: a version 4
/// UUID that is the same in every run.
String contractMessageId(int n) => '00000000-0000-4000-8000-${n.toRadixString(16).padLeft(12, '0')}';

/// The methods of [schema] that answer an event of the native side: the requests that require an
/// `event_id`.
Set<String> eventAnswerMethods(ContractSchema schema) => {
  for (final method in schema.requestMethods)
    if ((schema.resolve(schema.requestEntry(method).pointer)! as Map<String, Object?>)['required']
        case final List<Object?> required when required.contains('event_id'))
      method,
};

/// A call checked against its request: the [kept] violations are problems, the [taken] ones the
/// baseline takes away, each with its item.
final class RequestCheck {
  const RequestCheck({required this.entry, required this.handled, required this.kept, required this.taken});

  /// The request of the contract the call is.
  final SchemaEntry entry;

  /// Whether the platform handles the method; when it does not, the native answers [methodNotFoundReply].
  final bool handled;
  final List<Violation> kept;
  final List<(Violation, BaselineItem)> taken;
}

/// Checks a call of [method] with [arguments] on [platform]: the violations of its request, a
/// `platform_method` violation when the platform does not handle the method, each taken away by its
/// item of [baseline] ([takingItem]; the call is the case [declaredCase] when it is given) or kept.
/// Arguments that are not a JSON object ([arguments] null) are not validated. Null when [method] is
/// not a request of the contract.
RequestCheck? checkRequest(
  ContractSchema schema,
  List<BaselineItem> baseline, {
  required String method,
  required Map<String, Object?>? arguments,
  required ContractPlatform platform,
  String? declaredCase,
}) {
  final SchemaEntry entry;
  try {
    entry = schema.requestEntry(method);
  } on ArgumentError {
    return null;
  }
  final handled = schema.methodPlatforms[method]!.contains(platform);
  final violations = [
    if (arguments != null) ...schema.validate(entry, arguments, platform: platform).violations,
    if (!handled)
      Violation(
        instancePath: '',
        keyword: 'platform_method',
        schemaPointer: entry.pointer,
        detail: '${platform.name} does not handle $method',
      ),
  ];
  final kept = <Violation>[];
  final taken = <(Violation, BaselineItem)>[];
  for (final violation in violations) {
    final item = takingItem(baseline, entry.name, platform, violation, declaredCase: declaredCase);
    if (item == null) {
      kept.add(violation);
    } else {
      taken.add((violation, item));
    }
  }
  return RequestCheck(entry: entry, handled: handled, kept: kept, taken: taken);
}

/// The answer of a plugin to a method it has no request for, as a JSON string. Android 4.4.0:
/// `crossplatform/src/main/java/com/adapty/internal/crossplatform/AdaptyCallHandler.kt:104,710-712`.
/// iOS 4.4.1: `Sources.AdaptyPlugin/Requests/Request.swift:87-92` (`unknownRequest`), with
/// the message of `Sources.AdaptyPlugin/Errors/AdaptyPluginError.swift:55` and the description of
/// the internal error, as the plugin answers on a simulator. On iOS this happens only to a method
/// outside the contract.
String methodNotFoundReply(String method, ContractPlatform platform) => switch (platform) {
  ContractPlatform.ios => jsonEncode({
    'error': {
      'adapty_code': 2006,
      'message':
          'Decoding failed: The operation couldn\u2019t be completed. (AdaptyPlugin.AdaptyPluginInternalError error 0.)',
      'detail': 'AdaptyPluginError.decodingFailed: Decoding failed unknownRequest("$method")',
    },
  }),
  ContractPlatform.android => jsonEncode({
    'error': {'adapty_code': 2006, 'message': 'Method $method not found'},
  }),
};

/// `AdaptyUIError.viewNotFound` of each plugin for the view [id], as a JSON string: code 3001; iOS
/// adds the error as the detail.
String viewNotFoundReply(String id, ContractPlatform platform) {
  final message = 'AdaptyUIError.viewNotFound($id)';
  return jsonEncode({
    'error': {
      'adapty_code': 3001,
      'message': message,
      if (platform == ContractPlatform.ios)
        'detail': jsonEncode({'detail': message, 'adapty_code': 3001, 'message': message}),
    },
  });
}

/// The iOS answer to creating a flow view before AdaptyUI is activated, as a JSON string: 4.4.1
/// `Sources.AdaptyUI/AdaptyUI+Public.swift:342-346`, texts from
/// `Sources.AdaptyUI/Error/AdaptyUIError+Description.swift:19,46`.
final String adaptyUINotActivatedReply = jsonEncode({
  'error': {
    'adapty_code': 4003,
    'message': _adaptyUINotActivatedMessage,
    'detail': jsonEncode({
      'detail': 'AdaptyUI SDK must be initialized before using its methods. Please call AdaptyUI.activate() first.',
      'adapty_code': 4003,
      'message': _adaptyUINotActivatedMessage,
    }),
  },
});

const _adaptyUINotActivatedMessage =
    'AdaptyUIError.adaptyUINotActivated (Code: 4003): AdaptyUI SDK is not initialized. '
    'Ensure AdaptyUI.activate() is called before any UI-related operations.';

/// The answer of each plugin to a call of the SDK proper before it is activated, as a JSON string: iOS
/// `notActivated` with the SDK error as the detail (`Sources/Errors/AdaptyError+Description.swift:21`),
/// Android `ADAPTY_NOT_INITIALIZED` without a detail (`adapty/src/main/java/com/adapty/Adapty.kt:862-863`,
/// `adapty/src/main/java/com/adapty/errors/AdaptyErrorCode.kt:8`). The iOS detail names the [version] of
/// the iOS SDK (`Adapty.SDKVersion`: `Sources/Errors/AdaptyError.Source.swift:12`,
/// `Sources/Versions.swift:12`). The contract record has no field for it; the version of the schema
/// stands for it, and the check of the record reports an iOS ref that names another version.
String notActivatedReply(ContractPlatform platform, {required String version}) => switch (platform) {
  ContractPlatform.ios => jsonEncode({
    'error': {
      'adapty_code': 2002,
      'message': _iosNotActivated,
      'detail': jsonEncode({
        'adapty_code': 2002,
        'message': _iosNotActivated,
        'detail': 'AdaptyError.notActivated([$version]: Adapty/Adapty+Shared.swift#43)',
      }),
    },
  }),
  ContractPlatform.android => jsonEncode({
    'error': {'adapty_code': 20, 'message': 'Adapty was not initialized'},
  }),
};

const _iosNotActivated = 'Adapty SDK is not initialized. You need to activate the SDK before using its methods.';

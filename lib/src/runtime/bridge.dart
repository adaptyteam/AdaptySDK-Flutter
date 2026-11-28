import 'dart:convert' show json;

import '../adapty_logger.dart';
import '../constants/argument.dart';
import '../constants/method.dart';
import '../models/adapty_error.dart';
import '../models/adapty_error_code.dart';
import '../models/adapty_log_level.dart';
import 'adapty_runtime.dart';

/// Calls [method] on the native side of [rt] with [arguments] as JSON and returns the success value of the reply, read
/// by [responseParser]. A null reply is thrown as an [AdaptyError] with [AdaptyErrorCode.emptyResult]; an error in the
/// reply, as that [AdaptyError]; anything else that goes wrong, as an [AdaptyError] with
/// [AdaptyErrorCode.internalPluginError]. Arguments that can't be encoded as JSON, such as a NaN or infinite double,
/// throw the encoding error as it is, and nothing is sent. The call and its log lines run bound to [rt].
Future<T> adaptyInvoke<T>(
  AdaptyRuntime rt,
  NativeRequest method,
  T Function(dynamic) responseParser,
  Map<String, dynamic>? arguments,
) {
  return rt.runBound(() async {
    final stamp = AdaptyLogger.stamp;
    final stringArguments = json.encode(arguments ?? {});
    final logArguments = _argumentsForLog(method.hiddenArguments, arguments, stringArguments);
    AdaptyLogger.write(AdaptyLogLevel.verbose, '[$stamp] --> Adapty.${method.wireName}(), Args: $logArguments');

    try {
      final stringResult = await rt.transport.invoke(method.wireName, stringArguments);
      AdaptyLogger.write(AdaptyLogLevel.verbose, '[$stamp] <-- Adapty.${method.wireName}(), Result: $stringResult');

      if (stringResult == null) {
        throw AdaptyError('Adapty.${method.wireName}() returned null', AdaptyErrorCode.emptyResult, null);
      }

      final decodedResult = json.decode(stringResult) as Map<String, dynamic>;
      AdaptyLogger.write(AdaptyLogLevel.verbose, '[$stamp] <-- Adapty.${method.wireName}(), Result: $decodedResult');

      if (decodedResult.containsKey(Argument.error)) {
        final adaptyErrorData = decodedResult[Argument.error];

        final adaptyError = AdaptyErrorJSONBuilder.fromJsonValue(adaptyErrorData);
        throw adaptyError;
      } else {
        final successData = decodedResult[Argument.success];
        final successObject = responseParser(successData);

        AdaptyLogger.write(
          AdaptyLogLevel.verbose,
          '[$stamp] <-- Adapty.${method.wireName}(), Success Object: $successObject',
        );

        return successObject;
      }
    } on AdaptyError catch (e) {
      AdaptyLogger.write(AdaptyLogLevel.verbose, '[$stamp] <-- Adapty.${method.wireName}() Error: $e');
      throw e;
    } catch (e) {
      final adaptyError = AdaptyError(
        'Internal plugin error in Adapty.${method.wireName}()',
        AdaptyErrorCode.internalPluginError,
        e.toString(),
      );

      AdaptyLogger.write(AdaptyLogLevel.verbose, '[$stamp] <-- Adapty.${method.wireName}() Error: $adaptyError');
      throw adaptyError;
    }
  });
}

/// [encoded], the arguments as the native side gets them, as the log shows them: the value of each key of [hidden]
/// that the arguments have is replaced with `<redacted>`, so it never reaches the log. Every map counts as an object,
/// whatever its type arguments. A path whose keys lead through something other than an object is not looked for.
String _argumentsForLog(List<String> hidden, Map<String, dynamic>? arguments, String encoded) {
  Map<Object?, Object?>? shown = arguments;
  for (final path in hidden) {
    shown = _redacted(shown, path.split('.'));
  }
  return identical(shown, arguments) ? encoded : json.encode(shown);
}

/// [object] with the value at [keys] replaced with `<redacted>`, the keys in their order; [object] itself when it has
/// no such value.
Map<Object?, Object?>? _redacted(Map<Object?, Object?>? object, List<String> keys) {
  if (object == null || !object.containsKey(keys.first)) return object;
  if (keys.length == 1) return {...object, keys.first: '<redacted>'};
  final inner = object[keys.first];
  if (inner is! Map<Object?, Object?>) return object;
  final redacted = _redacted(inner, keys.sublist(1));
  return identical(redacted, inner) ? object : {...object, keys.first: redacted};
}

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
/// [AdaptyErrorCode.internalPluginError]. The call and its log lines run bound to [rt].
Future<T> adaptyInvoke<T>(
  AdaptyRuntime rt,
  NativeRequest method,
  T Function(dynamic) responseParser,
  Map<String, dynamic>? arguments,
) {
  return rt.runBound(() async {
    final stamp = AdaptyLogger.stamp;
    final stringArguments = json.encode(arguments ?? {});
    AdaptyLogger.write(AdaptyLogLevel.verbose, '[$stamp] --> Adapty.${method.wireName}(), Args: $stringArguments');

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

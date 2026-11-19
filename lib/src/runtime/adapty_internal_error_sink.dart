import '../adapty_logger.dart';
import '../models/adapty_log_level.dart';
import 'adapty_log_sink.dart';

/// What went wrong inside the SDK without reaching the app as an error.
enum AdaptyInternalErrorKind {
  /// A native event could not be read.
  eventDecodeFailed,

  /// An observer of flow or onboarding events threw.
  observerThrew,

  /// A handler or resolver the app set threw.
  handlerThrew,

  /// A call to the native side made in response to an event failed.
  replyFailed,

  /// The SDK could not complete a promoted purchase nobody listened for.
  promotedAutoCompleteFailed,

  /// A call the SDK made on its own and did not wait for failed.
  backgroundCallFailed,
}

/// One error the SDK swallowed, with what it was doing at the time.
final class AdaptyInternalErrorRecord {
  const AdaptyInternalErrorRecord(
    this.kind,
    this.error, {
    this.stack,
    required this.context,
    this.correlationId,
    this.where = 'Adapty._handleIncomingMethodCall',
  });

  final AdaptyInternalErrorKind kind;
  final Object error;
  final StackTrace? stack;

  /// The wire name of the event, the wire name of the native call, or the label of the background work.
  final String context;

  /// The `event_id` of the request, once it has been read. Not part of the log line.
  final String? correlationId;

  /// Where the log line says the error happened; used by the event kinds only.
  final String where;

  AdaptyLogLevel get logLevel => switch (kind) {
    AdaptyInternalErrorKind.eventDecodeFailed ||
    AdaptyInternalErrorKind.observerThrew ||
    AdaptyInternalErrorKind.handlerThrew ||
    AdaptyInternalErrorKind.replyFailed ||
    AdaptyInternalErrorKind.backgroundCallFailed => AdaptyLogLevel.error,
    AdaptyInternalErrorKind.promotedAutoCompleteFailed => AdaptyLogLevel.warn,
  };

  /// The log line, word for word what the SDK wrote before the sink existed.
  String get message => switch (kind) {
    AdaptyInternalErrorKind.eventDecodeFailed ||
    AdaptyInternalErrorKind.observerThrew ||
    AdaptyInternalErrorKind.handlerThrew ||
    AdaptyInternalErrorKind.replyFailed => 'Error in $where: $error',
    AdaptyInternalErrorKind.promotedAutoCompleteFailed =>
      'Failed to complete the promoted purchase automatically: $error',
    AdaptyInternalErrorKind.backgroundCallFailed => 'Adapty background call $context failed: $error',
  };
}

/// Where the SDK sends the errors it swallows.
abstract interface class AdaptyInternalErrorSink {
  void report(AdaptyInternalErrorRecord record);
}

/// Writes every record to [logSink], unless its level is below the log level.
final class LoggingErrorSink implements AdaptyInternalErrorSink {
  const LoggingErrorSink(this.logSink);

  final AdaptyLogSink logSink;

  @override
  void report(AdaptyInternalErrorRecord record) => writeAdaptyLogTo(logSink, record.logLevel, record.message);
}

/// Carries an error out of the handling of an event together with its kind, so the place that catches it can report
/// it as such.
final class IncomingEventFailure implements Exception {
  const IncomingEventFailure(this.kind, this.error, this.stack, {this.label, this.correlationId});

  final AdaptyInternalErrorKind kind;
  final Object error;
  final StackTrace stack;

  /// The wire name of the native call that failed, for [AdaptyInternalErrorKind.replyFailed].
  final String? label;

  /// The `event_id` of the request, once it has been read.
  final String? correlationId;
}

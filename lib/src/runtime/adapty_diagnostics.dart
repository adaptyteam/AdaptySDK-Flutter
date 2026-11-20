import 'adapty_internal_error_sink.dart';
import 'adapty_log_sink.dart';
import 'background_work.dart';

/// Where a runtime puts what goes wrong out of the app's sight, and its log.
final class AdaptyDiagnostics {
  /// The errors the SDK swallows go to [errorSink], to the log in [logSink] when it is null.
  AdaptyDiagnostics({required this.logSink, AdaptyInternalErrorSink? errorSink})
    : errorSink = errorSink ?? LoggingErrorSink(logSink);

  /// Where the log lines of the runtime go.
  final AdaptyLogSink logSink;

  final AdaptyInternalErrorSink errorSink;

  late final BackgroundWork background = BackgroundWork(errorSink);

  /// Ignored settings of custom linear gradients already warned about, e.g. `tileMode: TileMode.mirror`. Keyed by
  /// the setting rather than by the gradient: the embedded view serializes its creation params on every build, often
  /// from a gradient created in `build()`.
  final warnedIgnoredGradientSettings = <String>{};
}

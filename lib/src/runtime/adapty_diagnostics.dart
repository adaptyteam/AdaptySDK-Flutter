import 'adapty_internal_error_sink.dart';

/// Where a runtime puts what goes wrong out of the app's sight.
final class AdaptyDiagnostics {
  AdaptyDiagnostics(this.errorSink);

  final AdaptyInternalErrorSink errorSink;
}

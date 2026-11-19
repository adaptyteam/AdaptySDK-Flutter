import '../adaptyui_events_proxy.dart';
import '../adaptyui_observer_mode_resolver.dart';
import '../adaptyui_system_requests_handler.dart';
import 'adapty_diagnostics.dart';

/// What `AdaptyUI()` keeps between calls: the observers of flow and onboarding events with the embedded view errors
/// nobody listened for yet, the system requests handler and the observer mode resolver.
final class AdaptyUIState {
  AdaptyUIState(AdaptyDiagnostics diagnostics) : eventsProxy = AdaptyUIEventsProxy(diagnostics);

  final AdaptyUIEventsProxy eventsProxy;

  AdaptyUISystemRequestsHandler? systemRequestsHandler;

  AdaptyUIObserverModeResolver? observerModeResolver;
}

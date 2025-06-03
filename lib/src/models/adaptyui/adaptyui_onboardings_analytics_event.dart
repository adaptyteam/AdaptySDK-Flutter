part '../private/adaptyui_onboardings_analytics_event_json_builder.dart';

sealed class AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEvent();
}

class AdaptyOnboardingsAnalyticsEventOnboardingStarted extends AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEventOnboardingStarted();
}

class AdaptyOnboardingsAnalyticsEventScreenPresented extends AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEventScreenPresented();
}

class AdaptyOnboardingsAnalyticsEventScreenCompleted extends AdaptyOnboardingsAnalyticsEvent {
  final String? elementId;
  final String? reply;

  const AdaptyOnboardingsAnalyticsEventScreenCompleted({
    this.elementId,
    this.reply,
  });
}

class AdaptyOnboardingsAnalyticsEventSecondScreenPresented extends AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEventSecondScreenPresented();
}

class AdaptyOnboardingsAnalyticsEventRegistrationScreenPresented extends AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEventRegistrationScreenPresented();
}

class AdaptyOnboardingsAnalyticsEventProductsScreenPresented extends AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEventProductsScreenPresented();
}

class AdaptyOnboardingsAnalyticsEventUserEmailCollected extends AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEventUserEmailCollected();
}

class AdaptyOnboardingsAnalyticsEventOnboardingCompleted extends AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEventOnboardingCompleted();
}

class AdaptyOnboardingsAnalyticsEventUnknown extends AdaptyOnboardingsAnalyticsEvent {
  final String name;

  const AdaptyOnboardingsAnalyticsEventUnknown({
    required this.name,
  });
}

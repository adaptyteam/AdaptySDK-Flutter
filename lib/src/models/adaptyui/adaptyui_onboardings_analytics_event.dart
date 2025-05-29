import 'adaptyui_onboarding_meta.dart';

sealed class AdaptyOnboardingsAnalyticsEvent {
  final AdaptyUIOnboardingMeta meta;

  const AdaptyOnboardingsAnalyticsEvent({
    required this.meta,
  });
}

class AdaptyOnboardingsAnalyticsEventOnboardingStarted extends AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEventOnboardingStarted({
    required super.meta,
  });
}

class AdaptyOnboardingsAnalyticsEventScreenPresented extends AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEventScreenPresented({
    required super.meta,
  });
}

class AdaptyOnboardingsAnalyticsEventScreenCompleted extends AdaptyOnboardingsAnalyticsEvent {
  final String? elementId;
  final String? reply;

  const AdaptyOnboardingsAnalyticsEventScreenCompleted({
    required super.meta,
    this.elementId,
    this.reply,
  });
}

class AdaptyOnboardingsAnalyticsEventSecondScreenPresented extends AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEventSecondScreenPresented({
    required super.meta,
  });
}

class AdaptyOnboardingsAnalyticsEventRegistrationScreenPresented extends AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEventRegistrationScreenPresented({
    required super.meta,
  });
}

class AdaptyOnboardingsAnalyticsEventProductsScreenPresented extends AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEventProductsScreenPresented({
    required super.meta,
  });
}

class AdaptyOnboardingsAnalyticsEventUserEmailCollected extends AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEventUserEmailCollected({
    required super.meta,
  });
}

class AdaptyOnboardingsAnalyticsEventOnboardingCompleted extends AdaptyOnboardingsAnalyticsEvent {
  const AdaptyOnboardingsAnalyticsEventOnboardingCompleted({
    required super.meta,
  });
}

class AdaptyOnboardingsAnalyticsEventUnknown extends AdaptyOnboardingsAnalyticsEvent {
  final String name;

  const AdaptyOnboardingsAnalyticsEventUnknown({
    required super.meta,
    required this.name,
  });
}

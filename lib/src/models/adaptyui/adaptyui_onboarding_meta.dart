import 'package:meta/meta.dart' show immutable;

part '../private/adaptyui_onboarding_meta_json_builder.dart';

@immutable
class AdaptyUIOnboardingMeta {
  final String onboardingId;
  final String screenClientId;
  final int screenIndex;
  final int screensTotal;

  const AdaptyUIOnboardingMeta({
    required this.onboardingId,
    required this.screenClientId,
    required this.screenIndex,
    required this.screensTotal,
  });

  @override
  String toString() {
    return 'AdaptyUIOnboardingMeta(onboardingId: $onboardingId, screenClientId: $screenClientId, screenIndex: $screenIndex, screensTotal: $screensTotal)';
  }
}

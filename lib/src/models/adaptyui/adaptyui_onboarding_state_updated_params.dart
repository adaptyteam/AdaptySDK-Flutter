import 'adaptyui_onboardings_input.dart';

sealed class AdaptyOnboardingsStateUpdatedParams {
  const AdaptyOnboardingsStateUpdatedParams();
}

class AdaptyOnboardingsSelectParams extends AdaptyOnboardingsStateUpdatedParams {
  final String id;
  final String value;
  final String label;

  const AdaptyOnboardingsSelectParams({
    required this.id,
    required this.value,
    required this.label,
  });
}

class AdaptyOnboardingsMultiSelectParams extends AdaptyOnboardingsStateUpdatedParams {
  final List<AdaptyOnboardingsSelectParams> params;

  const AdaptyOnboardingsMultiSelectParams({
    required this.params,
  });
}

class AdaptyOnboardingsInputParams extends AdaptyOnboardingsStateUpdatedParams {
  final AdaptyOnboardingsInput input;

  const AdaptyOnboardingsInputParams({
    required this.input,
  });
}

class AdaptyOnboardingsDatePickerParams extends AdaptyOnboardingsStateUpdatedParams {
  final int? day;
  final int? month;
  final int? year;

  const AdaptyOnboardingsDatePickerParams({
    this.day,
    this.month,
    this.year,
  });
}

import 'adaptyui_onboardings_input.dart';

part '../private/adaptyui_onboardings_state_updated_params_json_builder.dart';

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

  @override
  String toString() {
    return 'AdaptyOnboardingsSelectParams(id: $id, value: $value, label: $label)';
  }
}

class AdaptyOnboardingsMultiSelectParams extends AdaptyOnboardingsStateUpdatedParams {
  final List<AdaptyOnboardingsSelectParams> params;

  const AdaptyOnboardingsMultiSelectParams({
    required this.params,
  });

  @override
  String toString() {
    return 'AdaptyOnboardingsMultiSelectParams(params: $params)';
  }
}

class AdaptyOnboardingsInputParams extends AdaptyOnboardingsStateUpdatedParams {
  final AdaptyOnboardingsInput input;

  const AdaptyOnboardingsInputParams({
    required this.input,
  });

  @override
  String toString() {
    return 'AdaptyOnboardingsInputParams(input: $input)';
  }
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

  @override
  String toString() {
    return 'AdaptyOnboardingsDatePickerParams(day: $day, month: $month, year: $year)';
  }
}

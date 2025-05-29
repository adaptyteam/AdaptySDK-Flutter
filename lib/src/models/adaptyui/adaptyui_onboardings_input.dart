sealed class AdaptyOnboardingsInput {
  const AdaptyOnboardingsInput();
}

class AdaptyOnboardingsTextInput extends AdaptyOnboardingsInput {
  final String value;

  const AdaptyOnboardingsTextInput({
    required this.value,
  });
}

class AdaptyOnboardingsEmailInput extends AdaptyOnboardingsInput {
  final String value;

  const AdaptyOnboardingsEmailInput({
    required this.value,
  });
}

class AdaptyOnboardingsNumberInput extends AdaptyOnboardingsInput {
  final double value;

  const AdaptyOnboardingsNumberInput({
    required this.value,
  });
}

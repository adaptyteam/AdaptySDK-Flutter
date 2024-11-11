part of '../adapty_locale.dart';

extension AdaptyLocaleJSONBuilder on AdaptyLocale {
  dynamic get jsonValue => {
        _Keys.id: id,
      };

  static AdaptyLocale fromJsonValue(Map<String, dynamic> json) {
    return AdaptyLocale._(json.string(_Keys.id));
  }
}

class _Keys {
  static const id = 'id';
}

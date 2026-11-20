part of '../adaptyui/adaptyui_localization_strategy.dart';

extension AdaptyUILocalizationStrategyJSONBuilder on AdaptyUILocalizationStrategy {
  /// [customId] is the id the host resolver of this strategy is registered under, if any.
  Map<String, dynamic> jsonValue({String? customId}) => {
        _Keys.resolver: resolver.name,
        if (customId != null) _Keys.customId: customId,
      };
}

class _Keys {
  static const resolver = 'resolver';
  static const customId = 'custom_id';
}

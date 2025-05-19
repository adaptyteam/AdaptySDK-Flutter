import 'package:flutter/material.dart';

extension on Gradient {
  List<Map<String, dynamic>> get stopsWithColorsMap {
    if (stops != null && stops!.length != colors.length) {
      throw ArgumentError('Stops and colors arrays must have the same length');
    }

    return stops
            ?.asMap()
            .entries
            .map((e) => {
                  'color': colors[e.key].value,
                  'location': e.value,
                })
            .toList() ??
        [];
  }
}

sealed class AdaptyGradient {
  const AdaptyGradient();

  const factory AdaptyGradient.linear({
    required LinearGradient gradient,
  }) = AdaptyGradientLinear;

  Map<String, dynamic> get jsonValue;
}

final class AdaptyGradientLinear extends AdaptyGradient {
  final LinearGradient gradient;

  const AdaptyGradientLinear({
    required this.gradient,
  });

  @override
  Map<String, dynamic> get jsonValue {
    final begin = gradient.begin as Alignment;
    final end = gradient.end as Alignment;

    return {
      'type': 'linear',
      'start': {'x': begin.x, 'y': begin.y},
      'end': {'x': end.x, 'y': end.y},
      'stops': gradient.stopsWithColorsMap,
    };
  }
}

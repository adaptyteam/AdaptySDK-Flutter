part of 'adaptyui_custom_assets.dart';

extension on Gradient {
  List<Map<String, dynamic>> get stopsWithColorsMap {
    if (stops != null && stops!.length != colors.length) {
      throw ArgumentError('Stops and colors arrays must have the same length');
    }

    return stops
            ?.asMap()
            .entries
            .map((e) => {
                  'color': colors[e.key].stringHexValue,
                  'p': e.value,
                })
            .toList() ??
        [];
  }
}

final class AdaptyCustomAssetLinearGradient extends AdaptyCustomAsset {
  final LinearGradient gradient;

  const AdaptyCustomAssetLinearGradient({
    required this.gradient,
  });

  @override
  Map<String, dynamic> get jsonValue {
    final begin = gradient.begin as Alignment;
    final end = gradient.end as Alignment;

    return {
      'type': 'linear-gradient',
      'values': gradient.stopsWithColorsMap,
      'points': {
        'x0': begin.x,
        'y0': begin.y,
        'x1': end.x,
        'y1': end.y,
      },
    };
  }
}

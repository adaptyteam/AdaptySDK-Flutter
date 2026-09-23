part of 'adaptyui_custom_assets.dart';

extension on Gradient {
  /// `stops` is optional in Flutter's gradients: when it is omitted the colors
  /// are distributed evenly. Mirror that here instead of dropping every color,
  /// otherwise the idiomatic `LinearGradient(colors: [a, b])` would be sent
  /// over the channel with an empty `values` array.
  List<double> get _impliedStops {
    final stops = this.stops;
    if (stops != null) return stops;
    if (colors.length == 1) return const [0.0];

    final separation = 1.0 / (colors.length - 1);
    return List<double>.generate(colors.length, (index) => index * separation);
  }

  List<Map<String, dynamic>> get stopsWithColorsMap {
    final stops = this.stops;
    if (stops != null && stops.length != colors.length) {
      throw ArgumentError('Stops and colors arrays must have the same length');
    }
    if (stops != null && !stops.every((stop) => stop.isFinite)) {
      throw ArgumentError('Stops must contain only finite numbers, got $stops');
    }

    return _impliedStops
        .asMap()
        .entries
        .map((e) => {
              'color': colors[e.key].stringHexValue,
              'p': e.value,
            })
        .toList();
  }
}

final class AdaptyCustomAssetLinearGradient extends AdaptyCustomAsset {
  final LinearGradient gradient;

  const AdaptyCustomAssetLinearGradient({
    required this.gradient,
  });

  /// Ignored settings already warned about, e.g. `tileMode: TileMode.mirror`.
  /// Keyed by the setting rather than by the gradient: the embedded view
  /// serializes its creation params on every build, often from a gradient
  /// created in `build()`.
  static final _warnedIgnoredSettings = <String>{};

  @override
  Map<String, dynamic> get jsonValue {
    // The flow's layout direction is decided natively, after the assets are
    // sent, so directional alignments are resolved left-to-right. A plain
    // `Alignment` resolves to itself.
    final begin = gradient.begin.resolve(TextDirection.ltr);
    final end = gradient.end.resolve(TextDirection.ltr);
    final values = gradient.stopsWithColorsMap;

    _checkFinite('begin', gradient.begin, begin);
    _checkFinite('end', gradient.end, end);
    _warnAboutIgnoredSettings();

    // The native side expects points as fractions of the element (0…1), while
    // `Alignment` spans −1…1, so each coordinate is rescaled with (v + 1) / 2.
    return {
      'type': 'linear-gradient',
      'values': values,
      'points': {
        'x0': (begin.x + 1) / 2,
        'y0': (begin.y + 1) / 2,
        'x1': (end.x + 1) / 2,
        'y1': (end.y + 1) / 2,
      },
    };
  }

  static void _checkFinite(String name, AlignmentGeometry value, Alignment resolved) {
    if (!resolved.x.isFinite || !resolved.y.isFinite) {
      throw ArgumentError('The $name alignment must have finite coordinates, got $value');
    }
  }

  // Custom gradients are drawn clamped and untransformed on both platforms,
  // and the payload has no field for either setting.
  void _warnAboutIgnoredSettings() {
    final transform = gradient.transform;
    final ignoredSettings = [
      if (transform != null) 'transform: ${transform.runtimeType}',
      if (gradient.tileMode != TileMode.clamp) 'tileMode: ${gradient.tileMode}',
    ];

    for (final setting in ignoredSettings) {
      if (_warnedIgnoredSettings.add(setting)) {
        AdaptyLogger.write(
          AdaptyLogLevel.warn,
          'AdaptyCustomAsset.linearGradient($setting): flows do not support this setting, so it is ignored.',
        );
      }
    }
  }
}

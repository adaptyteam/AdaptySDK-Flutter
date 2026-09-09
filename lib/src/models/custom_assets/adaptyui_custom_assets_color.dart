part of 'adaptyui_custom_assets.dart';

extension on Color {
  /// Converts Flutter's ARGB value to the RGBA wire format expected by AdaptyUI.
  String get stringHexValue {
    final argb = toARGB32();
    final rgba = ((argb & 0x00FFFFFF) << 8) | ((argb >> 24) & 0xFF);

    return '#${rgba.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }
}

final class AdaptyCustomAssetColor extends AdaptyCustomAsset {
  final Color color;

  const AdaptyCustomAssetColor({
    required this.color,
  });

  @override
  Map<String, dynamic> get jsonValue {
    return {
      'type': 'color',
      'value': color.stringHexValue,
    };
  }
}

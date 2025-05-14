import 'dart:typed_data' show Uint8List;
import 'dart:convert' show base64Encode;

sealed class AdaptyLocalImageAsset {
  const AdaptyLocalImageAsset();

  const factory AdaptyLocalImageAsset.asset({
    required String assetId,
  }) = AdaptyIdImageAsset;

  const factory AdaptyLocalImageAsset.data({
    required Uint8List data,
  }) = AdaptyDataImageAsset;

  Map<String, dynamic> get jsonValue;
}

final class AdaptyIdImageAsset extends AdaptyLocalImageAsset {
  final String assetId;

  const AdaptyIdImageAsset({
    required this.assetId,
  });

  @override
  Map<String, dynamic> get jsonValue {
    return {
      'type': 'asset',
      'id': assetId,
    };
  }
}

final class AdaptyDataImageAsset extends AdaptyLocalImageAsset {
  final Uint8List data;

  const AdaptyDataImageAsset({
    required this.data,
  });

  @override
  Map<String, dynamic> get jsonValue {
    return {
      'type': 'data',
      'data': base64Encode(data),
    };
  }
}

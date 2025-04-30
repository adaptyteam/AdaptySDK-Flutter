import 'dart:typed_data' show Uint8List;
import 'dart:convert' show base64Encode;

sealed class AdaptyLocalAsset {
  const AdaptyLocalAsset();

  const factory AdaptyLocalAsset.asset({
    required String path,
  }) = AdaptyPathAsset;

  const factory AdaptyLocalAsset.data({
    required Uint8List data,
  }) = AdaptyDataAsset;

  Map<String, dynamic> get jsonValue;
}

final class AdaptyPathAsset extends AdaptyLocalAsset {
  final String path;

  const AdaptyPathAsset({
    required this.path,
  });

  @override
  Map<String, dynamic> get jsonValue {
    return {
      'type': 'asset',
      'path': path,
    };
  }
}

final class AdaptyDataAsset extends AdaptyLocalAsset {
  final Uint8List data;

  const AdaptyDataAsset({
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

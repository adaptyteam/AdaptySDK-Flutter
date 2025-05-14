import 'package:flutter/material.dart';
import 'adaptyui_gradient.dart';
import 'adaptyui_local_asset.dart';

sealed class AdaptyCustomAsset {
  const AdaptyCustomAsset();

  const factory AdaptyCustomAsset.localImage({
    required AdaptyLocalImageAsset asset,
  }) = AdaptyCustomAssetLocalImage;

  const factory AdaptyCustomAsset.remoteImage({
    required String url,
    AdaptyLocalImageAsset? preview,
  }) = AdaptyCustomAssetRemoteImage;

  const factory AdaptyCustomAsset.localVideo({
    required String assetId,
  }) = AdaptyCustomAssetLocalVideo;

  const factory AdaptyCustomAsset.remoteVideo({
    required String url,
    AdaptyLocalImageAsset? preview,
  }) = AdaptyCustomAssetRemoteVideo;

  const factory AdaptyCustomAsset.color({
    required Color color,
  }) = AdaptyCustomAssetColor;

  const factory AdaptyCustomAsset.gradient({
    required AdaptyGradient gradient,
  }) = AdaptyCustomAssetGradient;

  Map<String, dynamic> get jsonValue;
}

final class AdaptyCustomAssetLocalImage extends AdaptyCustomAsset {
  final AdaptyLocalImageAsset asset;

  const AdaptyCustomAssetLocalImage({
    required this.asset,
  });

  @override
  Map<String, dynamic> get jsonValue {
    return {
      'type': 'image_local',
      'value': asset.jsonValue,
    };
  }
}

final class AdaptyCustomAssetRemoteImage extends AdaptyCustomAsset {
  final String url;
  final AdaptyLocalImageAsset? preview;

  const AdaptyCustomAssetRemoteImage({
    required this.url,
    this.preview,
  });

  @override
  Map<String, dynamic> get jsonValue {
    return {
      'type': 'image_remote',
      'url': url,
      if (preview != null) 'preview': preview!.jsonValue,
    };
  }
}

final class AdaptyCustomAssetLocalVideo extends AdaptyCustomAsset {
  final String assetId;

  const AdaptyCustomAssetLocalVideo({
    required this.assetId,
  });

  @override
  Map<String, dynamic> get jsonValue {
    return {
      'type': 'video_local',
      'asset_id': assetId,
    };
  }
}

final class AdaptyCustomAssetRemoteVideo extends AdaptyCustomAsset {
  final String url;
  final AdaptyLocalImageAsset? preview;

  const AdaptyCustomAssetRemoteVideo({
    required this.url,
    this.preview,
  });

  @override
  Map<String, dynamic> get jsonValue {
    return {
      'type': 'video_remote',
      'url': url,
      if (preview != null) 'preview': preview!.jsonValue,
    };
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
      'value': color.value, // a, r, g, b
    };
  }
}

final class AdaptyCustomAssetGradient extends AdaptyCustomAsset {
  final AdaptyGradient gradient;

  const AdaptyCustomAssetGradient({
    required this.gradient,
  });

  @override
  Map<String, dynamic> get jsonValue {
    return {
      'type': 'gradient',
      'value': gradient.jsonValue,
    };
  }
}

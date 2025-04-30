import 'package:flutter/material.dart';
import 'adaptyui_gradient.dart';
import 'adaptyui_local_asset.dart';

sealed class AdaptyCustomAsset {
  const AdaptyCustomAsset();

  const factory AdaptyCustomAsset.localImage({
    required AdaptyLocalAsset asset,
  }) = AdaptyCustomAssetLocalImage;

  const factory AdaptyCustomAsset.remoteImage({
    required String url,
    AdaptyLocalAsset? preview,
  }) = AdaptyCustomAssetRemoteImage;

  const factory AdaptyCustomAsset.localVideo({
    required AdaptyLocalAsset asset,
  }) = AdaptyCustomAssetLocalVideo;

  const factory AdaptyCustomAsset.remoteVideo({
    required String url,
    AdaptyLocalAsset? preview,
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
  final AdaptyLocalAsset asset;

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
  final AdaptyLocalAsset? preview;

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
  final AdaptyLocalAsset asset;
  final AdaptyLocalAsset? preview;

  const AdaptyCustomAssetLocalVideo({
    required this.asset,
    this.preview,
  });

  @override
  Map<String, dynamic> get jsonValue {
    return {
      'type': 'video_local',
      'value': asset.jsonValue,
      if (preview != null) 'preview': preview!.jsonValue,
    };
  }
}

final class AdaptyCustomAssetRemoteVideo extends AdaptyCustomAsset {
  final String url;
  final AdaptyLocalAsset? preview;

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

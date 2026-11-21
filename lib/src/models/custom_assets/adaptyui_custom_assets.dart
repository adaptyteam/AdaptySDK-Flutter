import 'package:flutter/painting.dart';
import 'dart:typed_data' show Uint8List;
import 'dart:convert' show base64Encode;

import '../../adapty_logger.dart';
import '../../runtime/adapty_runtime.dart';
import '../adapty_log_level.dart' show AdaptyLogLevel;

part 'adaptyui_custom_assets_image.dart';
part 'adaptyui_custom_assets_video.dart';
part 'adaptyui_custom_assets_color.dart';
part 'adaptyui_custom_assets_gradient.dart';

sealed class AdaptyCustomAsset {
  const AdaptyCustomAsset();

  const factory AdaptyCustomAsset.localImageData({
    required Uint8List data,
  }) = AdaptyCustomAssetLocalImageData;

  const factory AdaptyCustomAsset.localImageAsset({
    required String assetId,
  }) = AdaptyCustomAssetLocalImageAsset;

  const factory AdaptyCustomAsset.localImageFile({
    required String path,
  }) = AdaptyCustomAssetLocalImageFile;

  const factory AdaptyCustomAsset.localVideoAsset({
    required String assetId,
  }) = AdaptyCustomAssetLocalVideoAsset;

  const factory AdaptyCustomAsset.localVideoFile({
    required String path,
  }) = AdaptyCustomAssetLocalVideoFile;

  const factory AdaptyCustomAsset.color({
    required Color color,
  }) = AdaptyCustomAssetColor;

  /// A linear gradient: the flow gets its [LinearGradient.colors], [LinearGradient.stops],
  /// [LinearGradient.begin] and [LinearGradient.end], with directional alignments resolved
  /// left-to-right. It is not mirrored in a right-to-left flow: resolve the alignments for
  /// right-to-left yourself if needed. [LinearGradient.transform] and a [LinearGradient.tileMode]
  /// other than [TileMode.clamp] are ignored with a warning.
  ///
  /// [LinearGradient.stops], if given, must match [LinearGradient.colors] in length, and every
  /// stop and coordinate must be finite; otherwise `AdaptyUI.createFlowView` fails with
  /// `AdaptyErrorCode.wrongParam` and `AdaptyUIFlowPlatformView` throws an [ArgumentError].
  const factory AdaptyCustomAsset.linearGradient({
    required LinearGradient gradient,
  }) = AdaptyCustomAssetLinearGradient;

  Map<String, dynamic> get jsonValue;
}

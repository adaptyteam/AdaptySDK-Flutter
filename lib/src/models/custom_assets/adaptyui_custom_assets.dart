import 'package:flutter/material.dart';
import 'dart:typed_data' show Uint8List;
import 'dart:convert' show base64Encode;

import '../../adapty_logger.dart';
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

  /// A linear gradient. The flow receives its [LinearGradient.colors], [LinearGradient.stops],
  /// [LinearGradient.begin] and [LinearGradient.end].
  ///
  /// [AlignmentDirectional] values, and alignments that combine [Alignment] with [AlignmentDirectional]
  /// (for example the result of [AlignmentGeometry.add]), are resolved left-to-right whatever the ambient
  /// [Directionality], so `start` is the left edge.
  ///
  /// The gradient is not mirrored when the flow is shown in a right-to-left localization. On both iOS and
  /// Android the flow lays out its text and controls right-to-left but draws the gradient exactly as in a
  /// left-to-right flow, whether [LinearGradient.begin] and [LinearGradient.end] are [Alignment] or
  /// [AlignmentDirectional] values. To mirror it yourself, resolve the alignments for right-to-left before
  /// passing them, for example `AlignmentDirectional.centerStart.resolve(TextDirection.rtl)`.
  ///
  /// [LinearGradient.transform], and any [LinearGradient.tileMode] other than [TileMode.clamp], are not
  /// supported: they are ignored and a warning is logged.
  ///
  /// [LinearGradient.stops], when given, must have as many entries as [LinearGradient.colors], and every
  /// stop and alignment coordinate must be finite. Otherwise `AdaptyUI.createFlowView` fails with an
  /// `AdaptyError` with code `AdaptyErrorCode.wrongParam`, and `AdaptyUIFlowPlatformView` throws an
  /// [ArgumentError] when it builds.
  const factory AdaptyCustomAsset.linearGradient({
    required LinearGradient gradient,
  }) = AdaptyCustomAssetLinearGradient;

  Map<String, dynamic> get jsonValue;
}

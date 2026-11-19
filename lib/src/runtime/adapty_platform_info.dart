import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../models/adapty_sdk_native.dart';

/// Which native view an embedded Adapty view is drawn with.
enum AdaptyPlatformViewKind { uiKit, android, none }

/// What a runtime knows about the platform it runs on.
abstract interface class AdaptyPlatformInfo {
  /// Whether the iOS side of the native protocol applies.
  bool get isIOS;

  /// Whether the Android side of the native protocol applies.
  bool get isAndroid;

  /// The native view an embedded Adapty view is drawn with.
  AdaptyPlatformViewKind get viewKind;

  /// The letter after `AdaptyFlutter` in a log line.
  String get logTag;
}

/// The platform of the host the app runs on.
///
/// The protocol branches follow [AdaptySDKNative.debugPlatformOverride] in debug builds; the kind of platform view
/// and the log letter follow the real host only. Nothing here may log: the logger reads the platform of the current
/// runtime, which may be the production runtime being created.
final class HostPlatformInfo implements AdaptyPlatformInfo {
  const HostPlatformInfo();

  @override
  bool get isIOS {
    final override = AdaptySDKNative.platformOverride;
    if (override != null) return override == TargetPlatform.iOS || override == TargetPlatform.macOS;
    return !kIsWeb && (Platform.isIOS || Platform.isMacOS);
  }

  @override
  bool get isAndroid {
    final override = AdaptySDKNative.platformOverride;
    if (override != null) return override == TargetPlatform.android;
    return !kIsWeb && Platform.isAndroid;
  }

  @override
  AdaptyPlatformViewKind get viewKind {
    if (Platform.isIOS) return AdaptyPlatformViewKind.uiKit;
    if (Platform.isAndroid) return AdaptyPlatformViewKind.android;
    return AdaptyPlatformViewKind.none;
  }

  @override
  String get logTag => Platform.isAndroid ? 'a' : 'i';
}

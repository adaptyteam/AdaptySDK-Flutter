//
//  adapty_error.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class AdaptySDKNative {
  /// Makes [isAndroid] and [isIOS] report this platform instead of the host's. For tests only.
  ///
  /// A test cannot change the host's `Platform`, and [isIOS] is true on a macOS host. Set this
  /// to run the code path of the platform under test, and reset it to `null` in `tearDown`.
  /// Like Flutter's `debugDefaultTargetPlatformOverride`, it is honoured only in debug builds.
  @visibleForTesting
  static TargetPlatform? debugPlatformOverride;

  static bool get isAndroid {
    final override = _platformOverride;
    if (override != null) return override == TargetPlatform.android;
    return !kIsWeb && Platform.isAndroid;
  }

  static bool get isIOS {
    final override = _platformOverride;
    if (override != null) return override == TargetPlatform.iOS || override == TargetPlatform.macOS;
    return !kIsWeb && (Platform.isIOS || Platform.isMacOS);
  }

  static TargetPlatform? get _platformOverride => kDebugMode ? debugPlatformOverride : null;
}

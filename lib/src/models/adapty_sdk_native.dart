//
//  adapty_error.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:flutter/foundation.dart';

import '../runtime/adapty_runtime.dart';

class AdaptySDKNative {
  /// Makes [isAndroid] and [isIOS] report this platform instead of the host's. For tests only.
  ///
  /// A test cannot change the host's `Platform`, and [isIOS] is true on a macOS host. Set this
  /// to run the code path of the platform under test, and reset it to `null` in `tearDown`.
  /// Like Flutter's `debugDefaultTargetPlatformOverride`, it is honoured only in debug builds.
  @visibleForTesting
  static TargetPlatform? debugPlatformOverride;

  static bool get isAndroid => AdaptyRuntime.current.environment.platform.isAndroid;

  static bool get isIOS => AdaptyRuntime.current.environment.platform.isIOS;

  /// [debugPlatformOverride] in a debug build, null otherwise. The host platform reads it.
  @internal
  static TargetPlatform? get debugEffectivePlatformOverride => kDebugMode ? debugPlatformOverride : null;
}

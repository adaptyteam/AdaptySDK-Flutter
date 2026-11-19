import 'package:adapty_flutter/src/runtime/adapty_platform_info.dart';

/// A platform a test spells out in full, whatever the host is.
///
/// `AdaptySDKNative.debugPlatformOverride` has no effect on it: the override is read only by the host platform, so a
/// test that sets both gets the answers given here.
final class TestPlatformInfo implements AdaptyPlatformInfo {
  const TestPlatformInfo({required this.isIOS, required this.isAndroid, required this.viewKind, required this.logTag});

  @override
  final bool isIOS;

  @override
  final bool isAndroid;

  @override
  final AdaptyPlatformViewKind viewKind;

  @override
  final String logTag;
}

import 'package:adapty_flutter/src/runtime/adapty_platform_info.dart';

/// A platform a test spells out in full, whatever the host is.
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

import 'dart:io' show Platform;

class AdaptyUISDKNative {
  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS || Platform.isMacOS;
}

//
//  adapty_error.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'dart:io' show Platform;

class AdaptySDKNative {
  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS || Platform.isMacOS;
}

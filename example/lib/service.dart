import 'dart:io';

import 'package:adapty_flutter/adapty_flutter.dart';

import 'package:flutter_apns/flutter_apns.dart';

class Service {
  static final PushConnector? _connector = Platform.isIOS ? createPushConnector() : null;

  static Future<void> initializePushes() async {
    if (!Platform.isIOS) return;

    _connector!.configure(
      onLaunch: (message) => Adapty.handlePushNotification(message.data),
      onResume: (message) => Adapty.handlePushNotification(message.data),
      onMessage: (message) => Adapty.handlePushNotification(message.data),
      onBackgroundMessage: (message) => Adapty.handlePushNotification(message.data),
    );
    _connector!.token.addListener(() => Adapty.setApnsToken(_connector!.token.value!));
    _connector!.requestNotificationPermissions();

    if (_connector is ApnsPushConnector) {
      final apnsConnector = _connector as ApnsPushConnector;
      apnsConnector.shouldPresent = (x) => Future.value(true);
    }
  }

  static Future<String> getOrCreateInstallId() async {
    return Future.value('your-install-id');
  }
}

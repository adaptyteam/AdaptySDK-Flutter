import 'package:adapty_flutter/adapty_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_apns/flutter_apns.dart';
import 'package:uuid/uuid.dart';

class Service {
  static final PushConnector _connector = createPushConnector();

  static Future<void> initializePushes() async {
    // _connector.configure(
    //   onLaunch: (message ){Adapty.handlePushNotification(messag.)},
    //   onResume: Adapty.handlePushNotification,
    //   onMessage: Adapty.handlePushNotification,
    //   onBackgroundMessage: Adapty.handlePushNotification,
    // );
    _connector.token.addListener(() => Adapty.setApnsToken(_connector.token.value!));
    _connector.requestNotificationPermissions();

    if (_connector is ApnsPushConnector) {
      final apnsConnector = _connector as ApnsPushConnector;
      apnsConnector.shouldPresent = (x) => Future.value(true);
    }
  }

  static Future<String> getOrCreateInstallId() async {
    final prefs = await SharedPreferences.getInstance();
    String installId;
    if (prefs.containsKey('install_id')) {
      installId = prefs.getString('install_id')!;
    } else {
      installId = Uuid().v4();
      prefs.setString('install_id', installId);
    }

    return installId;
  }
}

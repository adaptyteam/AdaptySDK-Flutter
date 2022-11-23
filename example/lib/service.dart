import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class Service {
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

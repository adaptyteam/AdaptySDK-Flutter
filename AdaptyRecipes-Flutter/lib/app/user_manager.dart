import 'package:shared_preferences/shared_preferences.dart';

class UserManager {
  static const _userIdKey = 'app.user.id';

  Future<String?> currentUserId() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_userIdKey);
  }

  Future<void> login(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_userIdKey, userId);
  }

  Future<void> logout() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_userIdKey);
  }
}

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

class AuthGuard {
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.isLoggedInKey) ?? false;
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.accessTokenKey);
  }
}
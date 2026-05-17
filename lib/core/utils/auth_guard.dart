import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../services/auth_session_store.dart';

class AuthGuard {
  static Future<bool> isLoggedIn() async {
    final session = await AuthSessionStore.restore();
    if (session != null && session.accessToken.isNotEmpty) return true;

    final prefs = await SharedPreferences.getInstance();
    final hasToken = prefs.getString(AppConstants.accessTokenKey) != null;
    final loggedInFlag = prefs.getBool(AppConstants.isLoggedInKey) ?? false;
    return hasToken || loggedInFlag;
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.accessTokenKey);
  }
}

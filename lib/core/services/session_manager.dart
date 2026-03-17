import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'push_notification_service.dart';

class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  DateTime? _lastActiveTime;
  static const Duration _sessionTimeout = Duration(minutes: 30);

  Future<void> initializeSession() async {
    _lastActiveTime = DateTime.now();
  }

  Future<void> updateSessionActivity() async {
    _lastActiveTime = DateTime.now();
  }

  Future<bool> isSessionValid() async {
    if (_lastActiveTime == null) {
      return false;
    }

    final elapsed = DateTime.now().difference(_lastActiveTime!);
    return elapsed < _sessionTimeout;
  }

  Future<void> checkAndHandleSessionExpiration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(AppConstants.accessTokenKey);

      if (accessToken == null) {
        return;
      }

      final isValid = await isSessionValid();
      if (!isValid) {
        // Session has expired
        debugPrint('Session expired due to inactivity');
        
        // Show session expiration notification
        try {
          final pushService = PushNotificationService();
          await pushService.showSessionExpiredNotification();
        } catch (e) {
          debugPrint('Failed to show session expiration notification: $e');
        }

        // Clear the session data
        await prefs.remove(AppConstants.accessTokenKey);
        await prefs.remove(AppConstants.refreshTokenKey);
        await prefs.remove(AppConstants.userDataKey);
        await prefs.setBool(AppConstants.isLoggedInKey, false);
      }
    } catch (e) {
      debugPrint('Error checking session: $e');
    }
  }
}

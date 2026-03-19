import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'push_notification_service.dart';

/// SessionManager handles session lifecycle and expiration
/// This is separate from auth state restoration - that happens in SplashScreen
class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  DateTime? _lastActiveTime;
  static const Duration _sessionTimeout = Duration(minutes: 30);

  /// Initialize session tracking (called on app startup)
  Future<void> initializeSession() async {
    _lastActiveTime = DateTime.now();
    debugPrint('Session tracking initialized');
  }

  /// Update the last activity time (called when app comes to foreground)
  Future<void> updateSessionActivity() async {
    _lastActiveTime = DateTime.now();
    debugPrint('Session activity updated: $_lastActiveTime');
  }

  /// Check if the current session is still valid based on timeout
  Future<bool> isSessionValid() async {
    if (_lastActiveTime == null) {
      return false;
    }

    final elapsed = DateTime.now().difference(_lastActiveTime!);
    final isValid = elapsed < _sessionTimeout;
    
    if (!isValid) {
      debugPrint('Session expired after $elapsed (timeout: $_sessionTimeout)');
    }
    
    return isValid;
  }

  /// Check if session has expired and handle accordingly
  Future<void> checkAndHandleSessionExpiration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(AppConstants.accessTokenKey);

      if (accessToken == null) {
        // No session to validate
        return;
      }

      final isValid = await isSessionValid();
      if (!isValid) {
        // Session has expired due to inactivity
        debugPrint('Session expired - clearing session data');
        
        // Show session expiration notification
        try {
          final pushService = PushNotificationService();
          await pushService.showSessionExpiredNotification();
        } catch (e) {
          debugPrint('Failed to show session expiration notification: $e');
        }

        // Clear the session data
        await _clearSessionData(prefs);
      }
    } catch (e) {
      debugPrint('Error checking session: $e');
    }
  }

  /// Clear all session data from local storage
  Future<void> _clearSessionData(SharedPreferences prefs) async {
    try {
      await prefs.remove(AppConstants.accessTokenKey);
      await prefs.remove(AppConstants.refreshTokenKey);
      await prefs.remove(AppConstants.userDataKey);
      await prefs.setBool(AppConstants.isLoggedInKey, false);
      debugPrint('Session data cleared from storage');
    } catch (e) {
      debugPrint('Error clearing session data: $e');
    }
  }

  /// Get the time remaining before session expires (or null if expired)
  Duration? getTimeUntilExpiration() {
    if (_lastActiveTime == null) return null;

    final elapsed = DateTime.now().difference(_lastActiveTime!);
    final remaining = _sessionTimeout - elapsed;
    
    if (remaining.isNegative) return null;
    return remaining;
  }
}

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

  DateTime? _sessionStartTime;
  
  // Maximum session duration: 30 days from login (for long-lasting sessions)
  static const Duration _maxSessionDuration = Duration(days: 30);
  
  // Storage keys for session metadata
  static const String _sessionStartTimeKey = 'session_start_time';

  /// Initialize session tracking (called on app startup)
  Future<void> initializeSession() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Try to restore session start time from storage
    final storedStartTime = prefs.getString(_sessionStartTimeKey);
    
    if (storedStartTime != null) {
      try {
        _sessionStartTime = DateTime.parse(storedStartTime);
      } catch (e) {
        debugPrint('Error parsing stored session start time: $e');
      }
    }
    
    // If no session start time, use now
    _sessionStartTime ??= DateTime.now();
    
    // Persist session start time
    await prefs.setString(_sessionStartTimeKey, _sessionStartTime!.toIso8601String());
    
    debugPrint('Session tracking initialized - Start: $_sessionStartTime');
  }

  /// Update the last activity time (called when app comes to foreground)
  Future<void> updateSessionActivity() async {
    debugPrint('Session activity updated - session remains active');
  }

  /// Check if the current session is still valid based on max duration
  /// Returns true if session should remain active
  Future<bool> isSessionValid() async {
    final accessToken = (await SharedPreferences.getInstance())
        .getString(AppConstants.accessTokenKey);
    
    if (accessToken == null) {
      debugPrint('No access token found - session invalid');
      return false;
    }

    if (_sessionStartTime == null) {
      debugPrint('Session start time not initialized - session invalid');
      return false;
    }

    // Check maximum session duration only
    final totalElapsed = DateTime.now().difference(_sessionStartTime!);
    if (totalElapsed > _maxSessionDuration) {
      debugPrint('Session expired due to max duration after $totalElapsed');
      return false;
    }

    return true;
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
        // Session has expired
        final totalElapsed = _sessionStartTime != null
            ? DateTime.now().difference(_sessionStartTime!)
            : null;
            
        debugPrint('Session expired due to 30-day limit - Total duration: $totalElapsed');
        
        // Show session expiration notification (optional)
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
  Future<void> clearSessionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.accessTokenKey);
      await prefs.remove(AppConstants.refreshTokenKey);
      await prefs.remove(AppConstants.userDataKey);
      await prefs.remove(_sessionStartTimeKey);
      await prefs.setBool(AppConstants.isLoggedInKey, false);
      
      _sessionStartTime = null;
      
      debugPrint('Session data cleared from storage');
    } catch (e) {
      debugPrint('Error clearing session data: $e');
    }
  }

  /// Clear all session data from local storage (kept for backward compatibility)
  Future<void> _clearSessionData(SharedPreferences prefs) async {
    try {
      await prefs.remove(AppConstants.accessTokenKey);
      await prefs.remove(AppConstants.refreshTokenKey);
      await prefs.remove(AppConstants.userDataKey);
      await prefs.remove(_sessionStartTimeKey);
      await prefs.setBool(AppConstants.isLoggedInKey, false);
      
      _sessionStartTime = null;
      
      debugPrint('Session data cleared from storage');
    } catch (e) {
      debugPrint('Error clearing session data: $e');
    }
  }

  /// Get the time remaining before session expires due to max duration
  Duration? getTimeUntilMaxDurationExpiration() {
    if (_sessionStartTime == null) return null;

    final elapsed = DateTime.now().difference(_sessionStartTime!);
    final remaining = _maxSessionDuration - elapsed;
    
    if (remaining.isNegative) return null;
    return remaining;
  }

  /// Reset session (called after successful login)
  Future<void> resetSession() async {
    _sessionStartTime = DateTime.now();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionStartTimeKey, _sessionStartTime!.toIso8601String());
      debugPrint('Session reset after login');
    } catch (e) {
      debugPrint('Error resetting session: $e');
    }
  }
}

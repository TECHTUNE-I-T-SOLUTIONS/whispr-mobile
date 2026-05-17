import 'package:flutter/foundation.dart';
import 'auth_session_store.dart';
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

  /// Initialize session tracking (called on app startup)
  Future<void> initializeSession() async {
    final stored = await AuthSessionStore.restore();
    _sessionStartTime = stored?.sessionStart ?? DateTime.now();

    if (stored != null) {
      await AuthSessionStore.save(
        accessToken: stored.accessToken,
        refreshToken: stored.refreshToken,
        user: stored.user,
        sessionStart: _sessionStartTime,
      );
    }
    
    debugPrint('Session tracking initialized - Start: $_sessionStartTime');
  }

  /// Update the last activity time (called when app comes to foreground)
  Future<void> updateSessionActivity() async {
    debugPrint('Session activity updated - session remains active');
  }

  /// Check if the current session is still valid based on max duration
  /// Returns true if session should remain active
  Future<bool> isSessionValid() async {
    final stored = await AuthSessionStore.restore();
    final accessToken = stored?.accessToken;
    
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
      final stored = await AuthSessionStore.restore();
      final accessToken = stored?.accessToken;

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
        await _clearSessionData();
      }
    } catch (e) {
      debugPrint('Error checking session: $e');
    }
  }

  /// Clear all session data from local storage
  Future<void> clearSessionData() async {
    try {
      await AuthSessionStore.clear();
      _sessionStartTime = null;
      
      debugPrint('Session data cleared from storage');
    } catch (e) {
      debugPrint('Error clearing session data: $e');
    }
  }

  /// Clear all session data from local storage (kept for backward compatibility)
  Future<void> _clearSessionData() async {
    try {
      await AuthSessionStore.clear();
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
      final stored = await AuthSessionStore.restore();
      if (stored != null) {
        await AuthSessionStore.save(
          accessToken: stored.accessToken,
          refreshToken: stored.refreshToken,
          user: stored.user,
          sessionStart: _sessionStartTime,
        );
      }
      debugPrint('Session reset after login');
    } catch (e) {
      debugPrint('Error resetting session: $e');
    }
  }
}

import 'package:flutter/foundation.dart';

import 'auth_session_store.dart';
import 'push_notification_service.dart';

/// SessionManager owns session lifecycle.
///
/// Whispr is a reading-and-writing app: a reader who opens it once a month must
/// not be signed out. So there is **no fixed session expiry** here. A session
/// ends when the user signs out, when the refresh token is rejected, or when
/// the stored bundle can no longer be decrypted. Everything else is silent
/// refresh, which is what "login stays saved" actually requires.
class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  DateTime? _sessionStartTime;

  /// Called on app start. Restores the session start marker used only for
  /// display/telemetry — it never expires the session.
  Future<void> initializeSession() async {
    final stored = await AuthSessionStore.restore();
    _sessionStartTime = stored?.sessionStart ?? stored?.savedAt;

    if (stored != null && stored.sessionStart == null) {
      // Stamp the start once, so "signed in since" survives restarts.
      await AuthSessionStore.save(
        accessToken: stored.accessToken,
        refreshToken: stored.refreshToken,
        user: stored.user,
        sessionStart: _sessionStartTime,
      );
    }

    debugPrint('[SessionManager] initialized, signed in since $_sessionStartTime');
  }

  /// Kept for call sites that ping on foreground; a session no longer lapses
  /// from inactivity, so this is a no-op by design.
  Future<void> updateSessionActivity() async {}

  /// A session is valid whenever a token is stored. Expiry is handled by
  /// [checkAndHandleSessionExpiration], which only acts on a rejected refresh.
  Future<bool> isSessionValid() async {
    final stored = await AuthSessionStore.restore();
    final token = stored?.accessToken;
    final valid = token != null && token.isNotEmpty;
    if (!valid) debugPrint('[SessionManager] no access token stored - session invalid');
    return valid;
  }

  /// Called on foreground resume.
  ///
  /// This deliberately does **not** sign the user out. It only clears local
  /// state when secure storage has genuinely lost the session (for example the
  /// user removed the device passcode and the Keystore entry was dropped).
  /// Network failures, expired access tokens and offline launches are all
  /// normal and must never end a session.
  Future<void> checkAndHandleSessionExpiration() async {
    try {
      final stored = await AuthSessionStore.restore();
      if (stored != null && stored.accessToken.isNotEmpty) return;

      debugPrint('[SessionManager] session could not be restored - clearing local state');
      await clearSessionData();
    } catch (e) {
      debugPrint('[SessionManager] error checking session: $e');
    }
  }

  /// Full sign-out. Only call this when the user taps Sign out or the server
  /// has explicitly rejected the refresh token.
  Future<void> clearSessionData() async {
    try {
      await AuthSessionStore.clear();
      _sessionStartTime = null;
      debugPrint('[SessionManager] session cleared');
    } catch (e) {
      debugPrint('[SessionManager] error clearing session: $e');
    }
  }

  /// Called after a successful sign-in to stamp the start time.
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
    } catch (e) {
      debugPrint('[SessionManager] error resetting session: $e');
    }
  }

  /// Surfaces a "signed in for N days" value for the profile screen.
  Duration? getSessionAge() {
    if (_sessionStartTime == null) return null;
    return DateTime.now().difference(_sessionStartTime!);
  }

  /// Shown when the server definitively ended the session.
  Future<void> notifySessionEnded() async {
    try {
      await PushNotificationService().showSessionExpiredNotification();
    } catch (e) {
      debugPrint('[SessionManager] failed to show session notification: $e');
    }
  }
}

import 'package:flutter/foundation.dart';

import 'auth_session_store.dart';
import 'push_notification_service.dart';

/// Display/session-start bookkeeping only.
///
/// The active session itself lives in [AuthSessionStore]. There is no fixed
/// expiry: a reader who opens the app once a month must not be signed out.
/// Only explicit logout ends a session.
class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  static SessionManager get instance => _instance;

  factory SessionManager() => _instance;
  SessionManager._internal();

  DateTime? _sessionStartTime;

  /// Adopts the session that bootstrap already restored. Never reads storage.
  Future<void> adoptRestoredSession(AuthSessionData? session) async {
    _sessionStartTime = session?.sessionStart ?? session?.savedAt;
    if (session != null && session.sessionStart == null) {
      await AuthSessionStore.ensureSessionStart(_sessionStartTime!);
    }
    debugPrint('[SessionManager] adopted, signed in since $_sessionStartTime');
  }

  /// Kept for call sites that ping on foreground; inactivity never expires a
  /// session, so this is intentionally a no-op.
  Future<void> updateSessionActivity() async {}

  Future<bool> isSessionValid() async {
    final token = AuthSessionStore.currentSession?.accessToken;
    final valid = token != null && token.isNotEmpty;
    if (!valid) {
      debugPrint('[SessionManager] no access token in the active session');
    }
    return valid;
  }

  /// On resume: never clears anything. Log-only for diagnostics.
  Future<void> checkAndHandleSessionExpiration() async {
    final token = AuthSessionStore.currentSession?.accessToken;
    debugPrint('[SessionManager] resume check: tokenPresent=${token != null && token.isNotEmpty}');
  }

  /// Resets only the display marker. The encrypted session is cleared once,
  /// from [AuthStateNotifier.logout].
  Future<void> clearSessionData() async {
    _sessionStartTime = null;
    debugPrint('[SessionManager] session marker reset');
  }

  /// Kept for compatibility; [AuthSessionStore.save] now stamps the start.
  Future<void> resetSession() async {
    await AuthSessionStore.ensureSessionStart(DateTime.now());
  }

  Duration? getSessionAge() {
    if (_sessionStartTime == null) return null;
    return DateTime.now().difference(_sessionStartTime!);
  }

  Future<void> notifySessionEnded() async {
    try {
      await PushNotificationService().showSessionExpiredNotification();
    } catch (e) {
      debugPrint('[SessionManager] failed to show session notification: $e');
    }
  }
}

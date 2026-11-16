import 'package:flutter/foundation.dart';

import '../services/auth_session_store.dart';

/// Gate for signed-in-only areas.
///
/// This is an in-memory flag, never a disk read. The old version hit
/// SharedPreferences on every navigation, which made every tap wait on I/O and
/// made the login screen flash before the session loaded. [AuthSessionStore]
/// reads storage once at startup; everything after that reads this flag.
class AuthGuard {
  AuthGuard._();

  static bool? _signedIn;

  /// True once a session has been read. Until then, routes must not redirect,
  /// or a returning user gets bounced to /login before restore finishes.
  static bool get isReady => _signedIn != null;

  static bool get isLoggedInNow => _signedIn ?? false;

  /// Called once by the auth notifier after restore, login, signup and logout.
  static void setSignedIn(bool value) => _signedIn = value;

  /// Kept for callers that need an authoritative check; reads secure storage.
  /// Use sparingly — prefer [isLoggedInNow] on the navigation path.
  static Future<bool> isLoggedIn() async {
    if (_signedIn != null) return _signedIn!;
    final session = await AuthSessionStore.restore();
    final signedIn = session != null && session.accessToken.isNotEmpty;
    _signedIn = signedIn;
    debugPrint('[AuthGuard] resolved session from storage: signedIn=$signedIn');
    return signedIn;
  }

  static Future<String?> getAccessToken() async {
    final session = await AuthSessionStore.restore();
    return session?.accessToken;
  }
}

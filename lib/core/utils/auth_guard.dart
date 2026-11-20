import 'package:flutter/foundation.dart';

import '../services/auth_session_store.dart';

/// Synchronous router mirror of the auth session.
///
/// [signedIn] is a [ValueNotifier] so `GoRouter.refreshListenable` can
/// re-evaluate redirects the moment login, logout or bootstrap changes the
/// session. Nothing here reads disk on the navigation path.
class AuthGuard {
  AuthGuard._();

  static final ValueNotifier<bool?> signedIn = ValueNotifier<bool?>(null);

  /// True once a session has been read. Until then, routes must not redirect,
  /// or a returning user gets bounced to /login before restore finishes.
  static bool get isReady => signedIn.value != null;

  static bool get isLoggedInNow => signedIn.value ?? false;

  /// Called once by bootstrap, login, signup and logout.
  static void setSignedIn(bool value) => signedIn.value = value;

  /// For callers that need an authoritative check when bootstrap has not run.
  static Future<bool> isLoggedIn() async {
    if (isReady) return isLoggedInNow;
    final session = await AuthSessionStore.restore();
    final signedIn = session != null && session.accessToken.isNotEmpty;
    setSignedIn(signedIn);
    debugPrint('[AuthGuard] resolved session from storage: signedIn=$signedIn');
    return signedIn;
  }

  static Future<String?> getAccessToken() async {
    final session = await AuthSessionStore.restore();
    return session?.accessToken;
  }
}

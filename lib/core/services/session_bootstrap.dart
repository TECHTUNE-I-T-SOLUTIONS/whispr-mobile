import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_service.dart';
import '../utils/auth_guard.dart';
import '../../features/auth/supabase_auth_provider.dart';
import 'auth_session_store.dart';
import 'live_update_service.dart';
import 'session_manager.dart';

/// The one startup sequence for the active session.
///
/// Splash, the router and the app wrapper all await this same provider, so
/// secure storage is read exactly once per cold start and no side effect can
/// clear a session because an unrelated service failed to initialise.
final sessionBootstrapProvider = FutureProvider<AuthSessionData?>((ref) async {
  AuthSessionData? session;
  try {
    session = await AuthSessionStore.restore();
  } catch (e) {
    debugPrint('[Bootstrap] session restore failed: $e');
  }

  // Resolve the guard even when restore failed, otherwise the router never
  // redirects and navigation hangs on the first frame.
  AuthGuard.setSignedIn(session != null);

  try {
    await ApiService.instance.ensureInitialized();
  } catch (e) {
    debugPrint('[Bootstrap] API init failed: $e');
  }

  try {
    await ref.read(authStateProvider.notifier).adoptRestoredSession(session);
  } catch (e) {
    debugPrint('[Bootstrap] auth state adoption failed: $e');
  }

  try {
    await SessionManager.instance.adoptRestoredSession(session);
  } catch (e) {
    debugPrint('[Bootstrap] session manager adoption failed: $e');
  }

  unawaited(LiveUpdateService.instance.initialize());
  return session;
});

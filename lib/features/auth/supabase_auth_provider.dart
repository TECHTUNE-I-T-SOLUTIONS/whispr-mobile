import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/chronicles.dart';
import '../../core/network/api_service.dart';
import '../../core/services/auth_session_store.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/services/registered_accounts_store.dart';
import '../../core/services/session_bootstrap.dart';
import '../../core/services/session_manager.dart';
import '../../core/utils/auth_guard.dart';

class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final Creator? user;
  final String? accessToken;
  final String? refreshToken;
  final String? error;

  AuthState({
    this.isLoading = false,
    this.isLoggedIn = false,
    this.user,
    this.accessToken,
    this.refreshToken,
    this.error,
  });

  // Backward compatibility alias.
  bool get isAuthenticated => isLoggedIn;

  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    Creator? user,
    String? accessToken,
    String? refreshToken,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Reactive auth state. The encrypted store is the persistence authority;
/// this class only mirrors it for the UI and router.
class AuthStateNotifier extends StateNotifier<AuthState> {
  final ApiService apiService;

  AuthStateNotifier(this.apiService) : super(AuthState());

  /// Called once by [sessionBootstrapProvider] with the already-restored
  /// session. Never reads storage itself.
  Future<void> adoptRestoredSession(AuthSessionData? session) async {
    if (session == null) {
      AuthGuard.setSignedIn(false);
      state = AuthState();
      debugPrint('[Auth] no stored session; starting signed out');
      return;
    }
    await _adoptSignedIn(session);
    debugPrint('[Auth] restored session for ${session.user.penName}');
  }

  Future<void> _adoptSignedIn(AuthSessionData session) async {
    try {
      await _setSupabaseTokens(session.accessToken, session.refreshToken);
    } catch (e) {
      debugPrint('[Auth] Supabase token attach failed: $e');
    }

    try {
      await PushNotificationService().subscribeOnceForAccount(session.user.id);
    } catch (e) {
      debugPrint('[Auth] push subscription failed: $e');
    }

    state = AuthState(
      isLoggedIn: true,
      user: session.user,
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
    AuthGuard.setSignedIn(true);
  }

  Future<void> _registerAccount(Creator creator) async {
    try {
      await RegisteredAccountsStore.instance.upsert(creator);
    } catch (e) {
      debugPrint('[Auth] account registry update failed: $e');
    }
  }

  Future<bool> login(String email, String password) async {
    state = AuthState(isLoading: true);

    try {
      final response = await apiService.post(
        '/chronicles/auth/login',
        data: {'email': email, 'password': password},
      );

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Login failed');
      }

      final creator = Creator.fromJson(response['creator']);
      final accessToken = response['access_token'] as String;
      final refreshToken = response['refresh_token'] as String?;
      final now = DateTime.now();

      // Throws if the encrypted write fails: a login that was not persisted
      // must not be reported as successful.
      await AuthSessionStore.save(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: creator,
        sessionStart: now,
      );
      await _registerAccount(creator);

      await _adoptSignedIn(AuthSessionData(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: creator,
        savedAt: now,
        sessionStart: now,
      ));

      try {
        await PushNotificationService().showLoginSuccessNotification();
      } catch (e) {
        debugPrint('[Auth] login notification failed: $e');
      }

      debugPrint('Login successful for user: ${creator.penName}');
      return true;
    } catch (e) {
      debugPrint('Login failed: $e');
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<Creator> signup({
    required String email,
    required String password,
    required String penName,
    required String displayName,
    String? bio,
    String? contentType,
    List<String>? categories,
  }) async {
    state = AuthState(isLoading: true);

    try {
      final response = await apiService.post(
        '/chronicles/auth/signup',
        data: {
          'email': email,
          'password': password,
          'pen_name': penName,
          'display_name': displayName,
          'bio': bio,
          'content_type': contentType,
          'categories': categories,
        },
      );

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Signup failed');
      }

      final creator = Creator.fromJson(response['creator']);
      final accessToken = response['access_token'] as String;
      final refreshToken = response['refresh_token'] as String?;
      final now = DateTime.now();

      await AuthSessionStore.save(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: creator,
        sessionStart: now,
      );
      await _registerAccount(creator);

      await _adoptSignedIn(AuthSessionData(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: creator,
        savedAt: now,
        sessionStart: now,
      ));

      try {
        await PushNotificationService().showSignupSuccessNotification();
      } catch (e) {
        debugPrint('[Auth] signup notification failed: $e');
      }

      debugPrint('Signup successful for user: ${creator.penName}');
      return creator;
    } catch (e) {
      debugPrint('Signup failed: $e');
      state = AuthState(error: e.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    try {
      debugPrint('Logging out user...');

      // Deactivate this device's push token while the access token is still
      // valid — the endpoint authenticates with it.
      try {
        await PushNotificationService().unregisterToken();
      } catch (e) {
        debugPrint('Failed to unregister push token: $e');
      }

      await AuthSessionStore.clear();
      await SessionManager().clearSessionData();

      // Supabase sign-out is best effort; local sign-out must still complete.
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (e) {
        debugPrint('Supabase sign-out failed: $e');
      }

      AuthGuard.setSignedIn(false);
      state = AuthState();
      debugPrint('Logout successful - auth state reset');
    } catch (e) {
      debugPrint('Logout error: $e');
      AuthGuard.setSignedIn(false);
      state = AuthState(error: 'Logout failed: $e');
    }
  }

  Future<bool> refreshAccessToken() async {
    try {
      final refreshToken =
          AuthSessionStore.currentSession?.refreshToken ?? state.refreshToken;
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final response = await apiService.post(
        '/chronicles/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final newAccessToken = response['access_token']?.toString();
      if (newAccessToken == null || newAccessToken.isEmpty) return false;
      final newRefreshToken = response['refresh_token']?.toString();

      await AuthSessionStore.updateTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );
      acceptRefreshedTokens(newAccessToken, newRefreshToken);
      return true;
    } catch (e) {
      debugPrint('[Auth] token refresh failed: $e');
      return false;
    }
  }

  /// Called by ApiService after a silent 401/403 refresh. Keeps the in-memory
  /// state aligned without another storage read.
  void acceptRefreshedTokens(String accessToken, String? refreshToken) {
    if (accessToken.isEmpty) return;
    state = state.copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken ?? state.refreshToken,
    );
    try {
      Supabase.instance.client.rest.headers['Authorization'] =
          'Bearer $accessToken';
    } catch (_) {
      // Supabase may not be initialised in a test harness.
    }
  }

  Future<void> _setSupabaseTokens(
    String accessToken,
    String? refreshToken,
  ) async {
    final supabase = Supabase.instance.client;

    // Attach the access token to every REST call *first*, unconditionally.
    // A failed setSession (rotated refresh token, offline launch, ...) must
    // not leave Supabase-backed screens looking signed out.
    supabase.rest.headers['Authorization'] = 'Bearer $accessToken';

    if (refreshToken == null || refreshToken.isEmpty) return;

    try {
      await supabase.auth.setSession(refreshToken);
    } catch (e) {
      debugPrint('[Auth] Supabase session restore failed; keeping REST header: $e');
      // A failed setSession can clear the header — put the fallback back.
      supabase.rest.headers['Authorization'] = 'Bearer $accessToken';
    }
  }

  /// Re-attaches the current token on foreground resume.
  Future<void> syncSupabaseSession() async {
    try {
      final session = AuthSessionStore.currentSession;
      final accessToken = session?.accessToken ?? state.accessToken;
      if (accessToken == null || accessToken.isEmpty) return;
      await _setSupabaseTokens(
        accessToken,
        session?.refreshToken ?? state.refreshToken,
      );
    } catch (e) {
      debugPrint('[Auth] Supabase session re-sync failed: $e');
    }
  }

  Future<bool> updateUser(Creator updatedUser) async {
    try {
      await AuthSessionStore.saveUser(updatedUser);
      await _registerAccount(updatedUser);
      state = state.copyWith(user: updatedUser);
      return true;
    } catch (e) {
      debugPrint('[Auth] profile save failed: $e');
      return false;
    }
  }

  Future<void> refreshAvatar() async {
    if (!state.isLoggedIn || state.user == null) return;

    try {
      final avatarUrl = await apiService.get('/chronicles/creator/avatar');
      final url = avatarUrl['avatar'] as String?;

      if (url != null && url != state.user!.profileImageUrl) {
        final updatedUser = state.user!.copyWith(profileImageUrl: url);
        await updateUser(updatedUser);
      }
    } catch (_) {
      // Avatar refresh is not critical.
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await apiService.post(
        '/chronicles/auth/forgot-password',
        data: {'email': email},
      );
      state = state.copyWith(isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  bool isAuthenticated() => state.isLoggedIn && state.accessToken != null;

  String? getAccessToken() => state.accessToken;

  String? getRefreshToken() => state.refreshToken;
}

final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier(ApiService.instance);
});

/// Backward-compatible alias. New code should wait on sessionBootstrapProvider.
@Deprecated('Use sessionBootstrapProvider instead')
final authInitializationProvider = FutureProvider<void>((ref) async {
  await ref.read(sessionBootstrapProvider.future);
});

final userProvider = Provider<Creator?>((ref) {
  return ref.watch(authStateProvider).user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).isLoggedIn;
});

final accessTokenProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).accessToken;
});

final isLoadingAuthProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).isLoading;
});

final authErrorProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).error;
});

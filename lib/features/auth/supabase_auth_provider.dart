import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/chronicles.dart';
import '../../core/network/api_service.dart';
import '../../core/services/push_notification_service.dart';

// Auth state notifier
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

  // Backward compatibility alias
  bool get isAuthenticated => isLoggedIn;

  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    Creator? user,
    String? accessToken,
    String? refreshToken,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      error: error ?? this.error,
    );
  }
}

// Auth state notifier class
class AuthStateNotifier extends StateNotifier<AuthState> {
  final ApiService apiService;
  SharedPreferences? _prefs;

  AuthStateNotifier(this.apiService) : super(AuthState());

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // Initialize auth state on app startup
  Future<void> initializeAuth() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final prefs = await _getPrefs();
      
      // Check if tokens exist in storage
      final accessToken = prefs.getString(AppConstants.accessTokenKey);
      final refreshToken = prefs.getString(AppConstants.refreshTokenKey);
      final userDataJson = prefs.getString(AppConstants.userDataKey);

      debugPrint('Auth initialization: Checking stored credentials...');
      debugPrint('Access token exists: ${accessToken != null}');
      debugPrint('User data exists: ${userDataJson != null}');

      if (accessToken != null && userDataJson != null) {
        try {
          // Tokens exist, restore session
          final userMap = jsonDecode(userDataJson) as Map<String, dynamic>;
          final user = Creator.fromJson(userMap);

          // Set tokens in Supabase client
          await _setSupabaseTokens(accessToken, refreshToken);

          // Initialize push notifications when restoring session
          try {
            final pushService = PushNotificationService();
            await pushService.subscribeToPushNotifications();
            debugPrint('Push notifications subscribed successfully on session restore');
          } catch (e) {
            debugPrint('Failed to initialize push notifications on session restore: $e');
            // Don't fail session restore if push notifications fail to initialize
          }

          state = state.copyWith(
            isLoggedIn: true,
            user: user,
            accessToken: accessToken,
            refreshToken: refreshToken,
            isLoading: false,
            error: null,
          );
          
          debugPrint('Auth state restored successfully for user: ${user.penName}');
        } catch (e) {
          debugPrint('Error restoring session: $e');
          // If we can't decode the stored data, clear it
          await prefs.remove(AppConstants.userDataKey);
          await prefs.remove(AppConstants.accessTokenKey);
          await prefs.remove(AppConstants.refreshTokenKey);
          await prefs.setBool(AppConstants.isLoggedInKey, false);
          
          state = state.copyWith(isLoading: false, error: null);
          debugPrint('Corrupted session data cleared');
        }
      } else {
        // No tokens found
        debugPrint('No stored credentials found - starting fresh');
        state = state.copyWith(isLoading: false, error: null);
      }
    } catch (e) {
      debugPrint('Auth initialization failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to initialize auth: $e',
      );
    }
  }

  // Login with email and password
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await apiService.post(
        '/chronicles/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Login failed');
      }

      // Parse creator and tokens
      final creator = Creator.fromJson(response['creator']);
      final accessToken = response['access_token'] as String;
      final refreshToken = response['refresh_token'] as String?;

      // Store tokens and user data persistently
      final prefs = await _getPrefs();
      await prefs.setBool(AppConstants.isLoggedInKey, true);
      await prefs.setString(AppConstants.accessTokenKey, accessToken);
      if (refreshToken != null) {
        await prefs.setString(AppConstants.refreshTokenKey, refreshToken);
      }
      await prefs.setString(
        AppConstants.userDataKey,
        jsonEncode(creator.toJson()),
      );

      debugPrint('User data saved to storage: ${creator.penName}');

      // Set tokens in Supabase
      await _setSupabaseTokens(accessToken, refreshToken);

      // Initialize push notifications after successful login
      try {
        final pushService = PushNotificationService();
        await pushService.subscribeToPushNotifications();
        await pushService.showLoginSuccessNotification();
        debugPrint('Push notifications subscribed and login notification sent');
      } catch (e) {
        debugPrint('Failed to initialize push notifications: $e');
        // Don't fail the login if push notifications fail to initialize
      }

      state = state.copyWith(
        isLoading: false,
        isLoggedIn: true,
        user: creator,
        accessToken: accessToken,
        refreshToken: refreshToken,
        error: null,
      );

      debugPrint('Login successful for user: ${creator.penName}');
      return true;
    } catch (e) {
      debugPrint('Login failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  // Signup with email, password, and profile info
  Future<Creator> signup({
    required String email,
    required String password,
    required String penName,
    required String displayName,
    String? bio,
    String? contentType,
    List<String>? categories,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

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

      // Parse creator and tokens
      final creator = Creator.fromJson(response['creator']);
      final accessToken = response['access_token'] as String;
      final refreshToken = response['refresh_token'] as String?;

      // Store tokens and user data persistently
      final prefs = await _getPrefs();
      await prefs.setBool(AppConstants.isLoggedInKey, true);
      await prefs.setString(AppConstants.accessTokenKey, accessToken);
      if (refreshToken != null) {
        await prefs.setString(AppConstants.refreshTokenKey, refreshToken);
      }
      await prefs.setString(
        AppConstants.userDataKey,
        jsonEncode(creator.toJson()),
      );

      debugPrint('User data saved to storage: ${creator.penName}');

      // Set tokens in Supabase
      await _setSupabaseTokens(accessToken, refreshToken);

      state = state.copyWith(
        isLoading: false,
        isLoggedIn: true,
        user: creator,
        accessToken: accessToken,
        refreshToken: refreshToken,
        error: null,
      );

      debugPrint('Signup successful for user: ${creator.penName}');
      return creator;
    } catch (e) {
      debugPrint('Signup failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    try {
      debugPrint('Logging out user...');
      
      // Send logout notification before clearing data - DISABLED for now
      /*
      try {
        final pushService = PushNotificationService();
        await pushService.unsubscribeFromPushNotifications();
        await pushService.showLogoutNotification();
        debugPrint('Logout notification sent');
      } catch (e) {
        debugPrint('Failed to send logout notification: $e');
        // Don't fail logout if notifications fail
      }
      */

      final prefs = await _getPrefs();
      
      // Clear storage completely
      await prefs.remove(AppConstants.isLoggedInKey);
      await prefs.remove(AppConstants.accessTokenKey);
      await prefs.remove(AppConstants.refreshTokenKey);
      await prefs.remove(AppConstants.userDataKey);

      debugPrint('Session data cleared from storage');

      // Clear Supabase session
      await Supabase.instance.client.auth.signOut();

      // Reset state completely
      state = AuthState(isLoading: false);
      
      debugPrint('Logout successful - auth state reset');
    } catch (e) {
      debugPrint('Logout error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Logout failed: $e',
      );
    }
  }

  // Refresh access token using refresh token
  Future<bool> refreshAccessToken() async {
    try {
      final refreshToken = state.refreshToken;
      if (refreshToken == null) return false;

      final response = await apiService.post(
        '/chronicles/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response['access_token'] == null) {
        return false;
      }

      final newAccessToken = response['access_token'] as String;
      final newRefreshToken = response['refresh_token'] as String?;

      // Store new tokens
      final prefs = await _getPrefs();
      await prefs.setString(AppConstants.accessTokenKey, newAccessToken);
      if (newRefreshToken != null) {
        await prefs.setString(AppConstants.refreshTokenKey, newRefreshToken);
      }

      // Set tokens in Supabase
      await _setSupabaseTokens(newAccessToken, newRefreshToken);

      state = state.copyWith(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken ?? state.refreshToken,
      );

      return true;
    } catch (e) {
      // Token refresh failed
      return false;
    }
  }

  // Set tokens in Supabase client for database operations
  Future<void> _setSupabaseTokens(String accessToken, String? refreshToken) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Update the auth header for the Supabase client
      supabase.rest.headers['Authorization'] = 'Bearer $accessToken';
      
      // If you need to use real Supabase auth session, you can set it here
      // but since we're using API tokens, the header is sufficient
    } catch (e) {
      // Error setting tokens - not critical since API service also sets them
    }
  }

  // Update user data
  Future<bool> updateUser(Creator updatedUser) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(
        AppConstants.userDataKey,
        jsonEncode(updatedUser.toJson()),
      );

      state = state.copyWith(user: updatedUser);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Refresh avatar from API
  Future<void> refreshAvatar() async {
    if (!state.isLoggedIn || state.user == null) return;

    try {
      final avatarUrl = await apiService.get('/chronicles/creator/avatar');
      final url = avatarUrl['avatar'] as String?;
      
      if (url != null && url != state.user!.profileImageUrl) {
        final updatedUser = state.user!.copyWith(profileImageUrl: url);
        await updateUser(updatedUser);
      }
    } catch (e) {
      // Silently fail - avatar refresh is not critical
    }
  }

  // Clear error message
  void clearError() {
    state = state.copyWith(error: null);
  }

  // Forgot password - request password reset email
  Future<void> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await apiService.post(
        '/chronicles/auth/forgot-password',
        data: {'email': email},
      );

      state = state.copyWith(
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  // Check if user is authenticated
  bool isAuthenticated() => state.isLoggedIn && state.accessToken != null;

  // Get access token
  String? getAccessToken() => state.accessToken;

  // Get refresh token
  String? getRefreshToken() => state.refreshToken;
}

// Riverpod providers
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier(ApiService.instance);
});

// Provider to restore auth on app startup
final authInitializationProvider = FutureProvider<void>((ref) async {
  final auth = ref.read(authStateProvider.notifier);
  await auth.initializeAuth();
});

// Authentication convenience providers
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

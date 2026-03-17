
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/chronicles.dart';
import '../../core/network/api_service.dart';
import 'supabase_auth_provider.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ApiService.instance, ref);
});

class AuthService {
  final ApiService _apiService;
  final Ref ref;

  AuthService(this._apiService, this.ref);

  // Login - delegates to auth provider
  Future<Creator> login(String email, String password) async {
    final authNotifier = ref.read(authStateProvider.notifier);
    final success = await authNotifier.login(email, password);
    
    if (!success) {
      throw Exception(ref.read(authStateProvider).error ?? 'Login failed');
    }

    return ref.read(authStateProvider).user!;
  }

  // Signup - delegates to auth provider
  Future<Creator> signup({
    required String email,
    required String password,
    required String penName,
    required String displayName,
    String? bio,
    String? contentType,
    List<String>? categories,
  }) async {
    final authNotifier = ref.read(authStateProvider.notifier);
    return await authNotifier.signup(
      email: email,
      password: password,
      penName: penName,
      displayName: displayName,
      bio: bio,
      contentType: contentType,
      categories: categories,
    );
  }

  // Logout - delegates to auth provider
  Future<void> logout() async {
    final authNotifier = ref.read(authStateProvider.notifier);
    await authNotifier.logout();
  }

  // Get current user - reads from auth provider
  Future<Creator?> getCurrentUser() async {
    return ref.read(authStateProvider).user;
  }

  // Check if user is logged in - reads from auth provider
  Future<bool> isLoggedIn() async {
    return ref.read(authStateProvider).isLoggedIn;
  }

  // Get access token
  String? getAccessToken() {
    return ref.read(authStateProvider).accessToken;
  }

  // Get refresh token
  String? getRefreshToken() {
    return ref.read(authStateProvider).refreshToken;
  }

  // Update user profile
  Future<Creator> updateProfile({
    String? displayName,
    String? bio,
    String? profileImageUrl,
    List<String>? categories,
    Map<String, String>? socialLinks,
    ProfileVisibility? profileVisibility,
    bool? pushNotificationsEnabled,
  }) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['display_name'] = displayName;
    if (bio != null) data['bio'] = bio;
    if (profileImageUrl != null) data['profile_image_url'] = profileImageUrl;
    if (categories != null) data['categories'] = categories;
    if (socialLinks != null) data['social_links'] = socialLinks;
    if (profileVisibility != null) data['profile_visibility'] = profileVisibility.name;
    if (pushNotificationsEnabled != null) data['push_notifications_enabled'] = pushNotificationsEnabled;

    final response = await _apiService.put(
      '${AppConstants.chroniclesAuthEndpoint}/profile',
      data: data,
    );

    final creator = Creator.fromJson(response);
    
    // Update auth provider
    final authNotifier = ref.read(authStateProvider.notifier);
    await authNotifier.updateUser(creator);

    return creator;
  }

  // Get current user profile from API
  Future<Creator> getCurrentUserProfile() async {
    final response = await _apiService.get('/chronicles/creator/profile');
    final profile = response['creator'] ?? response['profile'];
    return Creator.fromJson(profile);
  }

  // Get current user avatar from API
  Future<String?> getCurrentUserAvatar() async {
    try {
      final response = await _apiService.get('/chronicles/creator/avatar');
      return response['avatar'] as String?;
    } catch (e) {
      // If avatar API fails, try to get from profile
      try {
        final profileResponse = await _apiService.get('/chronicles/creator/profile');
        final profile = profileResponse['creator'] ?? profileResponse['profile'];
        return profile['profileImageUrl'] ?? profile['profile_image_url'] ?? profile['avatar_url'];
      } catch (e) {
        return null;
      }
    }
  }

  // Forgot password
  Future<void> forgotPassword(String email) async {
    await _apiService.post(
      '${AppConstants.chroniclesAuthEndpoint}/forgot-password',
      data: {'email': email},
    );
  }

  // Reset password
  Future<void> resetPassword(String token, String newPassword) async {
    await _apiService.post(
      '${AppConstants.chroniclesAuthEndpoint}/reset-password',
      data: {
        'token': token,
        'password': newPassword,
      },
    );
  }
}
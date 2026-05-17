import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../models/chronicles.dart';

class AuthSessionData {
  final String accessToken;
  final String? refreshToken;
  final Creator user;
  final DateTime savedAt;
  final DateTime? sessionStart;

  AuthSessionData({
    required this.accessToken,
    required this.user,
    required this.savedAt,
    this.refreshToken,
    this.sessionStart,
  });

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'user_data': user.toJson(),
        'saved_at': savedAt.toIso8601String(),
        'session_start': sessionStart?.toIso8601String(),
      };

  factory AuthSessionData.fromJson(Map<String, dynamic> json) {
    return AuthSessionData(
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString(),
      user: Creator.fromJson(Map<String, dynamic>.from(json['user_data'] as Map)),
      savedAt: DateTime.tryParse(json['saved_at']?.toString() ?? '') ?? DateTime.now(),
      sessionStart: DateTime.tryParse(json['session_start']?.toString() ?? ''),
    );
  }
}

class AuthSessionStore {
  static const String _bundleKey = 'auth_session_bundle';

  static Future<void> save({
    required String accessToken,
    String? refreshToken,
    required Creator user,
    DateTime? sessionStart,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bundle = AuthSessionData(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: user,
      savedAt: DateTime.now(),
      sessionStart: sessionStart,
    );

    await prefs.setString(_bundleKey, jsonEncode(bundle.toJson()));
    await prefs.setBool(AppConstants.isLoggedInKey, true);
    await prefs.setString(AppConstants.accessTokenKey, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString(AppConstants.refreshTokenKey, refreshToken);
    } else {
      await prefs.remove(AppConstants.refreshTokenKey);
    }
    await prefs.setString(AppConstants.userDataKey, jsonEncode(user.toJson()));
    await prefs.setString('session_start_time', (sessionStart ?? DateTime.now()).toIso8601String());
  }

  static Future<AuthSessionData?> restore() async {
    final prefs = await SharedPreferences.getInstance();

    final rawBundle = prefs.getString(_bundleKey);
    if (rawBundle != null && rawBundle.isNotEmpty) {
      try {
        final parsed = jsonDecode(rawBundle);
        if (parsed is Map<String, dynamic>) {
          return AuthSessionData.fromJson(parsed);
        }
      } catch (_) {
        // Fall back to legacy keys below.
      }
    }

    final accessToken = prefs.getString(AppConstants.accessTokenKey);
    final userDataJson = prefs.getString(AppConstants.userDataKey);
    if (accessToken == null || userDataJson == null) return null;

    try {
      final userMap = jsonDecode(userDataJson);
      if (userMap is Map<String, dynamic>) {
        return AuthSessionData(
          accessToken: accessToken,
          refreshToken: prefs.getString(AppConstants.refreshTokenKey),
          user: Creator.fromJson(userMap),
          savedAt: DateTime.now(),
          sessionStart: DateTime.tryParse(prefs.getString('session_start_time') ?? ''),
        );
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bundleKey);
    await prefs.remove(AppConstants.accessTokenKey);
    await prefs.remove(AppConstants.refreshTokenKey);
    await prefs.remove(AppConstants.userDataKey);
    await prefs.remove(AppConstants.isLoggedInKey);
    await prefs.remove('session_start_time');
  }

  static Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_bundleKey) != null || prefs.getString(AppConstants.accessTokenKey) != null;
  }
}
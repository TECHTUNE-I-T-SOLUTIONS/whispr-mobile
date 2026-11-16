import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../models/chronicles.dart';

/// Persisted login.
///
/// Tokens live in platform-encrypted storage (Keychain on iOS, EncryptedShared
/// Preferences / Keystore on Android) and never in SharedPreferences, which is
/// world-readable plaintext on rooted devices. The `Creator` profile is
/// non-sensitive, so it stays in SharedPreferences for fast synchronous reads.
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

  /// Tokens only — this is what goes to secure storage.
  String toSecureJson() => jsonEncode({
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'saved_at': savedAt.toIso8601String(),
        'session_start': sessionStart?.toIso8601String(),
      });

  Map<String, dynamic> toJson() => {
        ...jsonDecode(toSecureJson()) as Map<String, dynamic>,
        'user_data': user.toJson(),
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
  AuthSessionStore._();

  /// Secure-storage key for the token bundle. The old SharedPreferences key
  /// stays in [_legacyBundleKey] so existing installs migrate on next launch.
  static const String _secureBundleKey = 'whispr_auth_tokens_v2';
  static const String _legacyBundleKey = 'auth_session_bundle';
  static const String _userKey = 'auth_user_profile';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// True once [restore] has completed at least once, so callers can tell
  /// "signed out" apart from "not read yet".
  static bool get isRestored => _restored;
  static bool _restored = false;

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

    try {
      await _secureStorage.write(key: _secureBundleKey, value: bundle.toSecureJson());
    } catch (e) {
      // A secure-storage failure must not block the login that just succeeded.
      // The tokens still work for this process; the user is asked to sign in
      // again next cold start rather than being logged out mid-session.
      debugPrint('[AuthSessionStore] secure write failed: $e');
    }

    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    await prefs.setBool(AppConstants.isLoggedInKey, true);
    await prefs.setString('session_start_time', (sessionStart ?? DateTime.now()).toIso8601String());

    // Legacy plaintext copies are removed once the encrypted copy exists.
    await prefs.remove(_legacyBundleKey);
    await prefs.remove(AppConstants.accessTokenKey);
    await prefs.remove(AppConstants.refreshTokenKey);
    await prefs.remove(AppConstants.userDataKey);

    _restored = true;
  }

  /// Reads the session, migrating a legacy plaintext bundle if that is all
  /// that exists. Returns null when nobody is signed in.
  static Future<AuthSessionData?> restore() async {
    final prefs = await SharedPreferences.getInstance();

    Map<String, dynamic>? tokens;
    try {
      final raw = await _secureStorage.read(key: _secureBundleKey);
      if (raw != null && raw.isNotEmpty) {
        tokens = jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[AuthSessionStore] secure read failed: $e');
    }

    if (tokens == null) {
      tokens = await _readLegacyTokens(prefs);
      if (tokens == null) {
        _restored = true;
        return null;
      }
    }

    final userJson = prefs.getString(_userKey) ?? prefs.getString(AppConstants.userDataKey);
    if (userJson == null || userJson.isEmpty) {
      _restored = true;
      return null;
    }

    final Creator user;
    try {
      user = Creator.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    } catch (e) {
      // Unreadable profile means the session cannot be reconstructed; it is
      // cleared by the caller so the user sees the login screen, not a crash.
      debugPrint('[AuthSessionStore] could not parse stored profile: $e');
      _restored = true;
      return null;
    }

    final session = AuthSessionData(
      accessToken: tokens['access_token']?.toString() ?? '',
      refreshToken: tokens['refresh_token']?.toString(),
      user: user,
      savedAt: DateTime.tryParse(tokens['saved_at']?.toString() ?? '') ?? DateTime.now(),
      sessionStart: DateTime.tryParse(tokens['session_start']?.toString() ?? ''),
    );

    if (session.accessToken.isEmpty) {
      _restored = true;
      return null;
    }

    // Migrate plaintext into secure storage, then drop the plaintext.
    try {
      final hadLegacy = await _secureStorage.read(key: _secureBundleKey) == null;
      if (hadLegacy) {
        await _secureStorage.write(key: _secureBundleKey, value: session.toSecureJson());
        await prefs.remove(_legacyBundleKey);
        await prefs.remove(AppConstants.accessTokenKey);
        await prefs.remove(AppConstants.refreshTokenKey);
        await prefs.remove(AppConstants.userDataKey);
      }
    } catch (e) {
      debugPrint('[AuthSessionStore] migration failed: $e');
    }

    _restored = true;
    return session;
  }

  static Future<Map<String, dynamic>?> _readLegacyTokens(SharedPreferences prefs) async {
    final rawBundle = prefs.getString(_legacyBundleKey);
    if (rawBundle != null && rawBundle.isNotEmpty) {
      try {
        final parsed = jsonDecode(rawBundle);
        if (parsed is Map<String, dynamic>) return parsed;
      } catch (_) {
        // fall through to the individual legacy keys
      }
    }

    final accessToken = prefs.getString(AppConstants.accessTokenKey);
    if (accessToken == null || accessToken.isEmpty) return null;
    return {
      'access_token': accessToken,
      'refresh_token': prefs.getString(AppConstants.refreshTokenKey),
      'saved_at': DateTime.now().toIso8601String(),
      'session_start': prefs.getString('session_start_time'),
    };
  }

  /// Updates just the cached profile after an edit, keeping tokens untouched.
  static Future<void> saveUser(Creator user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await _secureStorage.delete(key: _secureBundleKey);
    } catch (e) {
      debugPrint('[AuthSessionStore] secure delete failed: $e');
    }
    await prefs.remove(_legacyBundleKey);
    await prefs.remove(_userKey);
    await prefs.remove(AppConstants.accessTokenKey);
    await prefs.remove(AppConstants.refreshTokenKey);
    await prefs.remove(AppConstants.userDataKey);
    await prefs.remove(AppConstants.isLoggedInKey);
    await prefs.remove('session_start_time');
    _restored = true;
  }

  static Future<bool> hasSession() async {
    final session = await restore();
    return session != null && session.accessToken.isNotEmpty;
  }
}

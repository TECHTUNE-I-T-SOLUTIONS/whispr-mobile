import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../models/chronicles.dart';

/// One persisted login, including the profile.
///
/// The whole bundle lives in platform-encrypted storage (Keychain on iOS,
/// EncryptedSharedPreferences/Keystore on Android). Older installs kept tokens
/// in secure storage and the profile in SharedPreferences; those keys are read
/// only to migrate into the v3 bundle.
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

  String toSecureJson() => jsonEncode(toJson());

  factory AuthSessionData.fromJson(Map<String, dynamic> json) =>
      AuthSessionData.fromSecureJson(json);

  factory AuthSessionData.fromSecureJson(Map<String, dynamic> json) {
    final accessToken = json['access_token']?.toString() ?? '';
    if (accessToken.isEmpty) {
      throw const FormatException('Auth session has no access token');
    }
    final userData = json['user_data'];
    if (userData is! Map) {
      throw const FormatException('Auth session has no user_data');
    }
    return AuthSessionData(
      accessToken: accessToken,
      refreshToken: json['refresh_token']?.toString(),
      user: Creator.fromJson(Map<String, dynamic>.from(userData)),
      savedAt: DateTime.tryParse(json['saved_at']?.toString() ?? '') ?? DateTime.now(),
      sessionStart: DateTime.tryParse(json['session_start']?.toString() ?? ''),
    );
  }

  /// Reads a v2-style bundle (tokens only) with a separately stored profile.
  factory AuthSessionData.fromLegacyJson(
    Map<String, dynamic> json,
    Creator user,
  ) {
    return AuthSessionData(
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString(),
      user: user,
      savedAt: DateTime.tryParse(json['saved_at']?.toString() ?? '') ?? DateTime.now(),
      sessionStart: DateTime.tryParse(json['session_start']?.toString() ?? ''),
    );
  }
}

/// The single persistence authority for the active session.
///
/// Every read and write goes through one serialized queue. Cold start used to
/// have three callers (`main`, splash and [ApiService]) restoring the same
/// secure-storage key concurrently; whichever write landed last could win and
/// leave the next launch with a half-written session.
class AuthSessionStore {
  AuthSessionStore._();

  static const String _secureBundleKeyV3 = 'whispr_auth_session_v3';
  static const String _secureBundleKeyV2 = 'whispr_auth_tokens_v2';
  static const String _legacyBundleKey = 'auth_session_bundle';
  static const String _userKey = 'auth_user_profile';
  static const String _sessionStartKey = 'session_start_time';
// Supabase's own persisted session. An in-place update can leave this intact
// while the encrypted v3 bundle is unreadable; it is the recovery source for
// returning users, never the primary store.
static const String _supabaseSessionKey =
'sb-vkftywhuaxwbknlrymnr-auth-token';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<void> _tail = Future.value();
  static Future<AuthSessionData?>? _restoreFuture;
  static AuthSessionData? _currentSession;
  static bool _restored = false;

  /// True once a restore has been attempted (or a session has been saved).
  static bool get isRestored => _restored;

  /// The authoritative in-memory session, populated by [restore] or [save].
  static AuthSessionData? get currentSession => _currentSession;

  static String? get cachedAccessToken => _currentSession?.accessToken;
  static String? get cachedRefreshToken => _currentSession?.refreshToken;

  /// Serializes every storage operation, reads included.
  static Future<T> _exclusive<T>(Future<T> Function() action) {
    final previous = _tail;
    final next = Completer<void>();
    _tail = next.future;
    return previous.catchError((_) {}).then((_) async {
      try {
        return await action();
      } finally {
        if (!next.isCompleted) next.complete();
      }
    });
  }

  static void _adopt(AuthSessionData? session) {
    _currentSession = session;
    _restored = true;
  }

  /// Saves a new login. Throws if the encrypted write fails: a login that was
  /// not persisted must not be reported as successful to the user.
  static Future<void> save({
    required String accessToken,
    String? refreshToken,
    required Creator user,
    DateTime? sessionStart,
  }) async {
    if (accessToken.isEmpty) {
      throw ArgumentError.value(accessToken, 'accessToken', 'Cannot save an empty session');
    }
    final session = AuthSessionData(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: user,
      savedAt: DateTime.now(),
      sessionStart: sessionStart ?? DateTime.now(),
    );
    return _exclusive(() async {
      await _writeBundle(session);
      _adopt(session);
    });
  }

  /// Single-flight restore. Once the cache is warm, callers get it without
  /// touching disk again.
  static Future<AuthSessionData?> restore() {
    if (_restored) return Future.value(_currentSession);
    final inFlight = _restoreFuture;
    if (inFlight != null) return inFlight;

    final future = _exclusive<AuthSessionData?>(() async {
      final session = await _readSession();
      _adopt(session);
      return session;
    });
    _restoreFuture = future;
    return future.whenComplete(() {
      if (identical(_restoreFuture, future)) _restoreFuture = null;
    });
  }

  /// Replaces tokens after a silent refresh, preserving the profile and the
  /// original session start.
  static Future<void> updateTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    if (accessToken.isEmpty) {
      throw ArgumentError.value(accessToken, 'accessToken', 'Cannot store an empty token');
    }
    return _exclusive(() async {
      final existing = await _currentOrStored();
      if (existing == null) {
        debugPrint('[AuthSessionStore] token update ignored: no active session');
        return;
      }
      final updated = AuthSessionData(
        accessToken: accessToken,
        refreshToken: refreshToken ?? existing.refreshToken,
        user: existing.user,
        savedAt: DateTime.now(),
        sessionStart: existing.sessionStart ?? existing.savedAt,
      );
      await _writeBundle(updated);
      _adopt(updated);
    });
  }

  /// Rewrites the active bundle with an edited profile. Tokens are untouched.
  static Future<void> saveUser(Creator user) => _exclusive(() async {
        final prefs = await SharedPreferences.getInstance();
        final existing = await _currentOrStored(prefs: prefs);
        if (existing == null) {
          // No active session: keep the profile for a future migration only.
          await prefs.setString(_userKey, jsonEncode(user.toJson()));
          return;
        }
        final updated = AuthSessionData(
          accessToken: existing.accessToken,
          refreshToken: existing.refreshToken,
          user: user,
          savedAt: existing.savedAt,
          sessionStart: existing.sessionStart,
        );
        await _writeBundle(updated, prefs: prefs);
        _adopt(updated);
      });

  /// Stamps a session start once for bundles restored from older versions.
  static Future<void> ensureSessionStart(DateTime start) => _exclusive(() async {
        final existing = await _currentOrStored();
        if (existing == null || existing.sessionStart != null) return;
        final updated = AuthSessionData(
          accessToken: existing.accessToken,
          refreshToken: existing.refreshToken,
          user: existing.user,
          savedAt: existing.savedAt,
          sessionStart: start,
        );
        await _writeBundle(updated);
        _adopt(updated);
      });

  /// Explicit sign-out only. Never called from a failed refresh or restore.
  static Future<void> clear() => _exclusive(() async {
        try {
          await _secureStorage.delete(key: _secureBundleKeyV3);
          await _secureStorage.delete(key: _secureBundleKeyV2);
        } catch (e) {
          debugPrint('[AuthSessionStore] secure delete failed: $e');
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_legacyBundleKey);
        await prefs.remove(_userKey);
        await prefs.remove(_sessionStartKey);
        await prefs.remove(AppConstants.accessTokenKey);
        await prefs.remove(AppConstants.refreshTokenKey);
        await prefs.remove(AppConstants.userDataKey);
        await prefs.remove(AppConstants.isLoggedInKey);
        _adopt(null);
      });

  static Future<bool> hasSession() async {
    final session = _restored ? _currentSession : await restore();
    return session != null && session.accessToken.isNotEmpty;
  }

  // --- private helpers; all called from inside _exclusive ---

  static Future<AuthSessionData?> _currentOrStored({SharedPreferences? prefs}) async {
    if (_currentSession != null) return _currentSession;
    return _readSession(prefs: prefs);
  }

  static Future<AuthSessionData?> _readSession({SharedPreferences? prefs}) async {
    prefs ??= await SharedPreferences.getInstance();

    final v3 = await _readSecureJson(_secureBundleKeyV3);
    if (v3 != null) {
      try {
        return AuthSessionData.fromSecureJson(v3);
      } on FormatException catch (e) {
        debugPrint('[AuthSessionStore] ignoring invalid v3 bundle: $e');
      }
    }

    final v2 = await _readSecureJson(_secureBundleKeyV2);
    if (v2 != null && (v2['access_token']?.toString().isNotEmpty ?? false)) {
      final user = _userFrom(v2, prefs);
      if (user != null) {
        final session = AuthSessionData.fromLegacyJson(v2, user);
        await _migrate(session, prefs);
        return session;
      }
    }

    final legacy = await _readLegacyTokens(prefs);
debugPrint('[AuthSessionStore] restore sources: v3=${v3 != null}, v2=${v2 != null}, legacy=${legacy != null}');
if (v3 == null && v2 == null) {
final recovery = _sessionFromSupabase(prefs);
if (recovery != null) {
await _migrate(recovery, prefs);
debugPrint('[AuthSessionStore] recovered session from Supabase persistence');
return recovery;
}
}
    if (legacy != null && (legacy['access_token']?.toString().isNotEmpty ?? false)) {
      final user = _userFrom(legacy, prefs);
      if (user != null) {
        final session = AuthSessionData.fromLegacyJson(legacy, user);
        await _migrate(session, prefs);
        return session;
      }
    }
    return null;
  }

  static AuthSessionData? _sessionFromSupabase(SharedPreferences prefs) {
final raw = prefs.getString(_supabaseSessionKey);
if (raw == null || raw.isEmpty) return null;

final Map<String, dynamic> decoded;
try {
final parsed = jsonDecode(raw);
if (parsed is! Map<String, dynamic>) return null;
decoded = parsed;
} catch (e) {
debugPrint('[AuthSessionStore] unreadable Supabase session: $e');
return null;
}

final accessToken = decoded['access_token']?.toString() ?? '';
if (accessToken.isEmpty) return null;
final refreshToken = decoded['refresh_token']?.toString();

final expiresAt = int.tryParse(decoded['expires_at']?.toString() ?? '');
if ((refreshToken == null || refreshToken.isEmpty) &&
expiresAt != null &&
expiresAt * 1000 <= DateTime.now().millisecondsSinceEpoch) {
return null;
}

final user = _userFrom(decoded, prefs);
if (user == null) return null;
final supabaseUser = decoded['user'];
if (supabaseUser is Map) {
final id = supabaseUser['id']?.toString();
// Creator.id is the database row id; Creator.userId is the Supabase auth id.
final profileAuthId = user.userId ?? user.id;
if (id != null && id.isNotEmpty && profileAuthId.isNotEmpty && id != profileAuthId) {
debugPrint('[AuthSessionStore] Supabase session belongs to a different user');
return null;
}
}

return AuthSessionData(
accessToken: accessToken,
refreshToken: refreshToken,
user: user,
savedAt: DateTime.now(),
sessionStart: DateTime.tryParse(prefs.getString(_sessionStartKey) ?? ''),
);
}

static Future<Map<String, dynamic>?> _readSecureJson(String key) async {
// Diagnostic: the three supported stores are checked in order. A missing
// secure bundle is expected after an uninstall/reinstall, but must be
// distinguishable from a decryption failure on an in-place update.

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final raw = await _secureStorage.read(key: key);
        if (raw == null || raw.isEmpty) return null;
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        return null;
      } catch (e) {
        debugPrint('[AuthSessionStore] secure read failed ($key): $e');
        if (attempt == 0) await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
    return null;
  }

  static Creator? _userFrom(Map<String, dynamic> tokens, SharedPreferences prefs) {
    final candidates = <Object?>[
      tokens['user_data'],
      prefs.getString(_userKey),
      prefs.getString(AppConstants.userDataKey),
    ];
    for (final candidate in candidates) {
      if (candidate == null) continue;
      try {
        final map = candidate is String ? jsonDecode(candidate) : candidate;
        if (map is Map) return Creator.fromJson(Map<String, dynamic>.from(map));
      } catch (e) {
        debugPrint('[AuthSessionStore] stored profile unreadable: $e');
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _readLegacyTokens(SharedPreferences prefs) async {
    final rawBundle = prefs.getString(_legacyBundleKey);
    if (rawBundle != null && rawBundle.isNotEmpty) {
      try {
        final parsed = jsonDecode(rawBundle);
        if (parsed is Map<String, dynamic>) return parsed;
      } catch (_) {
        // Fall through to the individual legacy keys.
      }
    }

    final accessToken = prefs.getString(AppConstants.accessTokenKey);
    if (accessToken == null || accessToken.isEmpty) return null;
    return {
      'access_token': accessToken,
      'refresh_token': prefs.getString(AppConstants.refreshTokenKey),
      'saved_at': DateTime.now().toIso8601String(),
      'session_start': prefs.getString(_sessionStartKey),
    };
  }

  static Future<void> _migrate(AuthSessionData session, SharedPreferences prefs) async {
    try {
      await _writeBundle(session, prefs: prefs);
      await _secureStorage.delete(key: _secureBundleKeyV2);
      await prefs.remove(_legacyBundleKey);
      await prefs.remove(AppConstants.accessTokenKey);
      await prefs.remove(AppConstants.refreshTokenKey);
      await prefs.remove(AppConstants.userDataKey);
      debugPrint('[AuthSessionStore] migrated legacy session to encrypted v3 bundle');
    } catch (e) {
      debugPrint('[AuthSessionStore] legacy migration failed: $e');
    }
  }

  static Future<void> _writeBundle(
    AuthSessionData session, {
    SharedPreferences? prefs,
  }) async {
    await _secureStorage.write(key: _secureBundleKeyV3, value: session.toSecureJson());
    prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(session.user.toJson()));
    await prefs.setBool(AppConstants.isLoggedInKey, true);
    await prefs.setString(_sessionStartKey, (session.sessionStart ?? session.savedAt).toIso8601String());
    await prefs.remove(_legacyBundleKey);
    await prefs.remove(AppConstants.accessTokenKey);
    await prefs.remove(AppConstants.refreshTokenKey);
    await prefs.remove(AppConstants.userDataKey);
  }
}

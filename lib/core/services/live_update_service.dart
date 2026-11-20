import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../models/live_update_snapshot.dart';
import '../network/api_service.dart';

/// Owns the widget/live-update snapshot: one production API fetch produces a
/// compact model that is pushed to the Android home widget, the low-priority
/// ongoing notification, and (on iOS) a Live Activity.
class LiveUpdateService {
  LiveUpdateService._internal();
  static final LiveUpdateService instance = LiveUpdateService._internal();

  static const MethodChannel _channel =
      MethodChannel('com.whispr.whisprmobile/live_updates');
  static const String _snapshotKey = 'whispr.live_update.snapshot.v1';
  static const String _disabledKey = 'whispr.live_update.disabled';

  static const int liveNotificationId = 7101;
  static const String liveChannelId = 'whispr_live';
  static const String liveChannelName = 'Live Whispr';
  static const String liveChannelDescription =
      'Current counts and latest update, always quiet and never audible';

  static const Duration _refreshInterval = Duration(minutes: 15);
  static const Set<String> _productionHosts = <String>{
    'whisprwords.com',
    'www.whisprwords.com',
  };

  final ApiService _api = ApiService.instance;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  Future<LiveUpdateSnapshot?>? _inFlight;
bool _initialized = false;

  /// Starts updates when the user has not opted out. Android requires the
  /// notification permission already granted by the existing push prompt;
  /// iOS Live Activities do not need that permission.
  Future<LiveUpdateSnapshot?> initialize() async {
 if (_initialized) return null;
 _initialized = true;
    if (kIsWeb || !await _isEnabled()) return null;
    final cached = await loadCachedSnapshot();
    if (cached != null) {
      await publish(cached);
    }
    return refresh();
  }

  /// Called on app resume. Repaints a cached snapshot immediately and refetches
  /// only when the cache is older than [_refreshInterval].
  Future<LiveUpdateSnapshot?> refreshIfDue() async {
    if (kIsWeb || !await _isEnabled()) return null;
    final cached = await loadCachedSnapshot();
    if (cached != null &&
        DateTime.now().toUtc().difference(cached.updatedAt) < _refreshInterval) {
      await publish(cached);
      return cached;
    }
    return refresh();
  }

  Future<LiveUpdateSnapshot?> loadCachedSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_snapshotKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return LiveUpdateSnapshot.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('[LiveUpdates] cached snapshot unreadable: $e');
    }
    return null;
  }

  Future<bool> _isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_disabledKey) ?? false) return false;

    if (Platform.isAndroid) {
      final granted = await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
      return granted ?? false;
    }
    return true;
  }

  /// Settings hook. Disabling removes the ongoing notification and ends any
  /// Live Activity but leaves the home widget showing its last synced data.
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_disabledKey, !enabled);
    if (!enabled) {
      await stop();
    } else {
      await refresh();
    }
  }

  Future<LiveUpdateSnapshot?> refresh() async {
    final existing = _inFlight;
    if (existing != null) return existing;
    final task = _refresh();
    _inFlight = task;
    try {
      return await task;
    } finally {
      _inFlight = null;
    }
  }

  Future<LiveUpdateSnapshot?> _refresh() async {
    if (!_isProductionApi()) {
      debugPrint('[LiveUpdates] non-production API configured; snapshot skipped');
      return loadCachedSnapshot();
    }

    String? error;
    Map<String, dynamic> notifications = const <String, dynamic>{};
    Map<String, dynamic> stats = const <String, dynamic>{};
    List<dynamic> publicPosts = const <dynamic>[];

    try {
      await ApiService.instance.ensureInitialized();
      final results = await Future.wait<dynamic>(
        <Future<dynamic>>[
          _fetchMap('/chronicles/creator/notifications', <String, dynamic>{
            'limit': 1,
            'offset': 0,
            'type': 'all',
          }),
          _fetchMap('/chronicles/creator/stats', null),
        ],
        eagerError: false,
      );
      notifications = results[0] as Map<String, dynamic>;
      stats = results[1] as Map<String, dynamic>;
    } catch (e) {
      error = 'Counts unavailable';
      debugPrint('[LiveUpdates] signed-in fetch failed: $e');
    }

    // A signed-out phone (or a failed notifications call) still gets the
    // public latest post, so the widget is never an empty square.
    if (!notifications.containsKey('notifications')) {
      try {
        final feed = await _fetchMap('/chronicles/posts/feed', null);
        final posts = feed['posts'];
        if (posts is List) publicPosts = posts;
      } catch (e) {
        error ??= 'Latest posts unavailable';
        debugPrint('[LiveUpdates] public feed failed: $e');
      }
    }

    final snapshot = LiveUpdateSnapshot.fromSources(
      notifications: notifications,
      stats: stats,
      publicPosts: publicPosts,
      error: error,
    );
    await publish(snapshot);
    return snapshot;
  }

  bool _isProductionApi() {
    final uri = Uri.tryParse(AppConstants.baseUrl);
    return uri != null &&
        uri.isAbsolute &&
        uri.scheme == 'https' &&
        _productionHosts.contains(uri.host);
  }

  Future<Map<String, dynamic>> _fetchMap(
    String path,
    Map<String, dynamic>? query,
  ) async {
    final dynamic raw = await _api.get<dynamic>(path, queryParameters: query);
    if (raw is Map) {
      return raw.map(
        (dynamic key, dynamic value) => MapEntry<String, dynamic>(key.toString(), value),
      );
    }
    return <String, dynamic>{};
  }

  /// Persists first, then fans out to each surface independently so one
  /// unsupported platform cannot prevent the others from updating.
  Future<void> publish(LiveUpdateSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_snapshotKey, jsonEncode(snapshot.toJson()));

    if (kIsWeb) return;
    final payload = snapshot.toJson();
    if (Platform.isAndroid) {
      await _invoke('updateWidget', payload);
      await _showAndroidLiveNotification(snapshot);
    } else if (Platform.isIOS) {
      await _invoke('startLiveActivity', payload);
    }
  }

  Future<void> _invoke(String method, Map<String, dynamic> payload) async {
    try {
      await _channel.invokeMethod<dynamic>(method, payload);
    } catch (e) {
      debugPrint('[LiveUpdates] $method unavailable: $e');
    }
  }

  Future<void> _showAndroidLiveNotification(LiveUpdateSnapshot snapshot) async {
    try {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return;

      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          liveChannelId,
          liveChannelName,
          description: liveChannelDescription,
          importance: Importance.low,
        ),
      );

      await _notifications.show(
        liveNotificationId,
        liveChannelName,
        snapshot.liveNotificationBody,
        NotificationDetails(
          android: AndroidNotificationDetails(
            liveChannelId,
            liveChannelName,
            channelDescription: liveChannelDescription,
            channelAction: AndroidNotificationChannelAction.update,
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            showWhen: true,
            icon: 'ic_whispr_notification',
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
            color: const Color.fromARGB(255, 192, 0, 0),
            // Show the live status directly on the lock screen so the ongoing
            // notification works as the lock-screen widget surface.
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.status,
          ),
        ),
        payload: snapshot.latestLink,
      );
    } catch (e) {
      debugPrint('[LiveUpdates] live notification failed: $e');
    }
  }

  Future<void> stop() async {
    if (kIsWeb) return;
    try {
      await _notifications.cancel(liveNotificationId);
    } catch (e) {
      debugPrint('[LiveUpdates] failed to cancel live notification: $e');
    }
    if (Platform.isIOS) {
      await _invoke('endLiveActivity', const <String, dynamic>{});
    }
  }
}

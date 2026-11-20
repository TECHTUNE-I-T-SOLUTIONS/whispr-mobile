import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;

import '../network/api_service.dart';
import '../router/notification_router.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final ApiService _apiService = ApiService.instance;
  String? _subscriptionEndpoint;

  /// True once [Firebase.initializeApp] succeeded. Stays false when the app is
  /// built without `google-services.json` / `GoogleService-Info.plist`, in which
  /// case only local scheduled notifications are available.
  bool _firebaseReady = false;
  bool get remotePushAvailable => _firebaseReady;
  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  StreamSubscription<String>? _tokenRefreshSub;
String? _subscribedAccountId;
Future<void>? _subscribeInFlight;

  static const int dailyChallengeNotificationId = 7001;
  static const int dailyChallengeSnoozeId = 7002;
  static const String dailyChallengePayload = 'whispr://daily-challenge';
  static const String homePayload = 'whispr://app/home';
  static const String notificationsPayload = 'whispr://app/notifications';
  static const String loginPayload = 'whispr://login';

  static const String generalChannelId = 'whispr_channel';
  static const String generalChannelName = 'Whispr Notifications';
  static const String generalChannelDescription = 'Likes, comments and new posts from Whispr';
  static const String dailyChannelId = 'whispr_daily';
  static const String dailyChannelName = 'Daily Challenge';
  static const String dailyChannelDescription = 'Daily writing prompts and entry reminders';

  static const String openActionId = 'whispr_open';
  static const String snoozeActionId = 'whispr_snooze';

  Future<void> initialize() async {
    // Timezone data is required before any zoned_schedule call below.
    if (!kIsWeb) {
      tzdata.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Africa/Lagos'));
      } catch (_) {
        // Fall back to the package default (UTC) if the zone name is missing.
      }
    }

    // Android renders the small notification icon as a monochrome silhouette,
    // so it must be the white-on-transparent brand mark. The coloured launcher
    // icon is supplied separately as the large icon on each notification.
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('ic_whispr_notification');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const LinuxInitializationSettings linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      linux: linuxSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _handleNotificationResponse,
    );

    // Declare channels up front so FCM's default channel and local channels
    // share one identity; otherwise pushes land in an unmanaged FCM channel.
    await _configureChannels();

    // Request permissions. Platform is a dart:io shim on web that throws when
    // read, so it must stay behind kIsWeb.
    if (!kIsWeb) {
      if (Platform.isIOS) {
        await _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      } else if (Platform.isAndroid) {
        await _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      }
    }

    // For web, we'll handle VAPID key setup separately
    if (kIsWeb) {
      await _setupWebPush();
    } else {
      await _initializeFcm();
    }
  }

  Future<void> _configureChannels() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final android = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        generalChannelId,
        generalChannelName,
        description: generalChannelDescription,
        importance: Importance.high,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        dailyChannelId,
        dailyChannelName,
        description: dailyChannelDescription,
        importance: Importance.high,
      ),
    );
  }

  /// Boots Firebase Cloud Messaging. Safe to call when Firebase is not
  /// configured: the platform throws and we log, leaving [_firebaseReady] false
  /// so the rest of the app keeps using local notifications.
  Future<void> _initializeFcm() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseReady = true;
    } catch (e) {
      debugPrint('FCM unavailable (no Firebase config bundled): $e');
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FCM permission denied by user');
        return;
      }

      // iOS delivers pushes silently until the APNs token is attached.
      if (Platform.isIOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      _fcmToken = await messaging.getToken();
      if (_fcmToken != null) {
        await _registerToken(_fcmToken!);
      }

      _tokenRefreshSub = messaging.onTokenRefresh.listen((token) async {
        _fcmToken = token;
        await _registerToken(token);
      });

      // Foreground: Android does not show a notification for FCM messages, so
      // render it through the local plugin instead. Data-only messages still
      // carry the link that tells us where a tap should go.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final data = message.data;
        final payload = data['link'] as String? ?? data['payload'] as String?;
        if (notification == null && payload == null && data.isEmpty) return;
        showLocalNotification(
          title: notification?.title ?? data['title']?.toString() ?? 'Whispr',
          body: notification?.body ?? data['body']?.toString() ?? 'You have a new Whispr notification.',
          payload: payload,
        );
      });

      // Background -> foreground tap.
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _routeFromData(message.data);
      });

      // App opened from terminated state.
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _routeFromData(initialMessage.data);
      }
    } catch (e) {
      debugPrint('FCM setup failed after init: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      // `platform` lets the backend reason about delivery without guessing,
      // and the server rejects unknown values rather than trusting them.
      String platform = 'unknown';
      if (kIsWeb) {
        platform = 'web';
      } else if (Platform.isAndroid) {
        platform = 'android';
      } else if (Platform.isIOS) {
        platform = 'ios';
      }

      await _apiService.post('/push/fcm-token', data: {
        'token': token,
        'platform': platform,
      });
      debugPrint('FCM token registered with server');
    } catch (e) {
      // Non-fatal: the token retries on next refresh or app launch.
      debugPrint('Failed to register FCM token: $e');
    }
  }

  void _routeFromData(Map<String, dynamic> data) {
    final link = data['link'] as String? ?? data['payload'] as String?;
    if (link != null && link.isNotEmpty) {
      NotificationRouter.handle(link);
    }
  }

  Future<void> disposeFcm() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }

  /// Deactivates this device's token on the server so a signed-out phone stops
  /// receiving the previous account's notifications.
  ///
  /// Must be called *before* the Supabase session is cleared — the endpoint
  /// authenticates with the access token, so once it is gone this is a 401.
  /// Never throws: failing to unregister must not block sign-out.
  Future<void> unregisterToken() async {
    if (kIsWeb) return;
    final token = _fcmToken;
    if (token == null || token.isEmpty) return;

    try {
      await _apiService.delete('/push/fcm-token', data: {'token': token});
      debugPrint('FCM token unregistered');
    } catch (e) {
      debugPrint('Failed to unregister FCM token: $e');
    } finally {
      _fcmToken = null;
 _subscribedAccountId = null;
    }
  }

  Future<void> _setupWebPush() async {
    if (!kIsWeb) return;

    try {
      // Check if already subscribed
      final prefs = await SharedPreferences.getInstance();
      final subscriptionData = prefs.getString('push_subscription');
      if (subscriptionData != null) {
        final subscription = jsonDecode(subscriptionData);
        _subscriptionEndpoint = subscription['endpoint'];
      }

      debugPrint('Web push setup completed with VAPID key');
    } catch (e) {
      debugPrint('Failed to setup web push: $e');
    }
  }

  /// Subscribes this device once per account. A second account unregisters the
/// old token first; a repeated call for the same account is a no-op.
Future<void> subscribeOnceForAccount(String accountId) async {
 if (accountId.isEmpty) return;
 if (_subscribedAccountId == accountId) return;

 final inFlight = _subscribeInFlight;
 if (inFlight != null) {
 await inFlight;
 if (_subscribedAccountId == accountId) return;
 }

 final future = () async {
 if (_subscribedAccountId != null && _subscribedAccountId != accountId) {
 await unregisterToken();
 }
 await subscribeToPushNotifications();
 _subscribedAccountId = accountId;
 }();
 _subscribeInFlight = future;
 try {
 await future;
 } finally {
 if (identical(_subscribeInFlight, future)) _subscribeInFlight = null;
 }
}

Future<void> subscribeToPushNotifications() async {
    if (kIsWeb) {
      await _subscribeWebPush();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notifications_enabled', true);

    if (!_firebaseReady) {
      await _initializeFcm();
    }
    if (_fcmToken != null) {
      await _registerToken(_fcmToken!);
    }
  }

  Future<void> _subscribeWebPush() async {
    if (!kIsWeb) return;

    try {
      // For web, we'll use a simpler approach and store the subscription intent
      // The actual subscription will be handled by the web app's service worker
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('push_notifications_enabled', true);

      // Send subscription request to server (will be handled by web app)
      await _apiService.post('/push/subscription', data: {
        'userAgent': html.window.navigator.userAgent,
        'subscription': {'web': true}, // Placeholder for web subscription
      });

      debugPrint('Web push notifications enabled');
    } catch (e) {
      debugPrint('Failed to enable web push: $e');
    }
  }

  Future<void> unsubscribeFromPushNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notifications_enabled', false);

    if (kIsWeb && _subscriptionEndpoint != null) {
      try {
        final serviceWorker = html.window.navigator.serviceWorker;
        if (serviceWorker != null) {
          final registration = await serviceWorker.getRegistration();
          final subscription = await registration.pushManager?.getSubscription();
          if (subscription != null) {
            await subscription.unsubscribe();
          }
        }
      } catch (e) {
        debugPrint('Failed to unsubscribe from web push: $e');
      }
    }
  }

  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('push_notifications_enabled') ?? false;
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        generalChannelId,
        generalChannelName,
        channelDescription: generalChannelDescription,
        channelAction: AndroidNotificationChannelAction.update,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        // Status-bar silhouette (white on transparent).
        icon: 'ic_whispr_notification',
        // Full-colour brand mark shown in the expanded notification.
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        color: const Color.fromARGB(255, 192, 0, 0),
      );

      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to show notification with custom icon: $e');
      // Fallback: show notification without custom icon
      try {
        final androidDetailsFallback = AndroidNotificationDetails(
          generalChannelId,
          generalChannelName,
          channelDescription: generalChannelDescription,
          channelAction: AndroidNotificationChannelAction.update,
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
          color: const Color.fromARGB(255, 192, 0, 0),
        );

        final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

        final NotificationDetails detailsFallback = NotificationDetails(
          android: androidDetailsFallback,
          iOS: iosDetails,
        );

        await _flutterLocalNotificationsPlugin.show(
          id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title,
          body,
          detailsFallback,
          payload: payload,
        );
        debugPrint('Notification showed with fallback (no custom icon)');
      } catch (fallbackError) {
        debugPrint('Failed to show notification even with fallback: $fallbackError');
      }
    }
  }

  // Authentication notifications
  Future<void> sendTestNotification() async {
    await showLocalNotification(
      title: 'Test Notification',
      body: 'This is a test push notification from Whispr!',
      payload: homePayload,
    );
  }

  Future<void> showLoginSuccessNotification() async {
    await showLocalNotification(
      title: 'Welcome back!',
      body: 'You have successfully logged in to Whispr.',
      payload: homePayload,
    );
  }

  Future<void> showSignupSuccessNotification() async {
    await showLocalNotification(
      title: 'Welcome to Whispr!',
      body: 'Your account has been created successfully.',
      payload: homePayload,
    );
  }

  Future<void> showPasswordResetNotification() async {
    await showLocalNotification(
      title: 'Password Reset',
      body: 'Your password has been reset successfully.',
      payload: loginPayload,
    );
  }

  Future<void> showLogoutNotification() async {
    await showLocalNotification(
      title: 'Signed Out',
      body: 'You have been signed out from Whispr.',
      payload: loginPayload,
    );
  }

  Future<void> showSessionExpiredNotification() async {
    await showLocalNotification(
      title: 'Session Expired',
      body: 'Your session has expired. Please sign in again to continue.',
      payload: loginPayload,
    );
  }

  // Content notifications
  Future<void> showNewPostNotification(String authorName, String postType, {String? link}) async {
    await showLocalNotification(
      title: 'New $postType Posted',
      body: '$authorName just published a new $postType. Check it out!',
      payload: link ?? homePayload,
    );
  }

  Future<void> showNewChainNotification(String authorName, {String? link}) async {
    await showLocalNotification(
      title: 'New Writing Chain',
      body: '$authorName started a new writing chain. Join the conversation!',
      payload: link ?? 'whispr://app/writing-chains',
    );
  }

  // Engagement notifications
  Future<void> showLikeNotification(String likerName, String contentType, {String? link}) async {
    await showLocalNotification(
      title: 'New Like',
      body: '$likerName liked your $contentType.',
      payload: link ?? notificationsPayload,
    );
  }

  Future<void> showCommentNotification(String commenterName, String contentType, {String? link}) async {
    await showLocalNotification(
      title: 'New Comment',
      body: '$commenterName commented on your $contentType.',
      payload: link ?? notificationsPayload,
    );
  }

  Future<void> showChainEntryNotification(String authorName, String chainTitle, {String? link}) async {
    await showLocalNotification(
      title: 'New Chain Entry',
      body: '$authorName added to the writing chain "$chainTitle".',
      payload: link ?? notificationsPayload,
    );
  }

  // System notifications
  Future<void> showWelcomeNotification() async {
    await showLocalNotification(
      title: 'Welcome to Whispr',
      body: 'Start exploring amazing content from our creative community!',
      payload: homePayload,
    );
  }

  Future<void> showDailyReminderNotification() async {
    await showLocalNotification(
      title: 'Daily Writing Reminder',
      body: 'Don\'t forget to check out today\'s featured content and share your thoughts!',
      payload: dailyChallengePayload,
    );
  }

  // ---------------------------------------------------------------------------
  // Daily challenge reminders
  //
  // A scheduled local notification needs no server or Firebase project and
  // gives a real, testable daily nudge today; FCM can be layered on top later
  // without changing any of the call sites below.
  // ---------------------------------------------------------------------------

  /// Asks the OS for notification permission and returns whether it is granted.
  /// Called from the home screen's permission prompt, never on cold start.
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      return (await SharedPreferences.getInstance()).getBool('push_notifications_enabled') ?? false;
    }

    try {
      if (Platform.isIOS) {
        final granted = await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        if (granted ?? false) await _markEnabled(true);
        return granted ?? false;
      }

      if (Platform.isAndroid) {
        final android = _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final granted = await android?.requestNotificationsPermission() ?? false;
        if (granted) await _markEnabled(true);
        return granted;
      }
    } catch (e) {
      debugPrint('[PushNotifications] permission request failed: $e');
    }
    return false;
  }

  Future<void> _markEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notifications_enabled', enabled);
  }

  /// Schedules the daily "today's challenge is live" reminder.
  ///
  /// Cancels any previous reminder first, so changing the time in settings
  /// never leaves two notifications firing.
  Future<void> scheduleDailyChallengeReminder({
    int hour = 8,
    int minute = 0,
  }) async {
    if (kIsWeb) return;
    try {
      await _flutterLocalNotificationsPlugin.cancel(dailyChallengeNotificationId);

      final androidDetails = AndroidNotificationDetails(
        dailyChannelId,
        dailyChannelName,
        channelDescription: dailyChannelDescription,
        channelAction: AndroidNotificationChannelAction.update,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: 'ic_whispr_notification',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(openActionId, 'Open', showsUserInterface: true),
          AndroidNotificationAction(snoozeActionId, 'Snooze 10 min'),
        ],
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        dailyChallengeNotificationId,
        "Today's whisper is waiting",
        'A new writing challenge is live. Open Whispr and claim your streak.',
        _nextInstanceOf(hour, minute),
        NotificationDetails(android: androidDetails, iOS: darwinDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: dailyChallengePayload,
      );
      debugPrint('[PushNotifications] daily reminder scheduled for $hour:$minute');
    } catch (e) {
      debugPrint('[PushNotifications] failed to schedule daily reminder: $e');
    }
  }

  /// One-off nudge created by the notification's Snooze action. Kept on a
  /// separate id so cancelling the repeating reminder does not cancel it.
  Future<void> snoozeDailyChallengeReminder() async {
    if (kIsWeb) return;
    try {
      await _flutterLocalNotificationsPlugin.cancel(dailyChallengeSnoozeId);
      final androidDetails = AndroidNotificationDetails(
        dailyChannelId,
        dailyChannelName,
        channelDescription: dailyChannelDescription,
        channelAction: AndroidNotificationChannelAction.update,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: 'ic_whispr_notification',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(openActionId, 'Open', showsUserInterface: true),
          AndroidNotificationAction(snoozeActionId, 'Snooze 10 min'),
        ],
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        dailyChallengeSnoozeId,
        "Today's whisper is waiting",
        'Snoozed reminder: open Whispr and claim your streak.',
        tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10)),
        NotificationDetails(android: androidDetails, iOS: darwinDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: dailyChallengePayload,
      );
      debugPrint('[PushNotifications] daily reminder snoozed for 10 minutes');
    } catch (e) {
      debugPrint('[PushNotifications] failed to snooze daily reminder: $e');
    }
  }

  Future<void> cancelDailyChallengeReminder() async {
    if (kIsWeb) return;
    try {
      await _flutterLocalNotificationsPlugin.cancel(dailyChallengeNotificationId);
      await _flutterLocalNotificationsPlugin.cancel(dailyChallengeSnoozeId);
    } catch (e) {
      debugPrint('[PushNotifications] failed to cancel daily reminder: $e');
    }
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

/// Top-level so background action taps can invoke it after a cold start.
@pragma('vm:entry-point')
void _handleNotificationResponse(NotificationResponse response) {
  debugPrint('[PushNotifications] action=${response.actionId} payload=${response.payload}');
  if (response.actionId == PushNotificationService.snoozeActionId) {
    unawaited(PushNotificationService().snoozeDailyChallengeReminder());
    return;
  }
  NotificationRouter.handle(response.payload);
}

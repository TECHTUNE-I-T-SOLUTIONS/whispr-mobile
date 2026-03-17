import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;

import '../network/api_service.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final ApiService _apiService = ApiService.instance;
  String? _subscriptionEndpoint;

  Future<void> initialize() async {
    // Initialize local notifications with app launcher icon
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const LinuxInitializationSettings linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      linux: linuxSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions
    if (Platform.isIOS) {
      await _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    } else if (Platform.isAndroid) {
      await _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    }

    // For web, we'll handle VAPID key setup separately
    if (kIsWeb) {
      await _setupWebPush();
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

  Future<void> subscribeToPushNotifications() async {
    if (kIsWeb) {
      await _subscribeWebPush();
    } else {
      // For mobile, we'll use FCM or similar in the future
      // For now, just show local notifications
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
        'whispr_channel',
        'Whispr Notifications',
        channelDescription: 'Notifications from Whispr',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: 'ic_whispr_notification',
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
          'whispr_channel',
          'Whispr Notifications',
          channelDescription: 'Notifications from Whispr',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
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

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    // TODO: Navigate to appropriate screen based on payload
    debugPrint('Notification tapped: ${response.payload}');
  }

  Future<void> sendTestNotification() async {
    await showLocalNotification(
      title: 'Test Notification',
      body: 'This is a test push notification from Whispr!',
    );
  }

  // Authentication notifications
  Future<void> showLoginSuccessNotification() async {
    await showLocalNotification(
      title: 'Welcome back!',
      body: 'You have successfully logged in to Whispr.',
    );
  }

  Future<void> showSignupSuccessNotification() async {
    await showLocalNotification(
      title: 'Welcome to Whispr!',
      body: 'Your account has been created successfully.',
    );
  }

  Future<void> showPasswordResetNotification() async {
    await showLocalNotification(
      title: 'Password Reset',
      body: 'Your password has been reset successfully.',
    );
  }

  Future<void> showLogoutNotification() async {
    await showLocalNotification(
      title: 'Signed Out',
      body: 'You have been signed out from Whispr.',
    );
  }

  Future<void> showSessionExpiredNotification() async {
    await showLocalNotification(
      title: 'Session Expired',
      body: 'Your session has expired. Please sign in again to continue.',
    );
  }

  // Content notifications
  Future<void> showNewPostNotification(String authorName, String postType) async {
    await showLocalNotification(
      title: 'New $postType Posted',
      body: '$authorName just published a new $postType. Check it out!',
    );
  }

  Future<void> showNewChainNotification(String authorName) async {
    await showLocalNotification(
      title: 'New Writing Chain',
      body: '$authorName started a new writing chain. Join the conversation!',
    );
  }

  // Engagement notifications
  Future<void> showLikeNotification(String likerName, String contentType) async {
    await showLocalNotification(
      title: 'New Like',
      body: '$likerName liked your $contentType.',
    );
  }

  Future<void> showCommentNotification(String commenterName, String contentType) async {
    await showLocalNotification(
      title: 'New Comment',
      body: '$commenterName commented on your $contentType.',
    );
  }

  Future<void> showChainEntryNotification(String authorName, String chainTitle) async {
    await showLocalNotification(
      title: 'New Chain Entry',
      body: '$authorName added to the writing chain "$chainTitle".',
    );
  }

  // System notifications
  Future<void> showWelcomeNotification() async {
    await showLocalNotification(
      title: 'Welcome to Whispr',
      body: 'Start exploring amazing content from our creative community!',
    );
  }

  Future<void> showDailyReminderNotification() async {
    await showLocalNotification(
      title: 'Daily Writing Reminder',
      body: 'Don\'t forget to check out today\'s featured content and share your thoughts!',
    );
  }
}
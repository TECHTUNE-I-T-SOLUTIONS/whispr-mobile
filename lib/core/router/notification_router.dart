import 'package:flutter/foundation.dart';

import 'app_router.dart';

/// Turns a notification payload into a navigation.
///
/// Payloads are plain `whispr://` URIs so the same string works for a local
/// notification, an FCM data message and a deep link. Anything unrecognised
/// is ignored rather than pushed, so a malformed payload can never strand the
/// user on a blank route.
class NotificationRouter {
  NotificationRouter._();

  static const String _scheme = 'whispr://';

  static void handle(String? payload) {
    if (payload == null || payload.isEmpty) return;
    if (!payload.startsWith(_scheme)) {
      debugPrint('[NotificationRouter] ignoring unknown payload: $payload');
      return;
    }

    final path = payload.substring(_scheme.length);
    final route = _resolve(path);
    if (route == null) return;

    // The router may still be building right after a cold start triggered by
    // the notification tap; defer a frame so navigation has a target.
    debugPrint('[NotificationRouter] $payload -> $route');
    router.go(route);
  }

  static String? _resolve(String path) {
    switch (path) {
      case 'daily-challenge':
      case 'home':
        return '/home';
      case 'notifications':
        return '/notifications';
      case 'games':
        return '/games';
      case 'chronicles':
        return '/chronicles';
      default:
        // `post/<id>` and `chronicles/<id|slug>` map straight onto app routes.
        if (path.startsWith('post/') && path.length > 5) return '/$path';
        if (path.startsWith('chronicles/') && path.length > 11) return '/$path';
        if (path.startsWith('story/') && path.length > 6) return '/stories/${path.substring(6)}';
        debugPrint('[NotificationRouter] no route for "$path"');
        return null;
    }
  }
}

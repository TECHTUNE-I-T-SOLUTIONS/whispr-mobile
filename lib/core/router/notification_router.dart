import 'package:flutter/foundation.dart';

import '../services/deep_link_service.dart';

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

    var path = payload.substring(_scheme.length);
    // Share links and push payloads both use `whispr://app/<type>/<id>`; the
    // bare `whispr://<type>/<id>` form is still supported.
    if (path.startsWith('app/')) path = path.substring(4);
    final route = _resolve(path);
    if (route == null) return;

    // A tap can launch a cold app. Hand the route to DeepLinkService so it
    // waits for the splash screen to restore auth, exactly like a share link.
    debugPrint('[NotificationRouter] $payload -> $route');
    DeepLinkService.instance.handleRoute(route);
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
      case 'writing-chains':
        return '/writing-chains';
      case 'stories':
        return '/stories';
      case 'login':
        return '/login';
      default:
        // `post/<id>` and `chronicles/<id|slug>` map straight onto app routes.
        if (path.startsWith('post/') && path.length > 5) return '/$path';
        if (path.startsWith('chronicles/') && path.length > 11) return '/$path';
        if (path.startsWith('story/') && path.length > 6) {
          return '/stories/${path.substring(6)}';
        }
        debugPrint('[NotificationRouter] no route for "$path"');
        return null;
    }
  }
}

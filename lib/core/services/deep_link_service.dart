import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../router/app_router.dart';

/// Routes incoming links (`whispr://app/<type>/<id>` and the https share
/// links) to the screen they name.
///
/// Two arrival paths matter:
/// * Cold start — the link is what launched the process, so it is buffered
/// until the splash screen has restored the session. Navigating before
/// that would let the auth guard bounce a signed-in user to /login.
/// * Warm start — the activity is already up (`launchMode="singleTop"` hands
/// the link to `onNewIntent`), so it can be followed immediately.
class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  /// Set once the splash screen has finished restoring auth and navigating.
  bool _navigable = false;

  /// A link that arrived before the app was ready to route it.
  String? _pending;

  bool _started = false;

  /// Reads a link that launched the app, then follows every later one.
  Future<void> initialize() async {
    if (_started) return;
    _started = true;

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) handle(initial);
    } catch (e) {
      debugPrint('[DeepLink] initial link unavailable: $e');
    }

    try {
      _subscription = _appLinks.uriLinkStream.listen(
        handle,
        onError: (Object e) => debugPrint('[DeepLink] stream error: $e'),
      );
    } catch (e) {
      debugPrint('[DeepLink] could not subscribe to links: $e');
    }
  }

  /// Stops following links. Only used by tests; the app keeps the
  /// subscription for its whole lifetime.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }

  /// Called by the splash screen once the first route is safe to change.
  void markAppReady() {
    _navigable = true;
  }

  /// The buffered cold-start link, if any. Clears it.
  String? takePendingRoute() {
    final route = _pending;
    _pending = null;
    return route;
  }

  /// Public entry point for an incoming URI (deep link or shortcut).
  void handle(Uri uri) {
    final route = _routeFor(uri);
    if (route == null) {
      debugPrint('[DeepLink] ignored: $uri');
      return;
    }
    debugPrint('[DeepLink] $uri -> $route');
    handleRoute(route);
  }

  /// Follows an already-resolved app route, buffering it until splash is
  /// ready. Notification taps use this path so a cold-start tap cannot race
  /// the auth restore and get bounced to /login.
  void handleRoute(String route) {
    if (_navigable) {
      router.go(route);
    } else {
      _pending = route;
    }
  }

  /// The app path a link points at, or null when it is not ours.
  ///
  /// `whispr://app/chronicle/42` arrives with the host carrying `app` and the
  /// real path in the segments; go_router matches on the path only, so the
  /// segments are all that is kept here. Aliases (`chronicle` → `chronicles`)
  /// are resolved by the router's own redirect.
  String? _routeFor(Uri uri) {
    if (uri.scheme == 'whispr') {
      // `whispr://app/...` parses to host `app`, `whispr://<type>/...` parses
      // to host `<type>` — take both spellings into the path.
      final segments = <String>[
        if (uri.host.isNotEmpty && uri.host != 'app') uri.host,
        ...uri.pathSegments,
      ];
      if (segments.isEmpty) return null;
      return '/${segments.join('/')}';
    }

    if (uri.scheme == 'https' || uri.scheme == 'http') {
      if (uri.path.isEmpty || uri.path == '/') return null;
      return uri.path;
    }

    return null;
  }
}

import 'package:flutter/material.dart';

import 'app_router.dart';
import 'navigation_keys.dart';

/// Handles Android system back when GoRouter has nothing left to pop.
///
/// GoRouter's delegate returns false at the root of a `ShellRoute`, which lets
/// the platform finish the activity. Normal in-app history is still handled by
/// the delegate; this dispatcher only supplies a destination for those root
/// states, so the back button cannot close Whispr unexpectedly.
class AppBackButtonDispatcher extends RootBackButtonDispatcher {
 AppBackButtonDispatcher();

 static DateTime? _lastBackPress;

 @override
 Future<bool> didPopRoute() async {
 final handled = await super.didPopRoute();
 if (handled) return true;

 final path = router.routerDelegate.currentConfiguration.uri.path;
 if (_isAuthRoute(path)) {
 // Login and splash are legitimate exit points.
 return false;
 }

 if (path == '/home') {
 final now = DateTime.now();
 final shouldExit =
 _lastBackPress != null && now.difference(_lastBackPress!) < const Duration(seconds: 2);
 _lastBackPress = now;
 if (shouldExit) return false;
 _showLeaveHint();
 return true;
 }

 // Any other route with no in-app history returns to the main tab.
 router.go('/home');
 return true;
 }

 static bool _isAuthRoute(String path) =>
 path == '/login' ||
 path == '/signup' ||
 path == '/splash' ||
 path == '/onboarding' ||
 path == '/forgot-password';

 static void _showLeaveHint() {
 final context = shellNavigatorKey.currentContext;
 if (context == null || !context.mounted) return;
 ScaffoldMessenger.of(context)
 ..hideCurrentSnackBar()
 ..showSnackBar(
 const SnackBar(
 content: Text('Press back again to leave Whispr'),
 duration: Duration(seconds: 2),
 ),
 );
 }
}

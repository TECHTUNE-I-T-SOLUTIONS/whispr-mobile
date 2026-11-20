import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Keeps the Android system back button inside the app.
///
/// Screens outside the tab shell (AI chat, premium, creator studio, a creator
/// profile) used to have no back handler at all, so the first back press
/// closed the app. The navigator that hosts the route owns the pop when there
/// is history; this guard only supplies a destination when there is none.
class BackGuard extends StatelessWidget {
final Widget child;

const BackGuard({super.key, required this.child});

@override
Widget build(BuildContext context) {
final router = GoRouter.of(context);
final navigator = Navigator.of(context);
return PopScope(
// Never let the default pop finish the Flutter activity: these routes sit
// in the root navigator, where that would exit the app.
canPop: false,
onPopInvokedWithResult: (didPop, result) {
if (didPop) return;
if (navigator.canPop()) {
navigator.pop();
return;
}
// No navigator history (for example a deep link landed here directly).
router.go('/home');
},
child: child,
);
}
}

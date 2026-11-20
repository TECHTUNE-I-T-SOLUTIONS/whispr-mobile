import 'package:flutter/widgets.dart';

/// Navigator that owns the tab shell's branch routes.
///
/// Back handling needs the *branch* navigator, not GoRouter's overall stack:
/// the shell itself lives in the root navigator, so popping from there exits
/// the activity instead of returning from a pushed screen.
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

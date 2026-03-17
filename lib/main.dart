import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/session_manager.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/supabase_auth_provider.dart';
import 'features/theme/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://vkftywhuaxwbknlrymnr.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZrZnR5d2h1YXh3YmtubHJ5bW5yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA4MDU4MzksImV4cCI6MjA2NjM4MTgzOX0.FSPBORGCJEQQAQKGC5c-VHAdt3Zlm1CQ1YexYuKDATY',
  );

  // Push notifications removed for now

  runApp(const ProviderScope(child: WhisprApp()));
}

class WhisprApp extends ConsumerStatefulWidget {
  const WhisprApp({super.key});

  @override
  ConsumerState<WhisprApp> createState() => _WhisprAppState();
}

class _WhisprAppState extends ConsumerState<WhisprApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SessionManager().initializeSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App came back to foreground, check session
        SessionManager().checkAndHandleSessionExpiration();
        SessionManager().updateSessionActivity();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        // App went to background
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Whispr - Share Your Stories',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}


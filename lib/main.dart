import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/router/app_back_dispatcher.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/session_scope.dart';
import 'features/theme/theme_provider.dart';

final appBackButtonDispatcher = AppBackButtonDispatcher();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env and .env.local (build secret keys).
  // If neither file is present, continue with defaults for dev/test.
  await dotenv.load(fileName: '.env', isOptional: true);
  await dotenv.load(fileName: '.env.local', isOptional: true);

  await Supabase.initialize(
    url: 'https://vkftywhuaxwbknlrymnr.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZrZnR5d2h1YXh3YmtubHJ5bW5yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA4MDU4MzksImV4cCI6MjA2NjM4MTgzOX0.FSPBORGCJEQQAQKGC5c-VHAdt3Zlm1CQ1YexYuKDATY',
  );

  // Prepare the notification plugin before the first frame so a tap that
  // launched the app can still be routed. Permission is asked later, from the
  // home screen, once the user has seen what the app is for.
  try {
    await PushNotificationService().initialize();
  } catch (e) {
    debugPrint('[main] notification init failed: $e');
  }

  // A link that launched the app has to be captured before the first frame,
  // otherwise Android hands it over only when the activity is already up and
  // the destination is lost. The route itself waits for the splash screen.
  try {
    await DeepLinkService.instance.initialize();
  } catch (e) {
    debugPrint('[main] deep link init failed: $e');
  }

  // Session restore, API setup and live updates are owned by SessionScope.
  runApp(const ProviderScope(child: SessionScope(child: WhisprApp())));
}

class WhisprApp extends ConsumerStatefulWidget {
  const WhisprApp({super.key});

  @override
  ConsumerState<WhisprApp> createState() => _WhisprAppState();
}

class _WhisprAppState extends ConsumerState<WhisprApp> {
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Whispr',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routeInformationProvider: router.routeInformationProvider,
 routeInformationParser: router.routeInformationParser,
 routerDelegate: router.routerDelegate,
 backButtonDispatcher: appBackButtonDispatcher,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Stop the OS from scaling body text past a readable ceiling; the old
        // build let a 2x accessibility setting break card layouts.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler:
                media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.35),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

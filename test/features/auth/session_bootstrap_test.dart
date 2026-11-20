import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whispr/core/services/auth_session_store.dart';
import 'package:whispr/core/services/session_bootstrap.dart';
import 'package:whispr/features/auth/presentation/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('splash awaits the overridden bootstrap without restoring storage',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    final testRouter = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const SplashScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const Text('onboarding-placeholder'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionBootstrapProvider.overrideWith(
            (ref) => Future<AuthSessionData?>.value(null),
          ),
        ],
        child: MaterialApp.router(routerConfig: testRouter),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('onboarding-placeholder'), findsOneWidget);
    // If SplashScreen still restored storage itself, this would be true.
    expect(AuthSessionStore.isRestored, isFalse);
  });
}

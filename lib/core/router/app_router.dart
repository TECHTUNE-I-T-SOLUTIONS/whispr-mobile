import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/chronicles/presentation/chronicles_screen.dart';
import '../../features/chronicles/presentation/create_chronicles_post_screen.dart';
import '../../features/whispr_wall/presentation/whispr_wall_screen.dart';
import '../../features/writing_chains/presentation/writing_chains_screen.dart';
import '../../features/writing_chains/presentation/create_chain_screen.dart';
import '../../features/writing_chains/presentation/chain_entries_screen.dart';
import '../../features/writing_chains/presentation/create_chain_entry_screen.dart';
import '../../features/writing_chains/presentation/edit_chain_entry_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/profile_details_screen.dart';
import '../../features/premium/presentation/premium_screen.dart';
import '../../features/spoken_words/presentation/spoken_words_screen.dart';
import '../../shared/widgets/main_layout.dart';
import '../../shared/widgets/post_detail_screen.dart';
import '../../shared/widgets/creator_profile_screen.dart';
import '../utils/auth_guard.dart';

final router = GoRouter(
  initialLocation: '/splash',
  routes: [
    // Splash and Onboarding
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),

    // Auth routes
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),

    // Main app with bottom navigation
    ShellRoute(
      builder: (context, state, child) => MainLayout(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/chronicles',
          builder: (context, state) => const ChroniclesScreen(),
        ),
        GoRoute(
          path: '/chronicles/create',
          builder: (context, state) => const CreateChroniclesPostScreen(),
        ),
        GoRoute(
          path: '/whispr-wall',
          builder: (context, state) => const WhisprWallScreen(),
        ),
        GoRoute(
          path: '/spoken-words',
          builder: (context, state) => const SpokenWordsScreen(),
        ),
        GoRoute(
          path: '/writing-chains',
          builder: (context, state) => const WritingChainsScreen(),
        ),
        GoRoute(
          path: '/writing-chains/create',
          builder: (context, state) => const CreateChainScreen(),
        ),
        GoRoute(
          path: '/writing-chains/:chainId',
          builder: (context, state) {
            final chainId = state.pathParameters['chainId']!;
            return ChainEntriesScreen(chainId: chainId);
          },
          routes: [
            GoRoute(
              path: 'create-entry',
              builder: (context, state) {
                final chainId = state.pathParameters['chainId']!;
                final chainTitle = state.extra as String?;
                return CreateChainEntryScreen(
                  chainId: chainId,
                  chainTitle: chainTitle,
                );
              },
            ),
            GoRoute(
              path: 'edit-entry/:entryId',
              builder: (context, state) {
                final chainId = state.pathParameters['chainId']!;
                final entryId = state.pathParameters['entryId']!;
                final extra = state.extra as Map<String, dynamic>?;
                return EditChainEntryScreen(
                  chainId: chainId,
                  entryId: entryId,
                  chainTitle: extra?['chainTitle'] as String?,
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/more',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/profile-details',
          builder: (context, state) => const ProfileDetailsScreen(),
        ),
        // Post details
        GoRoute(
          path: '/post/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return PostDetailScreen(postId: id);
          },
        ),
      ],
    ),

    // Premium
    GoRoute(
      path: '/premium',
      builder: (context, state) => const PremiumScreen(),
    ),

    // Creator profile
    GoRoute(
      path: '/creator/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return CreatorProfileScreen(creatorId: id);
      },
    ),
  ],
  redirect: (context, state) async {
    final isLoggedIn = await AuthGuard.isLoggedIn();
    final isAuthRoute = state.matchedLocation.startsWith('/login') ||
                       state.matchedLocation.startsWith('/signup') ||
                       state.matchedLocation == '/splash' ||
                       state.matchedLocation == '/onboarding' ||
                       state.matchedLocation == '/forgot-password';

    // Allow access to main browsing routes even when not logged in
    final isPublicRoute = state.matchedLocation == '/home' ||
                         state.matchedLocation == '/chronicles' ||
                         state.matchedLocation == '/whispr-wall' ||
                         state.matchedLocation == '/notifications';

    if (!isLoggedIn && !isAuthRoute && !isPublicRoute) {
      return '/login';
    }

    if (isLoggedIn && isAuthRoute && state.matchedLocation != '/splash') {
      return '/home';
    }

    return null;
  },
);
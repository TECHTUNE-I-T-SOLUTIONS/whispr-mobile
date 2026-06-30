import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/chronicles/presentation/chronicles_screen.dart';
import '../../features/chronicles/presentation/create_chronicles_post_screen.dart';
import '../../features/chronicles/presentation/chronicles_post_detail_screen.dart';
import '../../features/ai_chat/presentation/ai_chat_screen.dart';
import '../../features/whispr_wall/presentation/whispr_wall_screen.dart';
import '../../features/writing_chains/presentation/writing_chains_screen.dart';
import '../../features/writing_chains/presentation/create_chain_screen.dart';
import '../../features/writing_chains/presentation/chain_entries_screen.dart';
import '../../features/writing_chains/presentation/create_chain_entry_screen.dart';
import '../../features/writing_chains/presentation/edit_chain_entry_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/games/presentation/games_screen.dart';
import '../../features/games/presentation/game_profile_screen.dart';
import '../../features/guides/presentation/guides_screen.dart';
import '../../features/guides/presentation/guide_detail_screen.dart';
import '../../features/profile/presentation/reviews_screen.dart';
import '../../features/portfolio/presentation/portfolio_screen.dart';
import '../../features/games/presentation/game_play_screen.dart';
import '../../features/games/presentation/educational_game_play_screen.dart';
import '../../features/stories/presentation/stories_screen.dart';
import '../../features/stories/presentation/story_detail_screen.dart';
import '../../features/stories/presentation/create_story_screen.dart';
import '../../features/profile/presentation/profile_details_screen.dart';
import '../../features/profile/presentation/review_detail_screen.dart';
import '../../features/premium/presentation/premium_screen.dart';
import '../../features/spoken_words/presentation/spoken_words_screen.dart';
import '../../shared/widgets/main_layout.dart';
import '../../shared/widgets/post_detail_screen.dart';
import '../../shared/widgets/creator_profile_screen.dart';
import '../utils/auth_guard.dart';

final router = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) async {
    final location = state.matchedLocation;

    // If the location is exactly '/', redirect to splash
    if (location == '/') {
      return '/splash';
    }

    final isLoggedIn = await AuthGuard.isLoggedIn();
    final isAuthRoute = location.startsWith('/login') ||
                        location.startsWith('/signup') ||
                        location == '/splash' ||
                        location == '/onboarding' ||
                        location == '/forgot-password';

    // Allow access to main browsing routes even when not logged in
    final isPublicRoute = location == '/home' ||
                          location == '/chronicles' ||
                          location == '/whispr-wall' ||
                          location == '/notifications' ||
                          location == '/games' ||
                          location == '/guides' ||
                          location == '/stories' ||
                          location.startsWith('/stories/') ||
                          location.startsWith('/post/') ||
                          location.startsWith('/chronicles/') ||
                          location.startsWith('/creator/') ||
                          location.startsWith('/portfolio/') ||
                          location.startsWith('/guides/') ||
                          location.startsWith('/games/');

    if (!isLoggedIn && !isAuthRoute && !isPublicRoute) {
      return '/login';
    }

    if (isLoggedIn && isAuthRoute && location != '/splash') {
      return '/home';
    }

    return null;
  },
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
    // Root route - redirect to splash
    GoRoute(
      path: '/',
      redirect: (context, state) => '/splash',
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
          path: '/chains/:chainId',
          builder: (context, state) {
            final chainId = state.pathParameters['chainId']!;
            final chainTitle = state.uri.queryParameters['title'];
            return ChainEntriesScreen(chainId: chainId, chainTitle: chainTitle);
          },
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
          path: '/games',
          builder: (context, state) => const GamesScreen(),
        ),
        GoRoute(
          path: '/games/profile',
          builder: (context, state) => const GameProfileScreen(),
        ),
        GoRoute(
          path: '/games/play',
          builder: (context, state) => GamePlayScreen(game: state.extra as Map<String, dynamic>),
        ),
        GoRoute(
          path: '/games/educational-play',
          builder: (context, state) => EducationalGamePlayScreen(game: state.extra as Map<String, dynamic>),
        ),
        GoRoute(
          path: '/stories',
          builder: (context, state) => const StoriesScreen(),
        ),
        GoRoute(
          path: '/stories/create',
          builder: (context, state) => const CreateStoryScreen(),
        ),
        GoRoute(
          path: '/stories/:slug',
          builder: (context, state) {
            final slug = state.pathParameters['slug']!;
            return StoryDetailScreen(storySlug: slug);
          },
          routes: [
            GoRoute(
              path: 'chapter/:chapterSlug',
              builder: (context, state) {
                final slug = state.pathParameters['slug']!;
                final chapterSlug = state.pathParameters['chapterSlug']!;
                return StoryDetailScreen(storySlug: slug, chapterSlug: chapterSlug);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/guides',
          builder: (context, state) => const GuidesScreen(),
        ),
        GoRoute(
          path: '/guides/:moduleId',
          builder: (context, state) => GuideDetailScreen(moduleId: state.pathParameters['moduleId']!),
        ),
        GoRoute(
          path: '/portfolio/:penName',
          builder: (context, state) => PortfolioScreen(penName: state.pathParameters['penName']!),
        ),
        GoRoute(
          path: '/profile-details',
          builder: (context, state) => const ProfileDetailsScreen(),
        ),
        GoRoute(
          path: '/reviews',
          builder: (context, state) => const ReviewsScreen(),
        ),
        GoRoute(
          path: '/reviews/detail',
          builder: (context, state) => ReviewDetailScreen(post: state.extra as Map<String, dynamic>),
        ),
        // Post details
        GoRoute(
          path: '/post/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return PostDetailScreen(postId: id);
          },
        ),
        // Chronicles post details - supports both deep link formats (slug or id)
        GoRoute(
          path: '/chronicles/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            // Detect if it's a slug (contains non-numeric characters) or UUID
            final isSlug = !RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(id) &&
                          !RegExp(r'^\d+$').hasMatch(id);
            return ChroniclesPostDetailScreen(postId: id, isSlug: isSlug);
          },
        ),
      ],
    ),

    // AI Chat (new)
    GoRoute(
      path: '/ai-chat',
      builder: (context, state) => const AiChatScreen(),
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
);
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/chronicles/presentation/chronicle_categories_screen.dart';
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
import '../../features/creator/presentation/creator_dashboard_screen.dart';
import '../../features/creator/presentation/creator_settings_screen.dart';
import '../../features/games/presentation/game_play_screen.dart';
import '../../features/games/presentation/educational_game_play_screen.dart';
import '../../features/stories/presentation/stories_screen.dart';
import '../../features/stories/presentation/story_detail_screen.dart';
import '../../features/stories/presentation/create_story_screen.dart';
import '../../features/stories/presentation/my_stories_screen.dart';
import '../../features/stories/presentation/manage_chapters_screen.dart';
import '../../features/profile/presentation/profile_details_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/review_detail_screen.dart';
import '../../features/premium/presentation/premium_screen.dart';
import '../../features/spoken_words/presentation/spoken_words_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../shared/widgets/back_guard.dart';
import '../../shared/widgets/main_layout.dart';
import '../../shared/widgets/route_error_screen.dart';
import '../../shared/widgets/post_detail_screen.dart';
import '../../shared/widgets/creator_profile_screen.dart';
import '../utils/auth_guard.dart';
import 'navigation_keys.dart';

/// Maps a custom-scheme deep link onto a real app route.
///
/// Share links open the app as `whispr://app/<type>/<id>`. The router matches
/// on the *path* part, and older links (and hand-typed ones) use singular
/// types, so `whispr://app/chronicle/<id>` arrived as `/chronicle/<id>` — no
/// such route — and dropped the user on the not-found page. Normalising the
/// first segment here means a shared link always lands on the content.
String? _normalizeDeepLink(Uri uri) {
  const aliases = <String, String>{
    'chronicle': 'chronicles',
    'story': 'stories',
    'writing-chain': 'writing-chains',
    'creator-studio': 'creator/studio',
  };

  var segments = uri.pathSegments.toList();
  if (segments.isEmpty) return null;

  // The web resolver serves share links as `https://…/r/<type>/<id>`; opening
  // one inside the app (App Links, or the link already in the clipboard) keeps
  // that `/r` segment, so drop it before matching.
  if (segments.length > 1 && (segments.first == 'r' || segments.first == 'app')) {
    segments = segments.sublist(1);
  }

  // `whispr://app/<type>/<id>` and `whispr://<type>/<id>` both put the type
  // first in the path, so there is nothing to strip — only to rename.
  final alias = aliases[segments.first];
  if (alias == null) return null;

  segments = [...alias.split('/'), ...segments.skip(1)];
  return '/${segments.join('/')}';
}

final router = GoRouter(
  initialLocation: '/splash',
 refreshListenable: AuthGuard.signedIn,
  errorBuilder: (context, state) => RouteErrorScreen(location: state.uri.toString()),
  redirect: (context, state) async {
    final location = state.matchedLocation;

    // If the location is exactly '/', redirect to splash
    if (location == '/') {
      return '/splash';
    }

    final normalized = _normalizeDeepLink(state.uri);
    if (normalized != null && normalized != location) {
      return normalized;
    }

    // Never redirect while the session is still being read from storage — a
    // returning user must not be bounced to /login for the half second the
    // restore takes. Splash owns that wait.
    if (!AuthGuard.isReady) return null;

    final isLoggedIn = AuthGuard.isLoggedInNow;
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
                          location == '/search' ||
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
      navigatorKey: shellNavigatorKey,
      builder: (context, state, child) => MainLayout(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: '/chronicles',
          builder: (context, state) => const ChroniclesScreen(),
        ),
        GoRoute(
          path: '/chronicles/create',
          builder: (context, state) {
            // Opened from the daily challenge, the prompt is passed as extra.
            final extra = state.extra;
            final brief = extra is Map ? extra : const {};
            return CreateChroniclesPostScreen(
              challengeId: brief['challengeId'] as String?,
              challengePrompt: brief['prompt'] as String?,
            );
          },
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
            return ChainEntriesScreen(chainId: chainId);
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
          path: '/stories/my-stories',
          builder: (context, state) => const MyStoriesScreen(),
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
            GoRoute(
              path: 'chapters',
              builder: (context, state) {
                final slug = state.pathParameters['slug']!;
                final storyTitle = state.uri.queryParameters['title'] ?? 'Manage Chapters';
                return ManageChaptersScreen(storyId: slug, storyTitle: storyTitle);
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
          path: '/edit-profile',
          builder: (context, state) => const EditProfileScreen(),
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
          path: '/chronicles/categories',
 builder: (context, state) => const ChronicleCategoriesScreen(),
 ),
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
      builder: (context, state) => const BackGuard(child: AiChatScreen()),
    ),

    // Premium
    GoRoute(
      path: '/premium',
      builder: (context, state) => const BackGuard(child: PremiumScreen()),
    ),

    // Creator studio — the workspace for managing your own work. Declared
    // before `/creator/:id` so "studio" is not parsed as a creator id.
    GoRoute(
      path: '/creator/studio',
      builder: (context, state) => const BackGuard(child: CreatorDashboardScreen()),
    ),
    GoRoute(
      path: '/creator/settings',
      builder: (context, state) => const BackGuard(child: CreatorSettingsScreen()),
    ),
    // Creator profile
    GoRoute(
      path: '/creator/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return BackGuard(child: CreatorProfileScreen(creatorId: id));
      },
    ),
  ],
);
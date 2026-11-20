import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/post.dart';
import '../../../core/network/api_service.dart';
import '../../../core/services/chains_service.dart';
import '../../../core/services/content_cache_service.dart';
import '../../../core/services/chronicles_service.dart';
import '../../../core/services/daily_challenge_service.dart';
import '../../../core/services/feed_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/supabase_auth_provider.dart';
import '../widgets/daily_challenge_card.dart';
import '../widgets/gated_preview.dart';
import '../widgets/notification_prompt.dart';
import '../../../core/constants/layout.dart';

final _feedServiceProvider = Provider((ref) => FeedService(ApiService.instance, ContentCacheService()));
final _chainsServiceProvider = Provider((ref) => ChainsService(ApiService.instance, ContentCacheService()));
final _chroniclesServiceProvider = Provider((ref) => ChroniclesService(ApiService.instance, ContentCacheService()));

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final PageController _pageController = PageController();
  int _tabIndex = 0;
  List<Post> _adminPosts = [];
  List<Post> _chroniclePosts = [];
  List<dynamic> _chains = [];
  DailyChallengeState? _challenge;
  bool _loadingFeed = true;

  @override
  void initState() {
    super.initState();
    _loadChallenge();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// The challenge is local and instant, so it renders first and the network
  /// content slides in underneath instead of blocking the whole screen.
  Future<void> _loadChallenge() async {
    final challenge = await DailyChallengeService.instance.load();
    if (!mounted) return;
    setState(() => _challenge = challenge);
  }

  /// Fetches the three feeds concurrently and lets each one paint as soon as
  /// it lands. A failing endpoint is logged and leaves that section empty;
  /// it never blocks the other two or hangs the loading state.
  Future<void> _load({bool forceRefresh = false}) async {
    final feedService = ref.read(_feedServiceProvider);
    final chroniclesService = ref.read(_chroniclesServiceProvider);
    final chainsService = ref.read(_chainsServiceProvider);

    Future<void> guarded(String label, Future<void> Function() run) async {
      try {
        await run();
      } catch (e) {
        debugPrint('[HomeScreen] $label failed: $e');
      }
    }

    await Future.wait([
      guarded('feed', () async {
        final feed = await feedService.getFeed(forceRefresh: forceRefresh);
        if (!mounted) return;
        setState(() {
          _adminPosts = feed
              .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
              .where((post) => post.source == 'admin')
              .toList();
        });
      }),
      guarded('chronicles', () async {
        final chronicles = await chroniclesService.getPublicChronicles(forceRefresh: forceRefresh);
        if (!mounted) return;
        setState(() {
          _chroniclePosts = chronicles
              .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
              .where((post) => post.source == 'creator' || post.source == 'user')
              .toList();
        });
      }),
      guarded('chains', () async {
        final chains = await chainsService.getChains(forceRefresh: forceRefresh);
        if (!mounted) return;
        setState(() => _chains = chains);
      }),
    ]);

    if (mounted) setState(() => _loadingFeed = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([_load(forceRefresh: true), _loadChallenge()]);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _topSection(context)),
              SliverToBoxAdapter(child: _tabBar()),
              // The tabbed body must size to its content. The old code wrapped
              // a PageView in SliverFillRemaining, which forced every tab to
              // exactly one screen and clipped the rest.
              _tabIndex == 3 ? _gamesSliver(context) : _feedSliver(context),
              const SliverToBoxAdapter(child: SizedBox(height: kBottomNavClearance)),
            ],
          ),
        ),
      ),
    );
  }

  /// Tab 0–2 content, sized to the content instead of the viewport.
  Widget _feedSliver(BuildContext context) {
    final tab = switch (_tabIndex) {
      0 => _discoverChildren(context),
      1 => _adminChildren(context),
      _ => _chroniclesChildren(context),
    };

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      sliver: SliverList(delegate: SliverChildListDelegate(tab)),
    );
  }

  /// Games used to be squeezed into a PageView cell with its own scaffold and
  /// app bar inside the home scroll view, which is why it rendered wrong. It
  /// gets a card that opens the real games screen now.
  Widget _gamesSliver(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Row(
            children: [
              Expanded(
                child: _actionCard(context, 'Games', 'Learn & improve', Icons.sports_esports_outlined, () => context.go('/games')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionCard(context, 'Guides', 'Tutorials & tips', Icons.menu_book_outlined, () => context.go('/guides')),
              ),
            ],
          ),
          _sectionHeader(context, 'Continue playing', 'Your scores and daily streaks'),
          _actionCard(
            context,
            'Open games',
            'Word games, poetry puzzles and seasonal challenges',
            Icons.extension_outlined,
            () => context.go('/games'),
          ),
          const SizedBox(height: 12),
          _actionCard(
            context,
            'Game profile',
            'Achievements, XP and leaderboard position',
            Icons.emoji_events_outlined,
            () => context.go('/games/profile'),
          ),
        ]),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top of home: greeting, daily challenge, notification prompt.
  // The old hero was a fixed marketing banner whose pills did not navigate
  // anywhere, and it pushed the real content a full screen down. The daily
  // challenge earns that space instead.
  // ---------------------------------------------------------------------------

  Widget _topSection(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final name = authState.user?.penName.trim();
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name == null || name.isEmpty ? 'Welcome to Whispr' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              _iconAction(
                icon: Icons.search_rounded,
                tooltip: 'Explore',
                onTap: () => context.go('/search'),
              ),
              const SizedBox(width: 4),
              _iconAction(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Notifications',
                onTap: () => context.go('/notifications'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const NotificationPrompt(),
          if (_challenge != null) ...[
            DailyChallengeCard(
              state: _challenge!,
              onEnter: _startChallenge,
              onRefresh: () => _load(forceRefresh: true),
            ),
            const SizedBox(height: 10),
            StreakStrip(
              current: _challenge!.currentStreak,
              best: _challenge!.bestStreak,
            ),
          ] else
            _challengeSkeleton(context),
        ],
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }

  Widget _challengeSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 168,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusXL),
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Future<void> _startChallenge() async {
    final challenge = _challenge?.challenge;
    if (challenge == null) return;

    // The composer is the existing chronicles writer, handed the prompt so the
    // user lands on a blank page that already has its brief.
    await context.push(
      '/chronicles/create',
      extra: {'challengeId': challenge.id, 'prompt': challenge.prompt},
    );

    if (!mounted) return;
    final updated = await DailyChallengeService.instance.load();
    if (mounted) setState(() => _challenge = updated);
  }

  // ---------------------------------------------------------------------------
  // Tabs
  // ---------------------------------------------------------------------------

  Widget _tabBar() {
    const labels = ['Discover', 'General', 'Chronicles', 'Games'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(labels.length, (index) {
            final selected = index == _tabIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() => _tabIndex = index);
                  _pageController.animateToPage(
                    index,
                    duration: AppTheme.shortAnimation,
                    curve: Curves.easeOut,
                  );
                },
                child: AnimatedContainer(
                  duration: AppTheme.shortAnimation,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.045)),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Tab bodies. These return children lists (not ListViews) so they can be
  // nested inside the one CustomScrollView that owns the whole screen.
  // ---------------------------------------------------------------------------

  List<Widget> _discoverChildren(BuildContext context) {
    return [
      if (_loadingFeed && _adminPosts.isEmpty && _chroniclePosts.isEmpty)
        _loadingBlock(context)
      else ...[
        Row(
          children: [
            Expanded(child: _actionCard(context, 'Games', 'Learn & improve', Icons.sports_esports_outlined, () => context.go('/games'))),
            const SizedBox(width: 12),
            Expanded(child: _actionCard(context, 'Guides', 'Tutorials & tips', Icons.menu_book_outlined, () => context.go('/guides'))),
          ],
        ),
        if (_adminPosts.isNotEmpty) ...[
          _sectionHeader(context, 'General highlights', 'Fresh poems and blogs from Whispr'),
          _horizontalPosts(context, _adminPosts.take(5).toList()),
        ],
        if (_chroniclePosts.isNotEmpty) ...[
          _sectionHeader(context, 'Featured chronicles', 'Blogs, poems and stories from Whispr creators'),
          _horizontalPosts(context, _chroniclePosts.take(5).toList()),
 _actionCard(
 context,
 'Browse by category',
 'Every chronicle arranged by the world it belongs to',
 Icons.category_outlined,
 () => context.push('/chronicles/categories'),
 ),
        ],
        if (_chains.isNotEmpty) ...[
          _sectionHeader(context, 'Writing chains', 'Active collaboration stories'),
          _horizontalChains(context),
        ],
        if (_adminPosts.isEmpty && _chroniclePosts.isEmpty && !_loadingFeed)
          _emptyBlock(
            context,
            'Nothing here yet',
            'New poems and chronicles will appear as they publish.',
          ),
      ],
    ];
  }

  List<Widget> _adminChildren(BuildContext context) {
    final poems = _adminPosts.where((post) => post.type == 'poem').toList();
    final blogs = _adminPosts.where((post) => post.type == 'blog').toList();

    if (poems.isEmpty && blogs.isEmpty) {
      return [_loadingFeed ? _loadingBlock(context) : _emptyBlock(context, 'No posts yet', 'General poems and blogs land here.')];
    }

    return [
      if (poems.isNotEmpty) ...[
        _sectionHeader(context, 'General poems', 'Curated poetry from Whispr'),
        ...poems.take(6).map((post) => _feedCard(context, post)),
      ],
      if (blogs.isNotEmpty) ...[
        _sectionHeader(context, 'General blogs', 'Curated writing from Whispr'),
        ...blogs.take(6).map((post) => _feedCard(context, post)),
      ],
    ];
  }

  List<Widget> _chroniclesChildren(BuildContext context) {
    final chronicles = _chroniclePosts
        .where((post) => post.type == 'chronicle' || post.type == 'poem' || post.type == 'blog')
        .toList();

    if (chronicles.isEmpty && _chains.isEmpty) {
      return [_loadingFeed ? _loadingBlock(context) : _emptyBlock(context, 'No chronicles yet', 'Creator posts appear here as they publish.')];
    }

    return [
      if (chronicles.isNotEmpty) ...[
        _sectionHeader(context, 'Creator chronicles', 'Independent posts from Chronicles creators'),
        ...chronicles.take(8).map((post) => _feedCard(context, post)),
      ],
      if (_chains.isNotEmpty) ...[
        _sectionHeader(context, 'Writing chains', 'Browse collaborative stories'),
        ..._chains.take(6).map((chain) {
          final chainMap = chain as Map<String, dynamic>;
          final entries = chainMap['entries_count'] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
                onTap: () => context.go('/chains/${chainMap['id']}'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chainMap['title'] ?? 'Untitled chain',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$entries ${entries == 1 ? 'entry' : 'entries'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    ];
  }

  Widget _loadingBlock(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _emptyBlock(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.auto_stories_outlined, size: 30, color: Theme.of(context).textTheme.bodySmall?.color),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _horizontalPosts(BuildContext context, List<Post> posts) {
    return SizedBox(
      height: 250,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, i) => SizedBox(width: 280, child: _heroCard(context, posts[i])),
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemCount: posts.length,
      ),
    );
  }

  Widget _horizontalChains(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, i) {
          final chain = _chains[i] as Map<String, dynamic>;
          return GestureDetector(
            onTap: () => context.go('/chains/${chain['id']}'),
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(22)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(chain['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(chain['description'] ?? '', maxLines: 3, overflow: TextOverflow.ellipsis),
                const Spacer(),
                Text('${chain['entries_count'] ?? 0} entries', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
              ]),
            ),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemCount: _chains.length.clamp(0, 6),
      ),
    );
  }

  Widget _actionCard(BuildContext context, String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 26,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context, Post post) {
    return GestureDetector(
      onTap: () => _openPost(context, post),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (post.coverImage != null)
              CachedNetworkImage(
                imageUrl: post.coverImage!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                errorWidget: (context, url, error) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Image.asset('assets/images/Whispr.png', fit: BoxFit.contain),
                ),
              )
            else
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Image.asset('assets/images/Whispr.png', fit: BoxFit.contain),
              ),
            // Ensure content is visible in both light and dark modes
            if (post.coverImage == null)
              Container(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey.shade200
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Center(
                  child: Image.asset(
                    'assets/images/Whispr.png',
                    fit: BoxFit.contain,
                    width: 80,
                    height: 80,
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      post.type.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    post.excerpt ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedCard(BuildContext context, Post post) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => _openPost(context, post),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.coverImage != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: post.coverImage!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 200,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Image.asset('assets/images/Whispr.png', fit: BoxFit.contain),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Positioned(top: 12, left: 12, child: _buildTypeBadge(post.type)),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GatedPreview(
                      text: post.excerpt ?? post.content,
                      fallback: 'Tap to open this ${post.type}.',
                      maxCharacters: 180,
                      onTap: () => _openPost(context, post),
                    ),
                    PostStatsRow(
                      reads: post.viewCount,
                      likes: post.likesCount,
                      comments: post.commentsCount,
                      minutes: post.readingTime,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.person,
                            size: 16,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            post.author.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            post.displayDate,
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodySmall?.color,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        type.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _openPost(BuildContext context, Post post) {
    final isChronicle = post.source == 'creator' || post.source == 'user';
    if (isChronicle) {
      // Use slug if available, otherwise use id
      final identifier = post.slug ?? post.id;
      context.go('/chronicles/$identifier');
    } else {
      context.go('/post/${post.id}');
    }
  }
}
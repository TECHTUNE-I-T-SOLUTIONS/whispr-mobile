import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/layout.dart';
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

final _feedServiceProvider = Provider(
  (ref) => FeedService(ApiService.instance, ContentCacheService()),
);
final _chainsServiceProvider = Provider(
  (ref) => ChainsService(ApiService.instance, ContentCacheService()),
);
final _chroniclesServiceProvider = Provider(
  (ref) => ChroniclesService(ApiService.instance, ContentCacheService()),
);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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
        final chronicles = await chroniclesService.getPublicChronicles(
          forceRefresh: forceRefresh,
        );
        if (!mounted) return;
        setState(() {
          _chroniclePosts = chronicles
              .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
              .where(
                (post) => post.source == 'creator' || post.source == 'user',
              )
              .toList();
        });
      }),
      guarded('chains', () async {
        final chains = await chainsService.getChains(
          forceRefresh: forceRefresh,
        );
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
              const SliverToBoxAdapter(child: NotificationPrompt()),
              SliverToBoxAdapter(child: _tabBar()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    _tabIndex == 3
                        ? _gamesChildren(context)
                        : _tabChildren(context),
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: kBottomNavClearance),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
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
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: secondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name == null || name.isEmpty ? 'Welcome to Whispr' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.serifFamily,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 18),
          if (_challenge != null)
            DailyChallengeCard(
              state: _challenge!,
              onEnter: _startChallenge,
              onRefresh: () => _load(forceRefresh: true),
            )
          else
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
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 19),
      ),
    );
  }

  Widget _challengeSkeleton(BuildContext context) {
    return Container(
      height: 148,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
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

    await context.push(
      '/chronicles/create',
      extra: {'challengeId': challenge.id, 'prompt': challenge.prompt},
    );

    if (!mounted) return;
    final updated = await DailyChallengeService.instance.load();
    if (mounted) setState(() => _challenge = updated);
  }

  // ---------------------------------------------------------------------------
  // Tabs — a quiet underline, not four competing pills.
  // ---------------------------------------------------------------------------

  Widget _tabBar() {
    const labels = ['Discover', 'General', 'Chronicles', 'Games'];
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final outline = Theme.of(
      context,
    ).colorScheme.outline.withValues(alpha: 0.4);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: outline)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(labels.length, (index) {
            final selected = index == _tabIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 24),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _tabIndex = index),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Text(
                        labels[index],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: selected ? primary : secondary,
                        ),
                      ),
                    ),
                    Container(
                      height: 2,
                      width: 22,
                      decoration: BoxDecoration(
                        color: selected ? primary : Colors.transparent,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab bodies. These return children lists so one CustomScrollView owns the
  // whole screen and every tab scrolls naturally to its own content height.
  // ---------------------------------------------------------------------------

  List<Widget> _tabChildren(BuildContext context) {
    if (_loadingFeed && _adminPosts.isEmpty && _chroniclePosts.isEmpty) {
      return [_loadingBlock(context)];
    }

    return switch (_tabIndex) {
      0 => _discoverChildren(context),
      1 => _adminChildren(context),
      _ => _chroniclesChildren(context),
    };
  }

  List<Widget> _discoverChildren(BuildContext context) {
    return [
      _quickLinks(context),
      if (_adminPosts.isNotEmpty) ...[
        MobileSectionHeader(
          title: 'From Whispr',
          subtitle: 'Fresh poems and blogs',
          actionLabel: 'See all',
          onAction: () => setState(() => _tabIndex = 1),
        ),
        _storyRow(context, _adminPosts.first, featured: true),
        ..._adminPosts.skip(1).take(2).map((post) => _storyRow(context, post)),
      ],
      if (_chroniclePosts.isNotEmpty) ...[
        MobileSectionHeader(
          title: 'From creators',
          subtitle: 'Stories, poems and blogs',
          actionLabel: 'See all',
          onAction: () => setState(() => _tabIndex = 2),
        ),
        ..._chroniclePosts.take(3).map((post) => _storyRow(context, post)),
      ],
      if (_chains.isNotEmpty) ...[
        const MobileSectionHeader(
          title: 'Writing chains',
          subtitle: 'Stories built together',
        ),
        _chainRow(context, _chains.first as Map<String, dynamic>),
      ],
      if (_adminPosts.isEmpty && _chroniclePosts.isEmpty && !_loadingFeed)
        _emptyBlock(
          context,
          'Nothing here yet',
          'New poems and chronicles will appear as they publish.',
        ),
    ];
  }

  List<Widget> _adminChildren(BuildContext context) {
    final poems = _adminPosts.where((post) => post.type == 'poem').toList();
    final blogs = _adminPosts.where((post) => post.type == 'blog').toList();

    if (poems.isEmpty && blogs.isEmpty) {
      return [
        _loadingFeed
            ? _loadingBlock(context)
            : _emptyBlock(
                context,
                'No posts yet',
                'General poems and blogs land here.',
              ),
      ];
    }

    return [
      if (poems.isNotEmpty) ...[
        const MobileSectionHeader(
          title: 'Poems',
          subtitle: 'Curated by Whispr',
        ),
        ...poems.take(6).map((post) => _storyRow(context, post)),
      ],
      if (blogs.isNotEmpty) ...[
        const MobileSectionHeader(
          title: 'Blogs',
          subtitle: 'Curated by Whispr',
        ),
        ...blogs.take(6).map((post) => _storyRow(context, post)),
      ],
    ];
  }

  List<Widget> _chroniclesChildren(BuildContext context) {
    final chronicles = _chroniclePosts
        .where(
          (post) =>
              post.type == 'chronicle' ||
              post.type == 'poem' ||
              post.type == 'blog',
        )
        .toList();

    if (chronicles.isEmpty && _chains.isEmpty) {
      return [
        _loadingFeed
            ? _loadingBlock(context)
            : _emptyBlock(
                context,
                'No chronicles yet',
                'Creator posts appear here as they publish.',
              ),
      ];
    }

    return [
      if (chronicles.isNotEmpty) ...[
        const MobileSectionHeader(
          title: 'Creator chronicles',
          subtitle: 'Independent posts from the community',
        ),
        ...chronicles.take(8).map((post) => _storyRow(context, post)),
      ],
      if (_chains.isNotEmpty) ...[
        const MobileSectionHeader(
          title: 'Writing chains',
          subtitle: 'Browse collaborative stories',
        ),
        ..._chains
            .take(6)
            .map((chain) => _chainRow(context, chain as Map<String, dynamic>)),
      ],
    ];
  }

  List<Widget> _gamesChildren(BuildContext context) {
    return [
      const MobileSectionHeader(
        title: 'Play',
        subtitle: 'Short games for a sharper pen',
      ),
      _quickLinks(context),
      const MobileSectionHeader(
        title: 'Your progress',
        subtitle: 'Scores, streaks and achievements',
      ),
      _listRow(
        icon: Icons.emoji_events_outlined,
        title: 'Game profile',
        subtitle: 'Achievements, XP and leaderboard position',
        onTap: () => context.go('/games/profile'),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Shared cards
  // ---------------------------------------------------------------------------

  Widget _quickLinks(BuildContext context) {
    final items = <(String, IconData, String)>[
      ('Games', Icons.sports_esports_outlined, '/games'),
      ('Guides', Icons.menu_book_outlined, '/guides'),
      ('Categories', Icons.category_outlined, '/chronicles/categories'),
    ];

    return Row(
      children: [
        for (final item in items) ...[
          Expanded(child: _quickLink(context, item.$1, item.$2, item.$3)),
          if (item != items.last) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _quickLink(
    BuildContext context,
    String label,
    IconData icon,
    String route,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    return MobileCard(
      onTap: () => context.go(route),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: primary),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _storyRow(BuildContext context, Post post, {bool featured = false}) {
    final size = featured ? 92.0 : 72.0;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final primary = Theme.of(context).colorScheme.primary;

    return MobileCard(
      onTap: () => _openPost(context, post),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _thumbnail(context, post, size),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      post.type,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        post.displayDate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: secondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  post.title,
                  maxLines: featured ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.serifFamily,
                    fontSize: featured ? 18 : 16,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                if (featured) ...[
                  const SizedBox(height: 4),
                  GatedPreview(
                    text: post.excerpt ?? post.content,
                    fallback: 'Tap to read this ${post.type}.',
                    maxCharacters: 120,
                  ),
                ],
                PostStatsRow(
                  reads: post.viewCount,
                  likes: post.likesCount,
                  comments: post.commentsCount,
                  minutes: post.readingTime,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbnail(BuildContext context, Post post, double size) {
    final placeholder = Theme.of(context).colorScheme.surfaceContainerHighest;
    final logo = Center(
      child: Image.asset(
        'assets/images/Whispr.png',
        width: size * 0.42,
        height: size * 0.42,
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: post.coverImage != null
          ? CachedNetworkImage(
              imageUrl: post.coverImage!,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: placeholder),
              errorWidget: (context, url, error) =>
                  Container(color: placeholder, child: logo),
            )
          : Container(color: placeholder, child: logo),
    );
  }

  Widget _chainRow(BuildContext context, Map<String, dynamic> chain) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final entries = chain['entries_count'] ?? 0;

    return MobileCard(
      onTap: () => context.go('/chains/${chain['id']}'),
      child: Row(
        children: [
          Icon(
            Icons.link_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chain['title'] ?? 'Untitled chain',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$entries ${entries == 1 ? 'entry' : 'entries'}',
                  style: TextStyle(fontSize: 12, color: secondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: secondary),
        ],
      ),
    );
  }

  Widget _listRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return MobileCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: secondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: secondary),
        ],
      ),
    );
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
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.auto_stories_outlined, size: 28, color: secondary),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: secondary),
          ),
        ],
      ),
    );
  }

  void _openPost(BuildContext context, Post post) {
    final isChronicle = post.source == 'creator' || post.source == 'user';
    if (isChronicle) {
      final identifier = post.slug ?? post.id;
      context.go('/chronicles/$identifier');
    } else {
      context.go('/post/${post.id}');
    }
  }
}

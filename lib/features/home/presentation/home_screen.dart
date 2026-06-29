import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/post.dart';
import '../../../core/network/api_service.dart';
import '../../../core/services/chains_service.dart';
import '../../../core/services/content_cache_service.dart';
import '../../../core/services/chronicles_service.dart';
import '../../../core/services/feed_service.dart';
import '../../../core/theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final feedService = ref.read(_feedServiceProvider);
    final chroniclesService = ref.read(_chroniclesServiceProvider);
    final chainsService = ref.read(_chainsServiceProvider);

    final feed = await feedService.getFeed(forceRefresh: forceRefresh);
    final chronicles = await chroniclesService.getPublicChronicles(forceRefresh: forceRefresh);
    final chains = await chainsService.getChains(forceRefresh: forceRefresh);
    if (!mounted) return;
    setState(() {
      _adminPosts = feed
          .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
          .where((post) => post.source == 'admin')
          .toList();
      _chroniclePosts = chronicles
          .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
          .where((post) => post.source == 'creator' || post.source == 'user')
          .toList();
      _chains = chains;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _load(forceRefresh: true),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _hero(context)),
            SliverToBoxAdapter(child: _tabBar()),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 560,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _tabIndex = index),
                  children: [
                    _discoverView(context),
                    _adminFeedView(context),
                    _chroniclesFeedView(context),
                    _gamesView(context),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to Whispr',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Discover stories, improve your craft',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill('Admin', Icons.edit_note_outlined),
                _pill('Chronicles', Icons.auto_stories_outlined),
                _pill('Chains', Icons.link_outlined),
                _pill('Games', Icons.sports_esports_outlined),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBar() {
    final labels = ['Discover', 'Admin Posts', 'Chronicles', 'Games'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(labels.length, (index) {
            final selected = index == _tabIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () {
                  setState(() => _tabIndex = index);
                  _pageController.animateToPage(index, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                },
                child: Column(
                  children: [
                    Text(labels[index], style: TextStyle(color: selected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 2,
                      width: selected ? 28 : 8,
                      decoration: BoxDecoration(color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent, borderRadius: BorderRadius.circular(99)),
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

  Widget _discoverView(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      children: [
        Row(
          children: [
            Expanded(child: _actionCard(context, 'Games', 'Learn & improve', Icons.sports_esports_outlined, () => context.go('/games'))),
            const SizedBox(width: 12),
            Expanded(child: _actionCard(context, 'Guides', 'Tutorials & tips', Icons.menu_book_outlined, () => context.go('/guides'))),
          ],
        ),
        const SizedBox(height: 16),
        _sectionHeader(context, 'Admin highlights', 'Fresh poems and blogs from the admin team'),
        _horizontalPosts(context, _adminPosts.take(5).toList()),
        _sectionHeader(context, 'Creator chronicles', 'Stories and writing from the community'),
        _horizontalPosts(context, _chroniclePosts.take(5).toList()),
        _sectionHeader(context, 'Writing Chains', 'Active collaboration stories'),
        _horizontalChains(context),
      ],
    );
  }

  Widget _adminFeedView(BuildContext context) {
    final poems = _adminPosts.where((post) => post.type == 'poem').toList();
    final blogs = _adminPosts.where((post) => post.type == 'blog').toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      children: [
        _sectionHeader(context, 'Admin poems', 'Curated poetic posts from the admin team'),
        ...poems.take(4).map((post) => _feedCard(context, post)),
        _sectionHeader(context, 'Admin blogs', 'Curated blog posts from the admin team'),
        ...blogs.take(4).map((post) => _feedCard(context, post)),
      ],
    );
  }

  Widget _chroniclesFeedView(BuildContext context) {
    final chronicles = _chroniclePosts.where((post) => post.type == 'chronicle' || post.type == 'poem' || post.type == 'blog').toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      children: [
        _sectionHeader(context, 'Creator chronicles', 'Independent posts from chronicles creators'),
        ...chronicles.take(6).map((post) => _feedCard(context, post)),
        _sectionHeader(context, 'Writing chains', 'Browse collaborative stories'),
        ..._chains.take(6).map((chain) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24)),
              child: Text((chain as Map<String, dynamic>)['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
            )),
      ],
    );
  }

  Widget _gamesView(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      children: [
        _sectionHeader(context, 'Games', 'Interactive templates and learning tools'),
        Row(
          children: [
            Expanded(child: _actionCard(context, 'Play now', 'Open the game hub', Icons.sports_esports_outlined, () => context.go('/games'))),
            const SizedBox(width: 12),
            Expanded(child: _actionCard(context, 'Guides', 'Open tutorials', Icons.menu_book_outlined, () => context.go('/guides'))),
          ],
        ),
      ],
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
          return Container(
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
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemCount: _chains.length.clamp(0, 6),
      ),
    );
  }

  Widget _pill(String label, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );

  Widget _actionCard(BuildContext context, String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 24,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
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
                  child: Icon(
                    Icons.broken_image,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.article,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 48,
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
                          child: Icon(
                            Icons.broken_image,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
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
                    Text(
                      post.excerpt ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        height: 1.5,
                      ),
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
    context.go(isChronicle ? '/chronicles/${post.id}' : '/post/${post.id}');
  }
}
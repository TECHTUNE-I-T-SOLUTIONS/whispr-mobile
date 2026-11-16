import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/content_badge.dart';
import '../../../core/models/creator_stats.dart';
import '../../../core/network/api_service.dart';
import '../../../core/services/content_cache_service.dart';
import '../../../core/services/creator_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/widgets/gated_preview.dart';

final _creatorServiceProvider = Provider(
  (ref) => CreatorService(ApiService.instance, ContentCacheService()),
);

/// The creator's own workspace on mobile.
///
/// The web dashboard gives creators stats, their post list with draft/publish
/// control, stories, reviews and settings. Mobile only ever had a profile view,
/// so a creator could not manage a draft or unpublish a post from their phone.
/// This is that workspace, with the same capabilities.
class CreatorDashboardScreen extends ConsumerStatefulWidget {
  const CreatorDashboardScreen({super.key});

  @override
  ConsumerState<CreatorDashboardScreen> createState() => _CreatorDashboardScreenState();
}

class _CreatorDashboardScreenState extends ConsumerState<CreatorDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  CreatorStats _stats = const CreatorStats();
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _stories = [];
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final service = ref.read(_creatorServiceProvider);

    // Stats, posts, stories and reviews are independent — load together.
    final results = await Future.wait([
      _guard(() => service.getStats(forceRefresh: forceRefresh)),
      _guard(() => service.getMyPosts(forceRefresh: forceRefresh)),
      _guard(() => service.getMyStories(forceRefresh: forceRefresh)),
      _guard(() => service.getReviews(forceRefresh: forceRefresh)),
    ]);

    if (!mounted) return;

    final stats = results[0];
    final posts = results[1];
    final stories = results[2];
    final reviews = results[3];

    setState(() {
      if (stats is CreatorStats) _stats = stats;
      if (posts is List<Map<String, dynamic>>) _posts = posts;
      if (stories is List<Map<String, dynamic>>) _stories = stories;
      if (reviews is List<Map<String, dynamic>>) _reviews = reviews;
      _loading = false;
      if (posts == null && stats == null) {
        _error = 'Could not reach Whispr. Pull down to try again.';
      }
    });
  }

  /// Returns null on failure so one bad endpoint cannot blank the workspace.
  Future<T?> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      debugPrint('[CreatorDashboard] $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  Future<void> _setStatus(Map<String, dynamic> post, String status) async {
    final id = (post['id'] ?? '').toString();
    if (id.isEmpty) return;

    HapticFeedback.selectionClick();
    // Optimistic: flip locally so the list responds instantly, then reconcile.
    setState(() => post['status'] = status);
    try {
      await ref.read(_creatorServiceProvider).setPostStatus(id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status == 'published' ? 'Published.' : 'Moved to drafts.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => post['status'] = status == 'published' ? 'draft' : 'published');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update. Check your connection.')),
      );
    }
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    final id = (post['id'] ?? '').toString();
    final title = (post['title'] ?? 'this post').toString();
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this post?'),
        content: Text('"$title" will be removed for good. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _posts.removeWhere((p) => p['id'] == id));
    try {
      await ref.read(_creatorServiceProvider).deletePost(id);
    } catch (e) {
      if (!mounted) return;
      await _load(forceRefresh: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete that post.')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Creator studio'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Posts'),
            Tab(text: 'Stories'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Creator settings',
            icon: const Icon(Icons.tune_rounded, size: 20),
            onPressed: () => context.push('/creator/settings'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _overview(),
                _postsTab(),
                _storiesTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/chronicles/create').then((_) => _load(forceRefresh: true)),
        icon: const Icon(Icons.edit_rounded, size: 19),
        label: const Text('Write'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Overview
  // ---------------------------------------------------------------------------

  Widget _overview() {
    final drafts = _posts.where((p) => p['status'] == 'draft').length;
    final published = _posts.where((p) => p['status'] == 'published').length;
    final scheduled = _posts.where((p) => p['status'] == 'scheduled').length;

    return RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          if (_error != null) ...[
            _errorBanner(),
            const SizedBox(height: 14),
          ],
          _streakCard(),
          const SizedBox(height: 16),
          _statGrid(drafts: drafts, published: published, scheduled: scheduled),
          const SizedBox(height: 22),
          const _Label('Quick actions'),
          const SizedBox(height: 10),
          _actionTile(
            Icons.edit_note_rounded,
            'Write a new post',
            'Poem or essay — publish now or save a draft',
            () => context.push('/chronicles/create').then((_) => _load(forceRefresh: true)),
          ),
          _actionTile(
            Icons.menu_book_outlined,
            'Start a story',
            'Multi-chapter work with its own readers',
            () => context.push('/stories/create').then((_) => _load(forceRefresh: true)),
          ),
          _actionTile(
            Icons.public_rounded,
            'View my portfolio',
            'See what readers see',
            () => context.push('/portfolio/${_stats.penName ?? ''}'),
          ),
          const SizedBox(height: 22),
          if (_reviews.isNotEmpty) ...[
            _Label('Recent reviews (${_reviews.length})'),
            const SizedBox(height: 10),
            ..._reviews.take(3).map(_reviewTile),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => context.push('/reviews'),
              child: const Text('See all reviews'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _streakCard() {
    final streak = _stats.currentStreak;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Theme.of(context).brightness == Brightness.dark
              ? [const Color(0xFF2A0F10), const Color(0xFF140A0A)]
              : [AppTheme.primaryColor, const Color(0xFF5E0E0F)],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFB74D), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak > 0 ? '$streak-day streak' : 'Start your streak',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  streak > 0
                      ? 'Keep writing daily to hold it.'
                      : 'Publish something today to begin.',
                  style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.72)),
                ),
              ],
            ),
          ),
          if (_stats.longestStreak > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_stats.longestStreak}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  'best',
                  style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.6)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statGrid({required int drafts, required int published, required int scheduled}) {
    final tiles = <(String, String, Color)>[
      ('Published', '$published', const Color(0xFF3E7A44)),
      ('Drafts', '$drafts', AppTheme.warningColor),
      ('Scheduled', '$scheduled', const Color(0xFF3E6FA8)),
      ('Followers', _formatCount(_stats.totalFollowers), AppTheme.primaryColor),
      ('Engagement', _formatCount(_stats.effectiveEngagement), const Color(0xFF7A3E8A)),
      ('Points', _formatCount(_stats.points), const Color(0xFFB26A22)),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 9,
      crossAxisSpacing: 9,
      childAspectRatio: 1.4,
      children: tiles.map((t) {
        final (label, value, color) = t;
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.14 : 0.075),
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color, height: 1.05),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _actionTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return MobileCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11.5, color: Theme.of(context).textTheme.bodySmall?.color),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 19),
        ],
      ),
    );
  }

  Widget _reviewTile(Map<String, dynamic> review) {
    final reviewer = (review['reviewer_name'] ?? review['creator_name'] ?? 'A reader').toString();
    final body = (review['feedback'] ?? review['comment'] ?? review['content'] ?? '').toString();
    final rating = review['rating'];

    return MobileCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(reviewer, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (rating is num)
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < rating.round() ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 13,
                      color: AppTheme.warningColor,
                    ),
                  ),
                ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            GatedPreview(text: body, fallback: '', maxCharacters: 100),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Posts
  // ---------------------------------------------------------------------------

  Widget _postsTab() {
    if (_posts.isEmpty) {
      return _empty(
        icon: Icons.edit_note_rounded,
        title: 'Nothing written yet',
        body: 'Your drafts and published pieces will show up here.',
        actionLabel: 'Write something',
        onAction: () => context.push('/chronicles/create').then((_) => _load(forceRefresh: true)),
      );
    }

    final statusOrder = {'draft': 0, 'scheduled': 1, 'published': 2};
    final sorted = [..._posts]..sort((a, b) {
        final sa = statusOrder[(a['status'] ?? 'draft').toString()] ?? 3;
        final sb = statusOrder[(b['status'] ?? 'draft').toString()] ?? 3;
        if (sa != sb) return sa.compareTo(sb);
        return (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString());
      });

    return RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: sorted.length,
        itemBuilder: (context, index) => _postRow(sorted[index]),
      ),
    );
  }

  Widget _postRow(Map<String, dynamic> post) {
    final status = (post['status'] ?? 'draft').toString();
    final title = (post['title'] ?? 'Untitled').toString();
    final type = (post['post_type'] ?? post['type'] ?? 'poem').toString();
    final excerpt = post['excerpt'] ?? post['content'];
    final isPublished = status == 'published';

    final statusColor = switch (status) {
      'published' => const Color(0xFF3E7A44),
      'scheduled' => const Color(0xFF3E6FA8),
      _ => AppTheme.warningColor,
    };

    return MobileCard(
      padding: const EdgeInsets.all(14),
      onTap: () {
        final slug = (post['slug'] ?? post['id'] ?? '').toString();
        if (slug.isNotEmpty) context.push('/chronicles/$slug');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: statusColor),
                ),
              ),
              const SizedBox(width: 7),
              ContentBadgeChip(
                badge: ContentBadge(origin: ContentOrigin.creator, format: type),
                compact: true,
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded, size: 19),
                onSelected: (value) {
                  switch (value) {
                    case 'publish':
                      _setStatus(post, isPublished ? 'draft' : 'published');
                    case 'edit':
                      context.push('/chronicles/create').then((_) => _load(forceRefresh: true));
                    case 'delete':
                      _deletePost(post);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'publish',
                    child: Row(
                      children: [
                        Icon(isPublished ? Icons.unpublished_rounded : Icons.publish_rounded, size: 17),
                        const SizedBox(width: 10),
                        Text(isPublished ? 'Move to drafts' : 'Publish'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 17),
                        SizedBox(width: 10),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 17),
                        SizedBox(width: 10),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTheme.serifFamily,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 5),
          GatedPreview(
            text: excerpt?.toString(),
            fallback: 'No preview yet.',
            maxCharacters: 100,
          ),
          if (isPublished)
            PostStatsRow(
              reads: _intOf(post['view_count']),
              likes: _intOf(post['likes_count']),
              comments: _intOf(post['comments_count']),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stories
  // ---------------------------------------------------------------------------

  Widget _storiesTab() {
    if (_stories.isEmpty) {
      return _empty(
        icon: Icons.menu_book_outlined,
        title: 'No stories yet',
        body: 'Stories hold chapters — a longer home for your work.',
        actionLabel: 'Start a story',
        onAction: () => context.push('/stories/create').then((_) => _load(forceRefresh: true)),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _stories.length,
        itemBuilder: (context, index) {
          final story = _stories[index];
          final title = (story['title'] ?? 'Untitled').toString();
          final genre = (story['genre'] ?? '').toString();
          final chapters = story['chapters'];
          final chapterCount = chapters is List ? chapters.length : _intOf(story['chapter_count']) ?? 0;
          final status = (story['status'] ?? 'draft').toString();

          return MobileCard(
            onTap: () {
              final slug = (story['slug'] ?? story['id'] ?? '').toString();
              if (slug.isNotEmpty) context.push('/stories/$slug');
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ContentBadgeChip(
                      badge: ContentBadge(origin: ContentOrigin.creator, format: 'story'),
                      compact: true,
                    ),
                    const SizedBox(width: 7),
                    if (genre.isNotEmpty)
                      Text(
                        genre,
                        style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
                      ),
                    const Spacer(),
                    Text(
                      status == 'published' ? 'Live' : 'Draft',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: status == 'published' ? const Color(0xFF3E7A44) : AppTheme.warningColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.serifFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$chapterCount ${chapterCount == 1 ? 'chapter' : 'chapters'}',
                  style: TextStyle(fontSize: 11.5, color: Theme.of(context).textTheme.bodySmall?.color),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared bits
  // ---------------------------------------------------------------------------

  Widget _errorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
        border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty({
    required IconData icon,
    required String title,
    required String body,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
      children: [
        Icon(icon, size: 40, color: Theme.of(context).textTheme.bodySmall?.color),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.5, color: Theme.of(context).textTheme.bodySmall?.color),
        ),
        const SizedBox(height: 20),
        Center(child: FilledButton(onPressed: onAction, child: Text(actionLabel))),
      ],
    );
  }

  static int? _intOf(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String _formatCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}k';
    return value.toString();
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppTheme.serifFamily,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
      ),
    );
  }
}

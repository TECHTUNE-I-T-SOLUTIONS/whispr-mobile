import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// A creator's public portfolio.
///
/// Rebuilt to show the full picture the web portfolio shows: identity and
/// verification, bio, social links, the complete stat set (posts, stories,
/// followers, streak, points, badges), their published work grouped by type,
/// and the writing chains they take part in. Read-only — editing lives in the
/// creator dashboard.
class PortfolioScreen extends ConsumerStatefulWidget {
  final String penName;
  const PortfolioScreen({super.key, required this.penName});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  Map<String, dynamic>? _creator;
  List<Map<String, dynamic>> _posts = [];
  final List<Map<String, dynamic>> _chains = [];
  CreatorStats _stats = const CreatorStats();
  bool _loading = true;
  bool _following = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = ref.read(_creatorServiceProvider);

      // Resolve the pen name to a real creator first, then fan out. This is
      // the fix for the old behaviour, where the screen used the *signed-in*
      // user's `/creator/profile` and so showed your own portfolio no matter
      // whose name you opened.
      final creator = await service.getCreatorByPenName(widget.penName, forceRefresh: forceRefresh);
      final creatorId = (creator['id'] ?? '').toString();

      final results = await Future.wait([
        creatorId.isEmpty
            ? Future.value(<Map<String, dynamic>>[])
            : service.getCreatorPosts(creatorId, forceRefresh: forceRefresh),
      ]);

      if (!mounted) return;
      setState(() {
        _creator = creator;
        _posts = results.first;
        _stats = CreatorStats.fromJson(creator);
        _following = creator['is_following'] == true || creator['isFollowing'] == true;
        _loading = false;
      });
    } on CreatorNotFoundException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No creator goes by "@${widget.penName}".';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'We could not load this portfolio. Pull down to try again.';
      });
      debugPrint('[Portfolio] failed for ${widget.penName}: $e');
    }
  }

  void _sharePortfolio() {
    final penName = _creator?['pen_name']?.toString() ?? widget.penName;
    Share.share(
      'Read $penName on Whispr\nhttps://whisprwords.com/chronicles/portfolio/$penName',
      subject: '$penName on Whispr',
    );
  }

  Future<void> _toggleFollow() async {
    final creatorId = _creator?['id']?.toString();
    if (creatorId == null || creatorId.isEmpty) return;
    final next = !_following;
    setState(() => _following = next);
    try {
      await ref.read(_creatorServiceProvider).followCreator(creatorId, follow: next);
    } catch (e) {
      if (!mounted) return;
      setState(() => _following = !next);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update follow. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_creator?['pen_name']?.toString() ?? widget.penName),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            onPressed: _creator == null ? null : _sharePortfolio,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(forceRefresh: true),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    children: [
                      _header(),
                      const SizedBox(height: 16),
                      _statGrid(),
                      if (_badges.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _badgesRow(),
                      ],
                      if (_bio != null) ...[
                        const SizedBox(height: 22),
                        const _SectionLabel('About'),
                        const SizedBox(height: 8),
                        _bioCard(),
                      ],
                      if (_socials.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _socialRow(),
                      ],
                      const SizedBox(height: 22),
                      _worksSection(),
                      if (_chains.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        const _SectionLabel('Writing chains'),
                        const SizedBox(height: 10),
                        ..._chains.map(_chainTile),
                      ],
                    ],
                  ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Derived fields
  // ---------------------------------------------------------------------------

  String? get _bio {
    final raw = _creator?['bio']?.toString().trim();
    return raw == null || raw.isEmpty ? null : raw;
  }

  List<String> get _badges {
    final raw = _creator?['badges'];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  Map<String, dynamic> get _socials {
    final raw = _creator?['social_links'];
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v))
        ..removeWhere((_, v) => v == null || v.toString().trim().isEmpty);
    }
    return const {};
  }

  List<String> get _categories {
    final raw = _creator?['categories'];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  bool get _isVerified => _creator?['is_verified'] == true;

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _header() {
    final creator = _creator ?? const {};
    final avatar = (creator['profile_image_url'] ?? creator['avatar_url'] ?? '').toString();
    final penName = (creator['pen_name'] ?? widget.penName).toString();
    final joined = _memberSince();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusXL),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Theme.of(context).brightness == Brightness.dark
              ? [const Color(0xFF1C1010), const Color(0xFF2B1214)]
              : [AppTheme.primaryColor, const Color(0xFF5E0E0F)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.6),
                  image: avatar.isEmpty
                      ? null
                      : DecorationImage(
                          image: NetworkImage(avatar),
                          fit: BoxFit.cover,
                          onError: (_, _) {},
                        ),
                ),
                child: avatar.isEmpty
                    ? Center(
                        child: Text(
                          penName.isNotEmpty ? penName[0].toUpperCase() : 'W',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            fontFamily: AppTheme.serifFamily,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            penName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                              fontFamily: AppTheme.serifFamily,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (_isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, size: 17, color: Color(0xFF8FD6FF)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        if (_categories.isNotEmpty) _categories.take(2).join(' · '),
                        if (joined != null) 'Since $joined',
                      ].where((e) => e.isNotEmpty).join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _toggleFollow,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: _following ? 0.5 : 0.3),
                    ),
                    backgroundColor: _following ? Colors.transparent : Colors.white.withValues(alpha: 0.12),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                    textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  child: Text(_following ? 'Following' : 'Follow'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _sharePortfolio,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryColor,
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                    textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _memberSince() {
    final raw = _creator?['created_at'] ?? _creator?['joined_at'];
    final date = DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return null;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.year}';
  }

  // ---------------------------------------------------------------------------
  // Stats
  // ---------------------------------------------------------------------------

  Widget _statGrid() {
    final published = _stats.publishedPosts > 0 ? _stats.publishedPosts : _posts.length;
    final tiles = <(String, String, IconData)>[
      ('Posts', '$published', Icons.article_outlined),
      if (_stats.totalStories > 0) ('Stories', '${_stats.totalStories}', Icons.menu_book_outlined),
      ('Followers', _formatCount(_stats.totalFollowers), Icons.people_outline_rounded),
      ('Engagement', _formatCount(_stats.effectiveEngagement), Icons.favorite_border_rounded),
      if (_stats.points > 0) ('Points', _formatCount(_stats.points), Icons.stars_outlined),
      if (_stats.currentStreak > 0) ('Streak', '${_stats.currentStreak}d', Icons.local_fire_department_outlined),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.28,
      children: tiles.map((t) {
        final (label, value, icon) = t;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.1),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _badgesRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _badges.map((badge) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.warningColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.workspace_premium_outlined, size: 13, color: AppTheme.warningColor),
              const SizedBox(width: 5),
              Text(
                badge.replaceAll('_', ' '),
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.warningColor),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Bio + socials
  // ---------------------------------------------------------------------------

  Widget _bioCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Text(
        _bio!,
        style: TextStyle(
          fontFamily: AppTheme.serifFamily,
          fontSize: 14.5,
          height: 1.62,
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }

  Widget _socialRow() {
    const icons = <String, IconData>{
      'twitter': Icons.alternate_email_rounded,
      'x': Icons.alternate_email_rounded,
      'instagram': Icons.camera_alt_outlined,
      'facebook': Icons.facebook_rounded,
      'linkedin': Icons.work_outline_rounded,
      'youtube': Icons.play_circle_outline_rounded,
      'tiktok': Icons.music_note_outlined,
      'website': Icons.language_rounded,
      'medium': Icons.article_outlined,
      'substack': Icons.mail_outline_rounded,
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _socials.entries.map((entry) {
        final key = entry.key.toLowerCase();
        final icon = icons[key] ?? Icons.link_rounded;
        return InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: () async {
            final uri = Uri.tryParse(entry.value.toString());
            if (uri == null) return;
            if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
              debugPrint('[Portfolio] could not open ${entry.value}');
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.14)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14),
                const SizedBox(width: 6),
                Text(
                  key[0].toUpperCase() + key.substring(1),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Published work
  // ---------------------------------------------------------------------------

  Widget _worksSection() {
    if (_posts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Published work'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  size: 26,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                const SizedBox(height: 8),
                Text(
                  'Nothing published yet',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Group by format so a reader can scan poems separately from essays.
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final post in _posts) {
      final type = (post['post_type'] ?? post['type'] ?? 'poem').toString().toLowerCase();
      grouped.putIfAbsent(type, () => []).add(post);
    }

    const order = ['poem', 'blog', 'chronicle', 'story'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Published work (${_posts.length})'),
        const SizedBox(height: 10),
        for (final type in order)
          if (grouped[type] != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Text(
                _pluralLabel(type, grouped[type]!.length),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
            ...grouped[type]!.map(_postTile),
          ],
      ],
    );
  }

  String _pluralLabel(String type, int count) {
    final label = switch (type) {
      'blog' => 'essay',
      'chronicle' => 'chronicle',
      'story' => 'story',
      _ => 'poem',
    };
    return '$count ${label.toUpperCase()}${count == 1 ? '' : 'S'}';
  }

  Widget _postTile(Map<String, dynamic> post) {
    final title = (post['title'] ?? 'Untitled').toString();
    final slug = (post['slug'] ?? post['id'] ?? '').toString();
    final excerpt = post['excerpt'] ?? post['content'];
    final type = (post['post_type'] ?? post['type'] ?? 'poem').toString();
    final badge = ContentBadge(
      origin: ContentOrigin.creator,
      format: type,
      creatorName: _creator?['pen_name']?.toString(),
    );

    return MobileCard(
      onTap: () {
        if (slug.isEmpty) return;
        final isUuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(slug);
        context.push(isUuid ? '/post/$slug' : '/chronicles/$slug');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ContentBadgeChip(badge: badge, compact: true),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _relativeDate(post['published_at'] ?? post['created_at']),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTheme.serifFamily,
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          GatedPreview(
            text: excerpt?.toString(),
            fallback: 'Tap to read this ${type == 'blog' ? 'essay' : type}.',
            maxCharacters: 120,
          ),
          PostStatsRow(
            reads: _intOf(post['view_count'] ?? post['views_count']),
            likes: _intOf(post['likes_count']),
            comments: _intOf(post['comments_count']),
          ),
        ],
      ),
    );
  }

  Widget _chainTile(Map<String, dynamic> chain) {
    final title = (chain['title'] ?? 'Untitled chain').toString();
    final entries = chain['entries'] is List ? (chain['entries'] as List).length : _intOf(chain['entries_count']) ?? 0;
    return MobileCard(
      onTap: () => context.push('/chains/${chain['id']}'),
      child: Row(
        children: [
          Icon(Icons.link_rounded, size: 17, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
                const SizedBox(height: 2),
                Text(
                  '$entries ${entries == 1 ? 'entry' : 'entries'}',
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

  Widget _errorState() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.person_search_outlined, size: 40, color: Theme.of(context).textTheme.bodySmall?.color),
        const SizedBox(height: 14),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton(
            onPressed: () => _load(forceRefresh: true),
            child: const Text('Try again'),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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

  static String _relativeDate(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontFamily: AppTheme.serifFamily,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/api_service.dart';
import '../../../core/services/content_cache_service.dart';
import '../../../core/services/portfolio_service.dart';
import '../../../core/theme/app_theme.dart';

final _portfolioServiceProvider = Provider((ref) => PortfolioService(ApiService.instance, ContentCacheService()));

class PortfolioScreen extends ConsumerStatefulWidget {
  final String penName;
  const PortfolioScreen({super.key, required this.penName});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _loading = true);
    try {
      final data = await ref.read(_portfolioServiceProvider).getPortfolioByPenName(
        widget.penName,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() { _data = data; _loading = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading portfolio: $e')),
        );
      }
    }
  }

  void _sharePortfolio() {
    final penName = widget.penName;
    final url = 'https://whisprwords.com/chronicles/portfolio/$penName';
    Share.share(
      'Check out my writing portfolio on Whispr!\n\n$url',
      subject: '$penName - Whispr Portfolio',
    );
  }

  @override
  Widget build(BuildContext context) {
    final creator = _data?['creator'] as Map<String, dynamic>?;
    final posts = (_data?['posts'] as List?) ?? [];
    final chains = (_data?['chains'] as List?) ?? [];

    // Calculate stats
    final totalPosts = posts.length;
    final totalChains = chains.length;
    int totalLikes = 0;
    int totalViews = 0;
    for (final post in posts) {
      totalLikes += (post['likes_count'] ?? post['likesCount'] ?? 0) as int;
      totalViews += (post['views_count'] ?? post['viewsCount'] ?? 0) as int;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.penName),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/more'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _sharePortfolio,
            tooltip: 'Share Portfolio',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(forceRefresh: true),
          ),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (creator != null) _buildHeader(creator, totalPosts, totalChains, totalLikes, totalViews),
          const SizedBox(height: 24),

          // Stats Cards
          _buildStatsRow(totalPosts, totalChains, totalLikes, totalViews),
          const SizedBox(height: 24),

          // Bio section
          if (creator != null && creator['bio'] != null && (creator['bio'] as String).isNotEmpty) ...[
            _buildSectionTitle('About'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
              ),
              child: Text(
                creator['bio'] ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Latest Publications
          _buildSectionTitle('Latest Publications (${posts.length})'),
          const SizedBox(height: 12),
          if (posts.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  'No publications yet',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ),
            )
          else
            ...posts.map((p) => _PostTile(post: Map<String, dynamic>.from(p))),

          // Chains section
          if (chains.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('Writing Chains'),
            const SizedBox(height: 12),
            ...chains.map((c) => _buildChainTile(c)),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> creator, int totalPosts, int totalChains, int totalLikes, int totalViews) {
    final memberSince = creator['created_at'] ?? creator['createdAt'] ?? creator['joined_date'];
    final memberSinceStr = memberSince != null
        ? DateTime.tryParse(memberSince.toString())?.toLocal().toString().split(' ')[0] ?? ''
        : '';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF111111), Color(0xFF4B1717)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                backgroundImage: creator['profile_image_url'] != null
                    ? CachedNetworkImageProvider(creator['profile_image_url'])
                    : null,
                child: creator['profile_image_url'] == null
                    ? Text(
                        ((creator['pen_name'] as String?)?.isNotEmpty == true
                            ? (creator['pen_name'] as String)[0]
                            : 'W').toString().toUpperCase(),
                        style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      creator['pen_name'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      creator['full_name'] ?? creator['name'] ?? '',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                    if (creator['location'] != null && (creator['location'] as String).isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Text(
                            creator['location'],
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                    if (memberSinceStr.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Text(
                            'Member since $memberSinceStr',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Share button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _sharePortfolio,
              icon: const Icon(Icons.share, color: Colors.white, size: 18),
              label: const Text('Share Portfolio', style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(int totalPosts, int totalChains, int totalLikes, int totalViews) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Posts', totalPosts.toString(), Icons.article)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Chains', totalChains.toString(), Icons.link)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Likes', totalLikes.toString(), Icons.favorite)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Views', totalViews.toString(), Icons.visibility)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildChainTile(dynamic chain) {
    final c = Map<String, dynamic>.from(chain);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.link, color: AppTheme.primaryColor),
        ),
        title: Text(c['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          c['description'] ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => context.push('/chains/${c['id']}'),
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  final Map<String, dynamic> post;
  const _PostTile({required this.post});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
      boxShadow: [
        BoxShadow(
          color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        final id = post['id'];
        if (id != null) {
          context.push('/chronicles/$id');
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover thumbnail if available
            if (post['coverImage'] != null || post['cover_image_url'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post['coverImage'] ?? post['cover_image_url'],
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 80,
                    height: 80,
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    child: Icon(Icons.article, color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                ),
              )
            else
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.article, color: AppTheme.primaryColor.withValues(alpha: 0.3)),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post['title'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (post['excerpt'] != null)
                    Text(
                      post['excerpt'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (post['type'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            (post['type'] as String).toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Icon(Icons.favorite_border, size: 12, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text(
                        '${post['likes_count'] ?? post['likesCount'] ?? 0}',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.3)),
          ],
        ),
      ),
    ),
  );
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/chronicles.dart';
import '../../core/models/post.dart';
import '../../core/network/api_service.dart';
import '../../core/theme/app_theme.dart';

class CreatorProfileScreen extends ConsumerStatefulWidget {
  final String creatorId;

  const CreatorProfileScreen({super.key, required this.creatorId});

  @override
  ConsumerState<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends ConsumerState<CreatorProfileScreen> {
  Creator? _creator;
  List<Post> _posts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCreatorProfile();
  }

  Future<void> _fetchCreatorProfile() async {
    try {
      setState(() => _isLoading = true);
      final apiService = ref.read(apiServiceProvider);

      // Fetch creator profile
      final creatorResponse = await apiService.get('/chronicles/creators/${widget.creatorId}');
      if (creatorResponse['success'] == true) {
        final creator = Creator.fromJson(creatorResponse['creator']);

        // Fetch creator's posts
        final postsResponse = await apiService.get('/chronicles/creators/${widget.creatorId}/posts');
        final posts = postsResponse['success'] == true
            ? (postsResponse['posts'] as List).map((json) => Post.fromJson(json)).toList()
            : <Post>[];

        setState(() {
          _creator = creator;
          _posts = posts;
          _isLoading = false;
        });
      } else {
        throw Exception(creatorResponse['error'] ?? 'Failed to load creator profile');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Creator Profile'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: AppTheme.spacingM),
                      ElevatedButton(
                        onPressed: _fetchCreatorProfile,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _creator == null
                  ? const Center(child: Text('Creator not found'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile header
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spacingM),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundImage: _creator!.profileImageUrl != null
                                        ? NetworkImage(_creator!.profileImageUrl!)
                                        : null,
                                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                    child: _creator!.profileImageUrl == null
                                        ? Text(
                                            _creator!.penName.substring(0, 1).toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: AppTheme.spacingM),
                                  Text(
                                    _creator!.penName,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_creator!.displayName != _creator!.penName) ...[
                                    const SizedBox(height: AppTheme.spacingXS),
                                    Text(
                                      _creator!.displayName,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).textTheme.bodySmall?.color,
                                      ),
                                    ),
                                  ],
                                  if (_creator!.bio.isNotEmpty) ...[
                                    const SizedBox(height: AppTheme.spacingM),
                                    Text(
                                      _creator!.bio,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                  const SizedBox(height: AppTheme.spacingM),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildStat('${_creator!.engagementCount}', 'Followers'),
                                      const SizedBox(width: AppTheme.spacingL),
                                      _buildStat('${_creator!.postCount}', 'Posts'),
                                      const SizedBox(width: AppTheme.spacingL),
                                      _buildStat('${_creator!.totalPoints}', 'Points'),
                                    ],
                                  ),
                                  if (_creator!.verifiedBadge) ...[
                                    const SizedBox(height: AppTheme.spacingM),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.verified,
                                          color: Theme.of(context).colorScheme.primary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: AppTheme.spacingXS),
                                        Text(
                                          'Verified Creator',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: AppTheme.spacingL),

                          // Posts section
                          Text(
                            'Posts (${_posts.length})',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingM),

                          ..._posts.map((post) => Card(
                                margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
                                child: InkWell(
                                  onTap: () {
                                    // TODO: Navigate to post detail
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(AppTheme.spacingM),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          post.title,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (post.excerpt != null && post.excerpt!.isNotEmpty) ...[
                                          const SizedBox(height: AppTheme.spacingXS),
                                          Text(
                                            post.excerpt!,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Theme.of(context).textTheme.bodySmall?.color,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: AppTheme.spacingS),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.favorite,
                                              size: 16,
                                              color: Theme.of(context).textTheme.bodySmall?.color,
                                            ),
                                            const SizedBox(width: AppTheme.spacingXS),
                                            Text(
                                              '${post.likesCount ?? 0}',
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                            const SizedBox(width: AppTheme.spacingM),
                                            Icon(
                                              Icons.comment,
                                              size: 16,
                                              color: Theme.of(context).textTheme.bodySmall?.color,
                                            ),
                                            const SizedBox(width: AppTheme.spacingXS),
                                            Text(
                                              '${post.commentsCount ?? 0}',
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                            const Spacer(),
                                            Text(
                                              _formatDate(DateTime.parse(post.createdAt ?? DateTime.now().toIso8601String())),
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
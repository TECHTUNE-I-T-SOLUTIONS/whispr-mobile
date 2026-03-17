import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/post.dart';
import '../../../core/network/api_service.dart';
import '../../../core/theme/app_theme.dart';

class WhisprWallScreen extends ConsumerStatefulWidget {
  const WhisprWallScreen({super.key});

  @override
  ConsumerState<WhisprWallScreen> createState() => _WhisprWallScreenState();
}

class _WhisprWallScreenState extends ConsumerState<WhisprWallScreen> {
  List<WallPost> _posts = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _postController = TextEditingController();
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _fetchWallPosts();
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  Future<void> _fetchWallPosts() async {
    try {
      setState(() => _isLoading = true);
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get('/wall');
      if (response['success'] == true) {
        final posts = (response['posts'] as List).map((json) => WallPost.fromJson(json)).toList();
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      } else {
        throw Exception(response['error'] ?? 'Failed to load wall posts');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _postToWall() async {
    final content = _postController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    setState(() => _isPosting = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post('/wall', data: {'content': content});

      if (response['success'] != false) {
        // Post successful
        _postController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Posted anonymously to the wall!')),
          );
        }
        // Refresh posts
        await _fetchWallPosts();
      } else {
        throw Exception(response['error'] ?? 'Failed to post');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: $e')),
        );
      }
    } finally {
      setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Whispr Wall'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchWallPosts,
          ),
        ],
      ),
      body: _buildContent(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPostDialog(),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Share Thought', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showPostDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Share your thoughts anonymously'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _postController,
                maxLines: 5,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: 'What\'s on your mind?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                  ),
                  contentPadding: const EdgeInsets.all(AppTheme.spacingS),
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              const Text(
                'Your post will be shared anonymously',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _postController.clear();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isPosting
                  ? null
                  : () async {
                      if (_postController.text.trim().isEmpty) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a message')),
                          );
                        }
                        return;
                      }
                      // Capture navigator before async operation
                      final navigator = Navigator.of(context);
                      setState(() => _isPosting = true);
                      try {
                        await _postToWall();
                        _postController.clear();
                        if (mounted) {
                          navigator.pop();
                        }
                      } finally {
                        setState(() => _isPosting = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: _isPosting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Post'),
            ),
          ],
        ),
      ),
    ).then((_) {
      // Dialog closed
    });
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: AppTheme.spacingM),
            ElevatedButton(
              onPressed: _fetchWallPosts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 64,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'The wall is empty',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'Be the first to share your thoughts!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchWallPosts,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spacingS),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return Card(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Question
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey.withValues(alpha: 0.1),
                        child: const Icon(Icons.person, size: 16, color: Colors.grey),
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      const Text(
                        'Anonymous User',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingXS,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'QUESTION',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  Text(
                    post.content,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),

                  // Admin Response (if available)
                  if (post.responses != null && post.responses!.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingL),
                    ...post.responses!.map((response) => Container(
                      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      decoration: BoxDecoration(
                        color: response.isAdmin
                            ? AppTheme.primaryColor.withValues(alpha: 0.05)
                            : Colors.grey.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                        border: Border.all(
                          color: response.isAdmin
                              ? AppTheme.primaryColor.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: response.isAdmin
                                    ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.1),
                                backgroundImage: response.author?.avatarUrl != null
                                    ? NetworkImage(response.author!.avatarUrl!)
                                    : null,
                                onBackgroundImageError: response.author?.avatarUrl != null
                                    ? (exception, stackTrace) {
                                        debugPrint('Failed to load response avatar: $exception');
                                      }
                                    : null,
                                child: response.author?.avatarUrl == null
                                    ? Text(
                                        response.isAdmin
                                            ? (response.author?.displayName[0].toUpperCase() ?? 'A')
                                            : 'U',
                                        style: TextStyle(
                                          color: response.isAdmin
                                              ? AppTheme.primaryColor
                                              : Colors.grey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Text(
                                response.isAdmin
                                    ? (response.author?.displayName ?? 'Whispr Admin')
                                    : 'Anonymous User',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingXS,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: response.isAdmin
                                      ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                      : Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  response.isAdmin ? 'RESPONSE' : 'REPLY',
                                  style: TextStyle(
                                    color: response.isAdmin
                                        ? AppTheme.primaryColor
                                        : Colors.grey,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            response.content,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (response.createdAt != null) ...[
                            const SizedBox(height: AppTheme.spacingXS),
                            Text(
                              'Posted ${DateTime.parse(response.createdAt!).toLocal().toString().split(' ')[0]}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )),
                  ],

                  // Timestamp
                  const SizedBox(height: AppTheme.spacingM),
                  Text(
                    post.createdAt != null
                        ? 'Posted ${DateTime.parse(post.createdAt!).toLocal().toString().split(' ')[0]}'
                        : 'Posted recently',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        },

      ),

    );

  }

}
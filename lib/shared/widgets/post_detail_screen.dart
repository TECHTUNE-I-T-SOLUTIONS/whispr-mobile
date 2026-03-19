import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/comment.dart';
import '../../core/models/post.dart';
import '../../core/network/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/auth_state.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  Post? _post;
  final List<Comment> _comments = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;
  bool _hasLiked = false;
  int _likesCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchPostDetails();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchPostDetails() async {
    try {
      setState(() => _isLoading = true);
      final apiService = ref.read(apiServiceProvider);

      // Try to fetch post details - first try admin posts, then chronicle posts
      dynamic postResponse;
      try {
        postResponse = await apiService.get('/posts/${widget.postId}');
      } catch (e) {
        // If admin posts endpoint fails, try chronicles endpoint
        postResponse = await apiService.get('/chronicles/posts/${widget.postId}');
      }
      
      _post = Post.fromJson(postResponse['data'] ?? postResponse);

      // Fetch comments (if endpoint exists)
      try {
        final commentsResponse = await apiService.get('/comments?post_id=${widget.postId}');
        final commentsData = commentsResponse['comments'] as List;
        _comments.clear();
        _comments.addAll(commentsData.map((json) => Comment.fromJson(json)).toList());
      } catch (e) {
        // Comments endpoint might not exist, continue without them
        debugPrint('Could not fetch comments: $e');
      }

      // Fetch reactions
      try {
        final reactionsResponse = await apiService.get('/reactions?post_id=${widget.postId}');
        final reactions = reactionsResponse['reactions'] as List;
        final userReaction = reactionsResponse['userReaction'];

        // Find like count and user's like status
        _likesCount = 0;
        _hasLiked = false;
        for (var reaction in reactions) {
          if (reaction['type'] == 'like') {
            _likesCount = reaction['count'];
          }
        }
        _hasLiked = userReaction == 'like';
      } catch (e) {
        // Reactions endpoint might not exist, use counts from post object
        _likesCount = _post?.likesCount ?? 0;
        debugPrint('Could not fetch reactions: $e');
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _likePost() async {
    final authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated) {
      _showAuthRequiredDialog('like this post');
      return;
    }

    if (_post == null) return;

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post('/reactions', data: {
        'post_id': widget.postId,
        'reaction_type': 'like',
      });

      // Update local state based on the action
      if (response['action'] == 'added') {
        setState(() {
          _hasLiked = true;
          _likesCount++;
        });
      } else if (response['action'] == 'removed') {
        setState(() {
          _hasLiked = false;
          _likesCount = (_likesCount > 0) ? _likesCount - 1 : 0;
        });
      } else if (response['action'] == 'updated') {
        // If updating from another reaction type to like
        setState(() {
          _hasLiked = true;
          // Note: count might not change if replacing another reaction
        });
      }

      if (mounted) {
        final message = _hasLiked ? 'Post liked!' : 'Like removed!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update like: $e')),
        );
      }
    }
  }

  Future<void> _submitComment() async {
    final authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated || authState.user == null) {
      _showAuthRequiredDialog('comment on this post');
      return;
    }

    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isSubmittingComment = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post('/comments', data: {
        'post_id': widget.postId,
        'author_name': authState.user!.penName,
        'author_email': authState.user!.email,
        'content': _commentController.text.trim(),
      });

      if (response['comment'] != null) {
        _commentController.clear();
        await _fetchPostDetails(); // Refresh comments
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Comment posted!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingComment = false);
      }
    }
  }

  void _showAuthRequiredDialog(String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Required'),
        content: Text('You need to be logged in to $action.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to login screen
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/chronicles'),
        ),
        title: const Text('Post Details'),
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
                        onPressed: _fetchPostDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _post == null
                  ? const Center(child: Text('Post not found'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Post content
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spacingM),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_post!.coverImage != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                                      child: Image.network(
                                        _post!.coverImage!,
                                        width: double.infinity,
                                        height: 200,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  const SizedBox(height: AppTheme.spacingM),
                                  Text(
                                    _post!.title,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_post!.excerpt != null) ...[
                                    const SizedBox(height: AppTheme.spacingS),
                                    Text(
                                      _post!.excerpt!,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).textTheme.bodySmall?.color,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: AppTheme.spacingM),
                                  if (_post!.content != null && _post!.content!.isNotEmpty)
                                    Html(
                                      data: _post!.content!,
                                      style: {
                                        "p": Style(
                                          margin: Margins.only(bottom: 16),
                                          lineHeight: LineHeight.number(1.6),
                                        ),
                                        "i": Style(
                                          fontStyle: FontStyle.italic,
                                        ),
                                        "strong": Style(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      },
                                    )
                                  else
                                    const Text('No content available'),
                                  const SizedBox(height: AppTheme.spacingM),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          _hasLiked ? Icons.favorite : Icons.favorite_border,
                                          color: _hasLiked
                                              ? Theme.of(context).colorScheme.primary
                                              : Theme.of(context).textTheme.bodySmall?.color,
                                        ),
                                        onPressed: _likePost,
                                      ),
                                      Text('$_likesCount'),
                                      const SizedBox(width: AppTheme.spacingM),
                                      Icon(
                                        Icons.comment,
                                        color: Theme.of(context).textTheme.bodySmall?.color,
                                      ),
                                      const SizedBox(width: AppTheme.spacingXS),
                                      Text('${_post!.commentsCount ?? 0}'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: AppTheme.spacingL),

                          // Comments section
                          Text(
                            'Comments (${_comments.length})',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingM),

                          // Add comment
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spacingM),
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _commentController,
                                    decoration: const InputDecoration(
                                      hintText: 'Write a comment...',
                                      border: OutlineInputBorder(),
                                    ),
                                    maxLines: 3,
                                  ),
                                  const SizedBox(height: AppTheme.spacingM),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      onPressed: _isSubmittingComment ? null : _submitComment,
                                      child: _isSubmittingComment
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Text('Post Comment'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: AppTheme.spacingM),

                          // Comments list
                          ..._comments.map((comment) => Card(
                                margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
                                child: Padding(
                                  padding: const EdgeInsets.all(AppTheme.spacingM),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                            child: Text(
                                              comment.authorName.substring(0, 1).toUpperCase(),
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: AppTheme.spacingS),
                                          Text(
                                            comment.authorName,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          const Spacer(),
                                          Text(
                                            _formatDate(DateTime.parse(comment.createdAt ?? DateTime.now().toIso8601String())),
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppTheme.spacingS),
                                      Text(comment.content),
                                    ],
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ),
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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/post.dart';
import '../../../core/network/api_service.dart';
import '../../../core/services/chronicles_service.dart';
import '../../../core/services/content_cache_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../features/auth/auth_state.dart';

final _chroniclesServiceProvider = Provider((ref) => ChroniclesService(ApiService.instance, ContentCacheService()));

class ChroniclesPostDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const ChroniclesPostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<ChroniclesPostDetailScreen> createState() => _ChroniclesPostDetailScreenState();
}

class _ChroniclesPostDetailScreenState extends ConsumerState<ChroniclesPostDetailScreen> {
  Post? _post;
  bool _isLoading = true;
  String? _error;
  bool _hasLiked = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  List<Map<String, dynamic>> _comments = [];
  final Map<String, int> _commentLikesCount = {}; // Track likes for each comment
  final Map<String, bool> _commentLikedByUser = {}; // Track if user liked each comment
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    _fetchChronicleDetails();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchChronicleDetails() async {
    try {
      setState(() => _isLoading = true);
      final postData = await ref.read(_chroniclesServiceProvider).getPost(widget.postId);
      _post = Post.fromJson(postData);
      final apiService = ref.read(apiServiceProvider);

      // Fetch comments for chronicles posts
      try {
        final commentsResponse = await apiService.get(
          '/chronicles/posts/${widget.postId}/comments',
        );
        debugPrint('Fetched comments response: ${commentsResponse.runtimeType} - $commentsResponse');
        
        List? commentsList;
        int? fetchedTotal;
        
        if (commentsResponse is Map<String, dynamic>) {
          commentsList = commentsResponse['comments'] as List?;
          fetchedTotal = commentsResponse['total'] as int?;
          debugPrint('API Response - Comments: ${commentsList?.length}, Total: $fetchedTotal');
        } else if (commentsResponse is List) {
          commentsList = commentsResponse;
          debugPrint('Comments list directly: ${commentsList.length}');
        }
        
        if (commentsList != null && commentsList.isNotEmpty) {
          _comments = List<Map<String, dynamic>>.from(
            commentsList.map((e) {
              if (e is Map) {
                return Map<String, dynamic>.from(e);
              }
              return <String, dynamic>{};
            }).where((e) => e.isNotEmpty)
          );
        } else {
          _comments = [];
        }
        
        // Update the comments count
        _commentsCount = _comments.length;
        debugPrint('INFO: Loaded $_commentsCount comments for post ${widget.postId}');

        // Fetch comment reactions for each comment
        if (_comments.isNotEmpty) {
          await _fetchCommentReactions();
        }
      } catch (e) {
        debugPrint('ERROR fetching comments: $e');
        // Fallback to post's comments count if available
        _commentsCount = _post?.commentsCount ?? 0;
        _comments = [];
      }

      // Fetch reactions for chronicles posts
      try {
        final reactionsResponse = await apiService.get(
          '/chronicles/posts/${widget.postId}/reactions',
        );
        final reactions = reactionsResponse['reactions'] as List?;
        final userReaction = reactionsResponse['userReaction'];

        _likesCount = 0;
        _hasLiked = false;
        
        if (reactions != null) {
          for (var reaction in reactions) {
            if (reaction['type'] == 'like' || reaction['reaction_type'] == 'like') {
              _likesCount = reaction['count'] ?? reactions.where((r) => r['reaction_type'] == 'like').length ?? 0;
            }
          }
        }
        _hasLiked = userReaction == 'like';
      } catch (e) {
        debugPrint('Could not fetch reactions: $e');
        _likesCount = _post?.likesCount ?? 0;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
      debugPrint('Error fetching chronicle details: $e');
    }
  }

  Future<void> _fetchCommentReactions() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final authState = ref.read(authStateProvider);

      // Fetch reactions for each comment
      for (final comment in _comments) {
        final commentId = comment['id']?.toString() ?? '';
        if (commentId.isEmpty || commentId.startsWith('temp_')) {
          continue; // Skip optimistic comments
        }

        try {
          final reactionsResponse = await apiService.get(
            '/chronicles/posts/${widget.postId}/comments/$commentId/reactions',
          );

          // Update likes count
          final likesCount = reactionsResponse['likes_count'] as int? ?? 
                             reactionsResponse['reactions_count'] as int? ?? 0;
          _commentLikesCount[commentId] = likesCount;

          // Check if user has liked this comment
          if (authState.isAuthenticated) {
            final userHasLiked = reactionsResponse['user_has_liked'] as bool? ?? false;
            _commentLikedByUser[commentId] = userHasLiked;
          }

          debugPrint('Loaded reactions for comment $commentId: likes=$likesCount, userLiked=${_commentLikedByUser[commentId]}');
        } catch (e) {
          debugPrint('Could not fetch reactions for comment $commentId: $e');
          // Set defaults from comment data if available
          _commentLikesCount[commentId] = comment['likes_count'] ?? 0;
          _commentLikedByUser[commentId] = false;
        }
      }

      // Rebuild UI after loading all reactions
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error fetching comment reactions: $e');
    }
  }

  Future<void> _toggleLike() async {
    final authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated) {
      _showAuthRequiredDialog('like this chronicle');
      return;
    }

    try {
      final apiService = ref.read(apiServiceProvider);
      
      if (_hasLiked) {
        // Unlike - use DELETE to chronicles-specific endpoint
        await apiService.delete(
          '/chronicles/posts/${widget.postId}/reactions/like',
        );
        setState(() {
          _hasLiked = false;
          _likesCount = (_likesCount - 1).clamp(0, 999999);
        });
      } else {
        // Like - use POST to chronicles-specific endpoint
        await apiService.post(
          '/chronicles/posts/${widget.postId}/reactions',
          data: {
            'reaction_type': 'like',
          },
        );
        setState(() {
          _hasLiked = true;
          _likesCount += 1;
        });
      }
      
      if (mounted) {
        final message = _hasLiked ? 'Chronicle liked!' : 'Like removed!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      debugPrint('Error toggling like: $e');
    }
  }

  Future<void> _submitComment() async {
    final authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated || authState.user == null) {
      _showAuthRequiredDialog('comment on this chronicle');
      return;
    }

    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a comment')),
      );
      return;
    }

    final commentText = _commentController.text.trim();
    final authorName = authState.user?.penName ?? 'Anonymous';
    final authorEmail = authState.user?.email ?? '';

    // Optimistic update - add comment immediately
    final optimisticComment = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'content': commentText,
      'author_name': authorName,
      'author_email': authorEmail,
      'created_at': DateTime.now().toIso8601String(),
      'is_optimistic': true, // Mark as optimistic
    };

    setState(() {
      _isSubmittingComment = true;
      _comments.insert(0, optimisticComment); // Add to top of comments
      _commentsCount += 1;
      _commentController.clear();
    });

    try {
      await ref.read(apiServiceProvider).post(
        '/chronicles/posts/${widget.postId}/comments',
        data: {
          'content': commentText,
          'author_name': authorName,
          'author_email': authorEmail,
        },
      );

      if (mounted) {
        // Remove the optimistic marker since it succeeded
        setState(() {
          final index = _comments.indexWhere((c) => c['id'] == optimisticComment['id']);
          if (index != -1) {
            _comments[index].remove('is_optimistic');
          }
        });

        // Close the dialog if still mounted
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment posted successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Remove optimistic comment on failure
        setState(() {
          _comments.removeWhere((c) => c['id'] == optimisticComment['id']);
          _commentsCount -= 1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post comment: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      debugPrint('Error posting comment: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmittingComment = false);
      }
    }
  }

  Future<void> _shareChronicle() async {
    if (_post == null) return;

    try {
      final apiService = ref.read(apiServiceProvider);
      // Use the deeplink API endpoint which handles app and web redirects
      final shareUrl = '${AppConstants.shareBaseUrl}/api/deeplink?type=chronicles&id=${widget.postId}';
      final subject = _post!.title;
      final message = '''
Check out this chronicle: "${_post!.title}"

${_post!.excerpt ?? _post!.content?.substring(0, 100) ?? ''}

$shareUrl
''';

      // Track the share using the dedicated chronicles endpoint
      try {
        await apiService.post(
          '/chronicles/posts/${widget.postId}/shares',
          data: {
            'share_platform': 'native_share',
          },
        );
      } catch (e) {
        debugPrint('Could not track share: $e');
        // Continue even if tracking fails
      }

      await Share.share(
        message,
        subject: subject,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
      debugPrint('Error sharing: $e');
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
              context.go('/login');
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  void _showCommentDialog() {
    final authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated) {
      _showAuthRequiredDialog('comment on this chronicle');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: !_isSubmittingComment, // Prevent dismissing while submitting
      builder: (context) => PopScope(
        canPop: !_isSubmittingComment, // Prevent back gesture while submitting
        child: AlertDialog(
          title: const Text('Add Comment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _commentController,
                maxLines: 4,
                enabled: !_isSubmittingComment, // Disable input while submitting
                decoration: InputDecoration(
                  hintText: 'Write your comment...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                ),
              ),
              if (_isSubmittingComment) ...
                [
                  const SizedBox(height: AppTheme.spacingM),
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    'Posting comment...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isSubmittingComment
                  ? null
                  : () {
                      _commentController.clear();
                      Navigator.of(context).pop(); // Properly close dialog
                    },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isSubmittingComment ? null : _submitComment,
              child: _isSubmittingComment
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Post Comment'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/chronicles'),
        ),
        title: Text(
          _post?.title ?? 'Chronicle',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _buildChronicleView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'Failed to Load Chronicle',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          ElevatedButton.icon(
            onPressed: _fetchChronicleDetails,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildChronicleView() {
    if (_post == null) {
      return const Center(
        child: Text('Chronicle not found'),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image if available
          if (_post!.coverImage != null)
            Container(
              width: double.infinity,
              height: 250,
              color: Theme.of(context).cardColor,
              child: Image.network(
                _post!.coverImage!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 64,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  );
                },
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Post type badge
                if (_post!.type.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingM,
                        vertical: AppTheme.spacingXS,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _post!.type.toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                // Title
                Text(
                  _post!.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: AppTheme.spacingM),

                // Meta information
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: AppTheme.spacingXS),
                    Text(
                      _post!.publishedAt != null ? _formatDate(_post!.publishedAt!) : 'Recent',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingL),
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: AppTheme.spacingXS),
                    Text(
                      '${_estimateReadTime(_post!.content ?? '')} min read',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.spacingL),

                // Tags if available
                if (_post!.tags != null && _post!.tags!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacingL),
                    child: Wrap(
                      spacing: AppTheme.spacingS,
                      runSpacing: AppTheme.spacingS,
                      children: _post!.tags!.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingM,
                            vertical: AppTheme.spacingXS,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Text(
                            '#$tag',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                // Divider
                Divider(
                  height: AppTheme.spacingL,
                  color: Theme.of(context).dividerColor,
                ),

                // Content
                SelectableText(
                  _post!.content ?? 'No content available',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.7,
                  ),
                ),

                const SizedBox(height: AppTheme.spacingXXL),

                // Engagement footer
                Container(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingL),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Like button
                      Expanded(
                        child: _buildEngagementButton(
                          icon: _hasLiked ? Icons.favorite : Icons.favorite_border,
                          label: _likesCount.toString(),
                          color: _hasLiked ? Colors.red : null,
                          onTap: _toggleLike,
                        ),
                      ),
                      // Comments button
                      Expanded(
                        child: _buildEngagementButton(
                          icon: Icons.comment_outlined,
                          label: _commentsCount.toString(),
                          onTap: _showCommentDialog,
                        ),
                      ),
                      // Share button
                      Expanded(
                        child: _buildEngagementButton(
                          icon: Icons.share_outlined,
                          label: 'Share',
                          onTap: _shareChronicle,
                        ),
                      ),
                    ],
                  ),
                ),

                // Comments section
                _buildCommentsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacingXXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            height: AppTheme.spacingL,
            color: Theme.of(context).dividerColor,
          ),
          Text(
            'Comments ($_commentsCount)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          if (_comments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingL),
                child: Text(
                  'No comments yet. Be the first to comment!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                for (final comment in _comments)
                  _buildCommentWidget(comment),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCommentWidget(Map<String, dynamic> comment) {
    final isOptimistic = comment['is_optimistic'] == true;
    final commentId = comment['id']?.toString() ?? '';
    
    // Handle both optimistic (flat) and API (nested) comment structures
    String authorName = 'Anonymous';
    String? authorEmail;
    
    if (comment['is_optimistic'] == true) {
      // Optimistic comments have flat structure
      authorName = comment['author_name'] ?? comment['pen_name'] ?? 'Anonymous';
      authorEmail = comment['author_email'];
    } else {
      // API comments have nested creator object
      final creator = comment['creator'];
      if (creator is Map) {
        authorName = creator['pen_name']?.isNotEmpty == true 
            ? creator['pen_name']
            : 'Anonymous';
      }
    }
    final likes = _commentLikesCount[commentId] ?? comment['likes_count'] ?? 0;
    final isLikedByUser = _commentLikedByUser[commentId] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isOptimistic
                ? AppTheme.primaryColor.withValues(alpha: 0.3)
                : Theme.of(context).dividerColor,
          ),
        ),
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
                        authorName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (authorEmail?.isNotEmpty == true)
                        Text(
                          authorEmail ?? '',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isOptimistic)
                  Chip(
                    label: const Text(
                      'Posting...',
                      style: TextStyle(fontSize: 11),
                    ),
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    side: BorderSide(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              comment['content'] ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatCommentDate(comment['created_at'] ?? ''),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                  ),
                ),
                InkWell(
                  onTap: isOptimistic
                      ? null
                      : () => _toggleCommentLike(commentId, isLikedByUser, comment),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingS,
                      vertical: AppTheme.spacingXS,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLikedByUser ? Icons.favorite : Icons.favorite_border,
                          size: 14,
                          color: isLikedByUser
                              ? Colors.red
                              : Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          likes.toString(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isLikedByUser
                                ? Colors.red
                                : Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementButton({
    required IconData icon,
    required String label,
    Color? color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  int _estimateReadTime(String content) {
    final wordCount = content.split(RegExp(r'\s+')).length;
    return (wordCount / 200).ceil();
  }

  String _formatCommentDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _toggleCommentLike(String commentId, bool isCurrentlyLiked, Map<String, dynamic> comment) async {
    final authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated || authState.user == null) {
      _showAuthRequiredDialog('like this comment');
      return;
    }

    final currentLikes = _commentLikesCount[commentId] ?? comment['likes_count'] ?? 0;

    // Store original values for rollback
    final originalLikeState = isCurrentlyLiked;
    final originalLikeCount = currentLikes;

    try {
      // Optimistic update
      setState(() {
        if (isCurrentlyLiked) {
          _commentLikesCount[commentId] = (currentLikes - 1).clamp(0, 999999);
          _commentLikedByUser[commentId] = false;
        } else {
          _commentLikesCount[commentId] = currentLikes + 1;
          _commentLikedByUser[commentId] = true;
        }
      });

      // Call the API to persist the like
      final apiService = ref.read(apiServiceProvider);
      
      if (isCurrentlyLiked) {
        // Unlike via DELETE
        await apiService.delete(
          '/chronicles/posts/${widget.postId}/comments/$commentId/likes',
        );
        debugPrint('Comment unliked: $commentId');
      } else {
        // Like via POST
        await apiService.post(
          '/chronicles/posts/${widget.postId}/comments/$commentId/likes',
        );
        debugPrint('Comment liked: $commentId');
      }

    } catch (e) {
      // Revert optimistic update on error
      setState(() {
        _commentLikesCount[commentId] = originalLikeCount;
        _commentLikedByUser[commentId] = originalLikeState;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
      debugPrint('Error toggling comment like: $e');
    }
  }
}

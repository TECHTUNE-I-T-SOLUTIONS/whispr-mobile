import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/post.dart';
import '../../../core/network/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/auth_state.dart';

class WhisprWallScreen extends ConsumerStatefulWidget {
  const WhisprWallScreen({super.key});

  @override
  ConsumerState<WhisprWallScreen> createState() => _WhisprWallScreenState();
}

class _WhisprWallScreenState extends ConsumerState<WhisprWallScreen> with TickerProviderStateMixin {
  List<WallPost> _posts = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _postController = TextEditingController();
  bool _isPosting = false;
  bool _mounted = true;
  late AnimationController _listAnimationController;
  final Set<String> _expandedPosts = <String>{}; // Track which posts have expanded replies

  // Track comment likes per post
  final Map<String, Map<String, bool>> _commentLikedByUser = {};
  final Map<String, Map<String, int>> _commentLikesCount = {};
  final Map<String, TextEditingController> _replyControllers = {};
  final Map<String, bool> _isReplyingTo = {};
  final Map<String, bool> _isSubmittingReply = {};

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fetchWallPosts();
  }

  @override
  void dispose() {
    _mounted = false;
    _postController.dispose();
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    _listAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchWallPosts() async {
    try {
      setState(() => _isLoading = true);
      final apiService = ref.read(apiServiceProvider);
      
      // Fetch wall posts with their comments (wall_comments table)
      final response = await apiService.get('/wall');
      
      if (response['success'] == true) {
        List<dynamic> rawPosts = response['posts'] as List? ?? [];
        
        // Process each post - map admin_response to responses format
        final posts = rawPosts.map((json) {
          final map = json is Map<String, dynamic> ? json : Map<String, dynamic>.from(json);
          
          // Build responses from wall_comments if available
          List<dynamic> commentsList = map['comments'] as List? ?? map['wall_comments'] as List? ?? [];
          List<WallResponse> responses = [];
          
          // Also check for admin_response field
          final adminResponse = map['admin_response'];
          final adminResponseUpdated = map['admin_response_updated_at'];
          
          if (adminResponse != null && (adminResponse as String).isNotEmpty) {
            responses.add(WallResponse(
              id: 'admin_${map['id']}',
              content: adminResponse,
              createdAt: adminResponseUpdated ?? map['created_at'],
              isAdmin: true,
              author: WallResponseAuthor(
                id: 'admin',
                username: 'admin',
                fullName: 'Whispr Admin',
                avatarUrl: null,
              ),
            ));
          }
          
          // Add other comments/responses from wall_comments
          for (final comment in commentsList) {
            final c = comment is Map<String, dynamic> ? comment : Map<String, dynamic>.from(comment);
            responses.add(WallResponse(
              id: c['id'] ?? '',
              content: c['content'] ?? '',
              createdAt: c['created_at'],
              isAdmin: c['is_admin'] == true || c['admin_response'] != null,
              author: WallResponseAuthor(
                id: c['user_id'] ?? c['id'] ?? '',
                username: c['pen_name'] ?? c['username'],
                fullName: c['name'] ?? c['pen_name'] ?? 'User',
                avatarUrl: c['avatar_url'],
              ),
            ));
          }

          return WallPost(
            id: map['id'] ?? '',
            content: map['content'] ?? map['question'] ?? '',
            responses: responses.isNotEmpty ? responses : null,
            createdAt: map['created_at'],
          );
        }).toList();

        if (_mounted) {
          setState(() {
            _posts = posts;
            _isLoading = false;
          });
        }
      } else {
        throw Exception(response['error'] ?? 'Failed to load wall posts');
      }
    } catch (e) {
      debugPrint('Error fetching wall posts: $e');
      if (_mounted) {
        setState(() {
          _error = 'Network error. Please check your connection.';
          _isLoading = false;
        });
      }
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

    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isPosting = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      final authState = ref.read(authStateProvider);
      final response = await apiService.post('/wall', data: {
        'content': content,
        if (authState.isAuthenticated) ...{
          'user_id': authState.user?.id,
          'pen_name': authState.user?.penName,
        },
      });

      if (response['success'] != false) {
        _postController.clear();
        if (_mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Posted to the wall!')),
          );
        }
        await _fetchWallPosts();
      } else {
        throw Exception(response['error'] ?? 'Failed to post');
      }
    } catch (e) {
      if (_mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to post: $e')),
        );
      }
    } finally {
      if (_mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  Future<void> _likeComment(String postId, String responseId, bool isCurrentlyLiked) async {
    final authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like comments')),
      );
      return;
    }

    // Initialize tracking maps if needed
    _commentLikedByUser.putIfAbsent(postId, () => {});
    _commentLikesCount.putIfAbsent(postId, () => {});

    final currentLikes = _commentLikesCount[postId]![responseId] ?? 0;

    // Optimistic update
    setState(() {
      if (isCurrentlyLiked) {
        _commentLikedByUser[postId]![responseId] = false;
        _commentLikesCount[postId]![responseId] = (currentLikes - 1).clamp(0, 999999);
      } else {
        _commentLikedByUser[postId]![responseId] = true;
        _commentLikesCount[postId]![responseId] = currentLikes + 1;
      }
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      if (isCurrentlyLiked) {
        await apiService.delete('/wall/$postId/responses/$responseId/likes');
      } else {
        await apiService.post('/wall/$postId/responses/$responseId/likes', data: {});
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _commentLikedByUser[postId]![responseId] = isCurrentlyLiked;
        _commentLikesCount[postId]![responseId] = currentLikes;
      });
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _submitReply(String postId, String content) async {
    if (content.trim().isEmpty) return;

    setState(() {
      _isSubmittingReply[postId] = true;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final authState = ref.read(authStateProvider);
      
      await apiService.post('/wall/$postId/responses', data: {
        'content': content.trim(),
        if (authState.isAuthenticated) ...{
          'user_id': authState.user?.id,
          'pen_name': authState.user?.penName,
        },
      });

      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply posted!')),
        );
        _replyControllers[postId]?.clear();
        setState(() {
          _isReplyingTo[postId] = false;
        });
        await _fetchWallPosts();
      }
    } catch (e) {
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reply: $e')),
        );
      }
    } finally {
      if (_mounted) {
        setState(() {
          _isSubmittingReply[postId] = false;
        });
      }
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
      floatingActionButton: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: FloatingActionButton.extended(
              onPressed: () => _showPostDialog(),
              backgroundColor: AppTheme.primaryColor,
              elevation: 8,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Share Thought', style: TextStyle(color: Colors.white)),
            ),
          );
        },
      ),
    );
  }

  void _showPostDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Share your thoughts'),
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
                      final navigator = Navigator.of(context);
                      setDialogState(() => _isPosting = true);
                      try {
                        await _postToWall();
                        _postController.clear();
                        if (_mounted) {
                          navigator.pop();
                        }
                      } finally {
                        if (_mounted) {
                          setState(() => _isPosting = false);
                        }
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
    );
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
            Icon(Icons.error_outline, size: 48, color: Colors.red.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchWallPosts,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
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
            Icon(Icons.forum_outlined, size: 64, color: AppTheme.primaryColor.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('The wall is empty', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Be the first to share your thoughts!'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        return _buildWallPost(post);
      },
    );
  }

  Widget _buildWallPost(WallPost post) {
    final responses = post.responses ?? [];
    final hasManyResponses = responses.length > 1;
    final isExpanded = _expandedPosts.contains(post.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post header
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey.withValues(alpha: 0.1),
                  child: const Icon(Icons.person, size: 16, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Anonymous User',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: const Text('QUESTION', style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Post content
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(post.content, style: const TextStyle(height: 1.5)),
            ),
            const SizedBox(height: 8),

            // Post date
            if (post.createdAt != null)
              Text(
                DateTime.parse(post.createdAt!).toLocal().toString().split(' ')[0],
                style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6)),
              ),

            // Responses section
            if (responses.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),
              
              // Show visible responses
              ..._getVisibleResponses(post, responses, isExpanded).map((response) =>
                _buildResponseTile(post.id, response)
              ),

              // Expand/Collapse button
              if (hasManyResponses)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedPosts.remove(post.id);
                        } else {
                          _expandedPosts.add(post.id);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isExpanded
                                ? 'Show less'
                                : 'Show ${responses.length - 1} more ${responses.length - 1 == 1 ? 'reply' : 'replies'}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],

            // Reply button and input
            const SizedBox(height: 8),
            _buildReplySection(post.id),
          ],
        ),
      ),
    );
  }

  List<WallResponse> _getVisibleResponses(WallPost post, List<WallResponse> responses, bool isExpanded) {
    if (responses.isEmpty) return [];
    // Show first reply at minimum, all if expanded
    return isExpanded ? responses : [responses.first];
  }

  Widget _buildResponseTile(String postId, WallResponse response) {
    final responseId = response.id;
    final isLiked = _commentLikedByUser[postId]?[responseId] ?? false;
    final likes = _commentLikesCount[postId]?[responseId] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: response.isAdmin
            ? AppTheme.primaryColor.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: response.isAdmin
              ? AppTheme.primaryColor.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author header
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: response.isAdmin
                    ? AppTheme.primaryColor.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                child: Text(
                  (response.author?.displayName ?? (response.isAdmin ? 'A' : 'U'))[0],
                  style: TextStyle(
                    fontSize: 10,
                    color: response.isAdmin ? AppTheme.primaryColor : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                response.isAdmin
                    ? (response.author?.displayName ?? 'Whispr Admin')
                    : 'User',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: response.isAdmin
                      ? AppTheme.primaryColor.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  response.isAdmin ? 'RESPONSE' : 'REPLY',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: response.isAdmin ? AppTheme.primaryColor : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Content
          Text(response.content, style: const TextStyle(height: 1.4, fontSize: 14)),
          
          // Date and like button
          const SizedBox(height: 8),
          Row(
            children: [
              if (response.createdAt != null)
                Text(
                  DateTime.parse(response.createdAt!).toLocal().toString().split(' ')[0],
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                  ),
                ),
              const Spacer(),
              InkWell(
                onTap: () => _likeComment(postId, responseId, isLiked),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 14,
                        color: isLiked ? Colors.red : Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        likes > 0 ? likes.toString() : '',
                        style: TextStyle(
                          fontSize: 11,
                          color: isLiked ? Colors.red : Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
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
    );
  }

  Widget _buildReplySection(String postId) {
    final isReplying = _isReplyingTo[postId] ?? false;
    final isSubmitting = _isSubmittingReply[postId] ?? false;

    if (!isReplying) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _isReplyingTo[postId] = true;
              _replyControllers.putIfAbsent(postId, () => TextEditingController());
            });
          },
          icon: const Icon(Icons.reply, size: 16),
          label: const Text('Reply', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
    }

    return Column(
      children: [
        TextField(
          controller: _replyControllers.putIfAbsent(postId, () => TextEditingController()),
          maxLines: 2,
          minLines: 1,
          decoration: InputDecoration(
            hintText: 'Write a reply...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: isSubmitting ? null : () {
                _replyControllers[postId]?.clear();
                setState(() {
                  _isReplyingTo[postId] = false;
                });
              },
              child: const Text('Cancel', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: isSubmitting ? null : () {
                final content = _replyControllers[postId]?.text ?? '';
                _submitReply(postId, content);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Post', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }
}
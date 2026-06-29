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

class _WhisprWallScreenState extends ConsumerState<WhisprWallScreen> with TickerProviderStateMixin {
  List<WallPost> _posts = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _postController = TextEditingController();
  bool _isPosting = false;
  bool _mounted = true;
  late AnimationController _listAnimationController;
  final Set<String> _expandedPosts = <String>{}; // Track which posts have expanded replies

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
    _listAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchWallPosts() async {
    try {
      setState(() => _isLoading = true);
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get('/wall');
      if (response['success'] == true) {
        final posts = (response['posts'] as List).map((json) => WallPost.fromJson(json)).toList();
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

    // Capture messenger before any async operations
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isPosting = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post('/wall', data: {'content': content});

      if (response['success'] != false) {
        // Post successful
        _postController.clear();
        if (_mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Posted anonymously to the wall!')),
          );
        }
        // Refresh posts
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
                        if (_mounted) {
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
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                margin: const EdgeInsets.all(AppTheme.spacingL),
                padding: const EdgeInsets.all(AppTheme.spacingL),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    Text(
                      'Oops! Something went wrong',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.red,
                      ),
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
                      onPressed: _fetchWallPosts,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingL,
                          vertical: AppTheme.spacingM,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                        ),
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

    if (_posts.isEmpty) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(AppTheme.spacingL),
                padding: const EdgeInsets.all(AppTheme.spacingXL),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.1),
                      AppTheme.primaryColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.bounceOut,
                      builder: (context, iconValue, child) {
                        return Transform.scale(
                          scale: iconValue,
                          child: Icon(
                            Icons.forum_outlined,
                            size: 64,
                            color: AppTheme.primaryColor.withValues(alpha: 0.7),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    Text(
                      'The wall is empty',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      'Be the first to share your thoughts!\nYour anonymous voice matters.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Text(
                            'Tap the + button to start sharing',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return CustomScrollView(
      slivers: [
        // Hero Section
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(AppTheme.spacingM),
            padding: const EdgeInsets.all(AppTheme.spacingL),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.1),
                  AppTheme.primaryColor.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                      ),
                      child: Icon(
                        Icons.forum,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Whispr Wall',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Share your thoughts anonymously',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Text(
                        '${_posts.length} whispers shared',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Posts List
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final post = _posts[index];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 400 + (index * 100)),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Card(
                          margin: EdgeInsets.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).cardColor,
                                  Theme.of(context).cardColor.withValues(alpha: 0.8),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spacingM),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // User Question Header
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(AppTheme.spacingXS),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.grey.withValues(alpha: 0.1),
                                              Colors.grey.withValues(alpha: 0.05),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
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
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.blue.withValues(alpha: 0.1),
                                              Colors.blue.withValues(alpha: 0.05),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.blue.withValues(alpha: 0.2),
                                            width: 1,
                                          ),
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

                                  // Post Content
                                  Container(
                                    padding: const EdgeInsets.all(AppTheme.spacingM),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.grey.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                                      border: Border.all(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white.withValues(alpha: 0.1)
                                            : Colors.grey.withValues(alpha: 0.1),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      post.content,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        height: 1.5,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ),

                                  // Admin Responses
                                  if (post.responses != null && post.responses!.isNotEmpty) ...[
                                    const SizedBox(height: AppTheme.spacingL),
                                    // Show first reply or all if expanded
                                    ...(_expandedPosts.contains(post.id) ? post.responses! : [post.responses!.first]).map((response) => Container(
                                      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: response.isAdmin
                                              ? [
                                                  AppTheme.primaryColor.withValues(alpha: 0.05),
                                                  AppTheme.primaryColor.withValues(alpha: 0.02),
                                                ]
                                              : [
                                                  Colors.grey.withValues(alpha: 0.05),
                                                  Colors.grey.withValues(alpha: 0.02),
                                                ],
                                        ),
                                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                                        border: Border.all(
                                          color: response.isAdmin
                                              ? AppTheme.primaryColor.withValues(alpha: 0.2)
                                              : Colors.grey.withValues(alpha: 0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(AppTheme.spacingM),
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
                                                    gradient: LinearGradient(
                                                      colors: response.isAdmin
                                                          ? [
                                                              AppTheme.primaryColor.withValues(alpha: 0.1),
                                                              AppTheme.primaryColor.withValues(alpha: 0.05),
                                                            ]
                                                          : [
                                                              Colors.grey.withValues(alpha: 0.1),
                                                              Colors.grey.withValues(alpha: 0.05),
                                                            ],
                                                    ),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: response.isAdmin
                                                          ? AppTheme.primaryColor.withValues(alpha: 0.2)
                                                          : Colors.grey.withValues(alpha: 0.2),
                                                      width: 1,
                                                    ),
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
                                            Container(
                                              padding: const EdgeInsets.all(AppTheme.spacingS),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.5),
                                                borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                                              ),
                                              child: Text(
                                                response.content,
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  height: 1.4,
                                                ),
                                              ),
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
                                      ),
                                    )),
                                    // Expand/Collapse button if there are multiple replies
                                    if (post.responses!.length > 1) ...[
                                      const SizedBox(height: AppTheme.spacingS),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            if (_expandedPosts.contains(post.id)) {
                                              _expandedPosts.remove(post.id);
                                            } else {
                                              _expandedPosts.add(post.id);
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppTheme.spacingM,
                                            vertical: AppTheme.spacingS,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                                            border: Border.all(
                                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _expandedPosts.contains(post.id) ? Icons.expand_less : Icons.expand_more,
                                                size: 16,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _expandedPosts.contains(post.id)
                                                    ? 'Show less'
                                                    : 'Show ${post.responses!.length - 1} more replies',
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
                                    ],
                                  ],

                                  // Timestamp
                                  const SizedBox(height: AppTheme.spacingM),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                      ),
                                      const SizedBox(width: AppTheme.spacingXS),
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
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              childCount: _posts.length,
            ),
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: AppTheme.spacingXL),
        ),
      ],
    );
  }

}
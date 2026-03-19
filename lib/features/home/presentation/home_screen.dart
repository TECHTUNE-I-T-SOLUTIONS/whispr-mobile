import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:math' as math;

import '../../../core/models/post.dart';
import '../../../core/network/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_state.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  List<Post> _posts = [];
  bool _isLoading = true;
  String? _error;
  SharedPreferences? _prefs;
  final Set<String> _expandedPostIds = {}; // Track which posts are expanded
  static const String _feedCacheKey = 'feed_cache';
  static const String _feedCacheTimeKey = 'feed_cache_time';
  static const Duration _cacheDuration = Duration(minutes: 5); // Cache for 5 minutes
  bool _animationsPlayed = false; // Prevent animations from restarting

  late AnimationController _heroAnimationController;
  late AnimationController _cardAnimationController;
  late AnimationController _statsAnimationController;
  late AnimationController _floatingAnimationController;
  late AnimationController _shimmerAnimationController;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    // Initialize preferences and load feed data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initAndLoadFeed();
      }
    });
  }

  Future<void> _initAndLoadFeed() async {
    await _initPrefs();
    await _loadCachedPosts();
  }

  @override
  void dispose() {
    _heroAnimationController.dispose();
    _cardAnimationController.dispose();
    _statsAnimationController.dispose();
    _floatingAnimationController.dispose();
    _shimmerAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only play animations once when screen first loads
    if (!_animationsPlayed) {
      _animationsPlayed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _heroAnimationController.forward();
          _cardAnimationController.forward();
          _statsAnimationController.forward();
        }
      });
    }
  }

  void _setupAnimations() {
    _heroAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _statsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Floating animation controller - continuous looping
    _floatingAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    // Shimmer animation controller - continuous looping for glow effect
    _shimmerAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  // ignore: unused_element
  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ignore: unused_element
  Future<void> _loadCachedPosts() async {
    if (_prefs == null) return;

    try {
      final cachedPostsJson = _prefs!.getString(_feedCacheKey);
      final cacheTime = _prefs!.getInt(_feedCacheTimeKey);

      if (cachedPostsJson != null && cacheTime != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTime;
        if (cacheAge < _cacheDuration.inMilliseconds) {
          final cachedPosts = (jsonDecode(cachedPostsJson) as List)
              .map((json) => Post.fromJson(json))
              .toList();
          setState(() {
            _posts = cachedPosts;
            _isLoading = false;
          });
          // Still fetch fresh data in background
          _fetchPosts();
          return;
        }
      }
    } catch (e) {
      debugPrint('Error loading cached posts: $e');
    }

    // No valid cache, fetch fresh data
    _fetchPosts();
  }

  Future<void> _savePostsToCache(List<Post> posts) async {
    if (_prefs == null) return;

    try {
      final postsJson = jsonEncode(posts.map((post) => post.toJson()).toList());
      await _prefs!.setString(_feedCacheKey, postsJson);
      await _prefs!.setInt(_feedCacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error saving posts to cache: $e');
    }
  }

  Future<void> _fetchPosts() async {
    try {
      setState(() => _isLoading = true);
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get('/feed');
      if (response['success'] == true) {
        final allPosts = (response['posts'] as List).map((json) => Post.fromJson(json)).toList();
        // Filter to only show admin posts
        final adminPosts = allPosts.where((post) => post.source == 'admin').toList();
        if (mounted) {
          setState(() {
            _posts = adminPosts;
            _isLoading = false;
          });
        }
        // Cache the posts
        await _savePostsToCache(adminPosts);
      } else {
        throw Exception(response['error'] ?? 'Failed to load feed');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Network error. Please check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  String _getContentPreview(String? content) {
    if (content == null || content.isEmpty) return '';
    // Remove HTML tags for preview
    final cleanContent = content.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    if (cleanContent.length <= 150) return cleanContent;
    return '${cleanContent.substring(0, 150)}...';
  }

  Future<void> _likePost(Post post) async {
    final authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated) {
      _showAuthRequiredDialog('like this post');
      return;
    }

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post('/reactions', data: {
        'post_id': post.id,
        'reaction_type': 'like',
      });

      // Update local state based on the action
      if (mounted) {
        setState(() {
          final index = _posts.indexWhere((p) => p.id == post.id);
          if (index != -1) {
            final currentPost = _posts[index];
            int newLikesCount = currentPost.likesCount ?? 0;

            if (response['action'] == 'added') {
              newLikesCount++;
            } else if (response['action'] == 'removed') {
              newLikesCount = (newLikesCount > 0) ? newLikesCount - 1 : 0;
            } else if (response['action'] == 'updated') {
              // Count might not change if replacing another reaction
            }

            final updatedPost = currentPost.copyWith(
              likesCount: newLikesCount,
              userReaction: response['action'] == 'added' || response['action'] == 'updated' ? 'like' : null,
            );
            _posts[index] = updatedPost;
          }
        });
      }

      if (mounted) {
        final message = (response['action'] == 'added' || response['action'] == 'updated') ? 'Post liked!' : 'Like removed!';
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

  Future<void> _commentOnPost(Post post) async {
    final authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated) {
      _showAuthRequiredDialog('comment on this post');
      return;
    }

    final commentController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // ignore: unused_local_variable
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Comment'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: commentController,
            decoration: const InputDecoration(
              hintText: 'Write your comment...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Comment cannot be empty';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() == true) {
                final currentContext = context; // Store context before async operation
                try {
                  final apiService = ref.read(apiServiceProvider);
                  await apiService.post('/comments', data: {
                    'post_id': post.id,
                    'content': commentController.text.trim(),
                  });

                  if (mounted) {
                    Navigator.of(currentContext).pop(); // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(currentContext).showSnackBar( // ignore: use_build_context_synchronously
                      const SnackBar(content: Text('Comment added!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(currentContext).showSnackBar( // ignore: use_build_context_synchronously
                      SnackBar(content: Text('Failed to add comment: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  void _searchPosts() {
    showSearch(
      context: context,
      delegate: GlobalSearchDelegate(_posts, context),
    );
  }

  Future<void> _sharePost(Post post) async {
    try {
      // Construct the appropriate URL based on post type
      final baseUrl = 'https://whispr.vercel.app';
      String url;

      switch (post.type.toLowerCase()) {
        case 'blog':
          url = '$baseUrl/blog/${post.id}';
          break;
        case 'poem':
          url = '$baseUrl/poems/${post.id}';
          break;
        case 'chronicle':
          // For chronicles, we might need slug, but for now use id
          // TODO: Update when slug is available in Post model
          url = '$baseUrl/chronicles/${post.id}';
          break;
        default:
          url = '$baseUrl/blog/${post.id}'; // fallback
      }

      final shareText = '${post.title}\n\n$url\n\nBy ${post.author.name}';
      await Share.share(shareText, subject: post.title);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }

  void _showAuthRequiredDialog(String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Required'),
        content: Text('You need to be logged in to $action. Would you like to sign in?'),
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
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Whispr'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _searchPosts,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              context.go('/notifications');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPosts,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: $_error'),
                        const SizedBox(height: AppTheme.spacingM),
                        ElevatedButton(
                          onPressed: _fetchPosts,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _posts.isEmpty
                    ? const Center(child: Text('No posts available'))
                    : CustomScrollView(
                        slivers: [
                          // Hero Section
                          SliverToBoxAdapter(
                            child: FadeTransition(
                              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                                CurvedAnimation(parent: _heroAnimationController, curve: Curves.easeIn),
                              ),
                              child: SlideTransition(
                                position: Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero).animate(
                                  CurvedAnimation(parent: _heroAnimationController, curve: Curves.easeOut),
                                ),
                                child: Container(
                                  height: 240,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.primaryColor.withValues(alpha: 0.8),
                                        AppTheme.primaryColor.withValues(alpha: 0.4),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      // Animated background gradient
                                      Positioned.fill(
                                        child: ShaderMask(
                                          shaderCallback: (bounds) {
                                            return LinearGradient(
                                              colors: [
                                                Colors.transparent,
                                                AppTheme.primaryColor.withValues(alpha: 0.1),
                                              ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ).createShader(bounds);
                                          },
                                          child: Opacity(
                                            opacity: 0.1,
                                            child: Container(
                                              decoration: const BoxDecoration(
                                                image: DecorationImage(
                                                  image: AssetImage('assets/images/Whispr.png'),
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Animated scrolling light effect
                                      Positioned.fill(
                                        child: AnimatedBuilder(
                                          animation: _heroAnimationController,
                                          builder: (context, child) {
                                            return Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.white.withValues(alpha: 0.1),
                                                    Colors.transparent,
                                                  ],
                                                  stops: [
                                                    0.0,
                                                    _heroAnimationController.value,
                                                    1.0,
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      // Shimmering light glow effect
                                      Positioned.fill(
                                        child: AnimatedBuilder(
                                          animation: _shimmerAnimationController,
                                          builder: (context, child) {
                                            final angle = _shimmerAnimationController.value * 6.28; // 2π
                                            return Container(
                                              decoration: BoxDecoration(
                                                gradient: RadialGradient(
                                                  center: Alignment(
                                                    0.5 + 0.3 * math.cos(angle),
                                                    0.3 + 0.2 * math.sin(angle),
                                                  ),
                                                  radius: 1.5,
                                                  colors: [
                                                    Colors.white.withValues(alpha: 0.15),
                                                    Colors.white.withValues(alpha: 0.05),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppTheme.spacingL,
                                          vertical: AppTheme.spacingM,
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Welcome to Whispr',
                                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 28,
                                              ),
                                            ),
                                            const SizedBox(height: AppTheme.spacingXS),
                                            Text(
                                              'Discover inspiring words, poems, and chronicles from our community',
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: Colors.white.withValues(alpha: 0.9),
                                              ),
                                            ),
                                            const SizedBox(height: AppTheme.spacingS),
                                            ScaleTransition(
                                              scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                                                CurvedAnimation(
                                                  parent: _heroAnimationController,
                                                  curve: const Interval(0.5, 1.0, curve: Curves.elasticOut),
                                                ),
                                              ),
                                              child: ElevatedButton(
                                                onPressed: () => context.go('/chronicles'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  foregroundColor: AppTheme.primaryColor,
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: AppTheme.spacingM,
                                                    vertical: AppTheme.spacingXS,
                                                  ),
                                                ),
                                                child: const Text('Explore Chronicles'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Quick Stats Section
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spacingM),
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                                  CurvedAnimation(parent: _statsAnimationController, curve: Curves.elasticOut),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildAnimatedStatCard(
                                      'Chronicles',
                                      '1',
                                      Icons.history,
                                      () => context.go('/chronicles'),
                                      0,
                                    ),
                                    _buildAnimatedStatCard(
                                      'Whispr Wall',
                                      '1',
                                      Icons.forum,
                                      () => context.go('/whispr-wall'),
                                      1,
                                    ),
                                    _buildAnimatedStatCard(
                                      'Chains',
                                      '1',
                                      Icons.link,
                                      () => context.go('/writing-chains'),
                                      2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Categories Section
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Explore Categories',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spacingM),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildAnimatedCategoryCard(
                                        'Chronicles',
                                        Icons.history,
                                        Colors.orange.shade600,
                                        () => context.go('/chronicles'),
                                        0,
                                      ),
                                      _buildAnimatedCategoryCard(
                                        'Whispr Wall',
                                        Icons.forum,
                                        Colors.blue.shade600,
                                        () => context.go('/whispr-wall'),
                                        1,
                                      ),
                                      _buildAnimatedCategoryCard(
                                        'Write Chain',
                                        Icons.link,
                                        Colors.green.shade600,
                                        () => context.go('/writing-chains'),
                                        2,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Featured Post Section
                          if (_posts.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(AppTheme.spacingM),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Featured Post',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: AppTheme.spacingM),
                                    _buildFeaturedPostCard(_posts.first),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // Latest Feed Section
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM, vertical: AppTheme.spacingS),
                              child: Text(
                                'Latest Feed',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          // Feed Posts
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final post = _posts[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingS,
                                    vertical: AppTheme.spacingXS,
                                  ),
                                  child: InkWell(
                                    onTap: () => context.go('/post/${post.id}'),
                                    child: Padding(
                                      padding: const EdgeInsets.all(AppTheme.spacingM),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Author info
                                          Row(
                                            children: [
                                              if (post.author.avatar != null && post.author.avatar!.isNotEmpty)
                                                CachedNetworkImage(
                                                  imageUrl: post.author.avatar!,
                                                  imageBuilder: (context, imageProvider) => CircleAvatar(
                                                    radius: 16,
                                                    backgroundImage: imageProvider,
                                                  ),
                                                  placeholder: (context, url) => CircleAvatar(
                                                    radius: 16,
                                                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                                                    child: SizedBox(
                                                      width: 12,
                                                      height: 12,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 1.5,
                                                        valueColor: AlwaysStoppedAnimation<Color>(
                                                          AppTheme.primaryColor.withValues(alpha: 0.6),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  errorWidget: (context, url, error) => CircleAvatar(
                                                    radius: 16,
                                                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                                                    child: Text(
                                                      post.author.name.isNotEmpty ? post.author.name[0].toUpperCase() : '?',
                                                      style: const TextStyle(
                                                        color: AppTheme.primaryColor,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  fadeInDuration: const Duration(milliseconds: 300),
                                                  fadeOutDuration: const Duration(milliseconds: 300),
                                                  httpHeaders: const {
                                                    'User-Agent': 'Whispr-Mobile-App/1.0',
                                                  },
                                                )
                                              else
                                                CircleAvatar(
                                                  radius: 16,
                                                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                                                  child: Text(
                                                    post.author.name.isNotEmpty ? post.author.name[0].toUpperCase() : '?',
                                                    style: const TextStyle(
                                                      color: AppTheme.primaryColor,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              const SizedBox(width: AppTheme.spacingS),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      post.author.name,
                                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${post.displayDate} • ${post.readingTimeText}',
                                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: AppTheme.spacingXS,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: post.source == 'admin'
                                                      ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                                      : Colors.orange.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  post.source == 'admin' ? 'ADMIN' : 'USER',
                                                  style: TextStyle(
                                                    color: post.source == 'admin'
                                                        ? AppTheme.primaryColor
                                                        : Colors.orange,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: AppTheme.spacingM),

                                          // Title
                                          Text(
                                            post.title,
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                          // Content preview or full content
                                          if (post.excerpt != null && post.excerpt!.isNotEmpty) ...[
                                            const SizedBox(height: AppTheme.spacingS),
                                            Text(
                                              post.excerpt!,
                                              style: Theme.of(context).textTheme.bodyMedium,
                                              maxLines: _expandedPostIds.contains(post.id) ? null : 2,
                                              overflow: _expandedPostIds.contains(post.id) ? TextOverflow.visible : TextOverflow.ellipsis,
                                            ),
                                          ],
                                          if (post.content != null && post.content!.isNotEmpty) ...[
                                            const SizedBox(height: AppTheme.spacingS),
                                            Text(
                                              _getContentPreview(post.content),
                                              style: Theme.of(context).textTheme.bodyMedium,
                                              maxLines: _expandedPostIds.contains(post.id) ? null : 3,
                                              overflow: _expandedPostIds.contains(post.id) ? TextOverflow.visible : TextOverflow.ellipsis,
                                            ),
                                            // Show "see more" button if content is long and not expanded
                                            if (!_expandedPostIds.contains(post.id) && _getContentPreview(post.content).length > 150)
                                              Padding(
                                                padding: const EdgeInsets.only(top: AppTheme.spacingS),
                                                child: GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _expandedPostIds.add(post.id);
                                                    });
                                                  },
                                                  child: Text(
                                                    'See more',
                                                    style: TextStyle(
                                                      color: AppTheme.primaryColor,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            // Show "see less" if expanded
                                            if (_expandedPostIds.contains(post.id))
                                              Padding(
                                                padding: const EdgeInsets.only(top: AppTheme.spacingS),
                                                child: GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _expandedPostIds.remove(post.id);
                                                    });
                                                  },
                                                  child: Text(
                                                    'See less',
                                                    style: TextStyle(
                                                      color: AppTheme.primaryColor,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],

                                          // Tags
                                          if (post.tags != null && post.tags!.isNotEmpty) ...[
                                            const SizedBox(height: AppTheme.spacingS),
                                            Wrap(
                                              spacing: AppTheme.spacingXS,
                                              children: post.tags!.map((tag) => Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: AppTheme.spacingXS,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  tag,
                                                  style: TextStyle(
                                                    color: AppTheme.primaryColor,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              )).toList(),
                                            ),
                                          ],

                                          const SizedBox(height: AppTheme.spacingM),

                                          // Stats and actions
                                          Row(
                                            children: [
                                              // Post type badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: AppTheme.spacingXS,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _getTypeColor(post.type).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  post.type.toUpperCase(),
                                                  style: TextStyle(
                                                    color: _getTypeColor(post.type),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),

                                              // Stats
                                              if (post.viewCount != null) ...[
                                                Icon(
                                                  Icons.visibility,
                                                  size: 16,
                                                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                                ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  '${post.viewCount}',
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                                  ),
                                                ),
                                                const SizedBox(width: AppTheme.spacingM),
                                              ],

                                              // Action buttons
                                              Row(
                                                children: [
                                                  IconButton(
                                                    icon: Icon(
                                                      post.userReaction == 'like' ? Icons.favorite : Icons.favorite_border,
                                                      size: 20,
                                                      color: post.userReaction == 'like' ? Colors.red : null,
                                                    ),
                                                    onPressed: () => _likePost(post),
                                                  ),
                                                  if (post.likesCount != null && post.likesCount! > 0) ...[
                                                    Text(
                                                      '${post.likesCount}',
                                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                                      ),
                                                    ),
                                                    const SizedBox(width: AppTheme.spacingS),
                                                  ],
                                                ],
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.comment, size: 20),
                                                onPressed: () => _commentOnPost(post),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.share, size: 20),
                                                onPressed: () => _sharePost(post),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                              childCount: _posts.length,
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _buildAnimatedStatCard(
    String title,
    String value,
    IconData icon,
    VoidCallback onTap,
    int index,
  ) {
    final staggeredAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _statsAnimationController,
        curve: Interval(
          index * 0.15,
          1.0,
          curve: Curves.easeOut,
        ),
      ),
    );

    // Floating animation with delay for each index
    final floatingAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _floatingAnimationController, curve: Curves.easeInOut),
    );

    return ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1.0).animate(staggeredAnimation),
      child: FadeTransition(
        opacity: staggeredAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, -floatingAnimation.value / 100),
            end: Offset(0, floatingAnimation.value / 100),
          ).animate(_floatingAnimationController),
          child: MouseRegion(
            onEnter: (_) => _handleCardHover(),
            child: Card(
              elevation: 8,
              shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    child: Column(
                      children: [
                        Icon(icon, color: AppTheme.primaryColor, size: 36),
                        const SizedBox(height: AppTheme.spacingS),
                        Text(
                          value,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                            shadows: [
                              Shadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedCategoryCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
    int index,
  ) {
    final staggeredAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardAnimationController,
        curve: Interval(
          index * 0.2,
          1.0,
          curve: Curves.easeOut,
        ),
      ),
    );

    return ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1.0).animate(staggeredAnimation),
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero).animate(staggeredAnimation),
        child: FadeTransition(
          opacity: staggeredAnimation,
          child: GestureDetector(
            onTap: onTap,
            child: Card(
              elevation: 6,
              shadowColor: color.withValues(alpha: 0.3),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Column(
                    children: [
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.8, end: 1.1).animate(
                          CurvedAnimation(
                            parent: _cardAnimationController,
                            curve: Interval(
                              0.5 + index * 0.15,
                              1.0,
                              curve: Curves.elasticOut,
                            ),
                          ),
                        ),
                        child: Icon(icon, color: color, size: 40),
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleCardHover() {
    // Can be used for additional hover effects if needed
  }

  // ignore: unused_element
  Widget _buildStatCard(String title, String value, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 8,
      shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              children: [
                Icon(icon, color: AppTheme.primaryColor, size: 32),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    shadows: [
                      Shadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildCategoryCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 6,
        shadowColor: color.withValues(alpha: 0.3),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedPostCard(Post post) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () => context.go('/post/${post.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (post.author.avatar != null && post.author.avatar!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: post.author.avatar!,
                      imageBuilder: (context, imageProvider) => CircleAvatar(
                        radius: 20,
                        backgroundImage: imageProvider,
                      ),
                      placeholder: (context, url) => CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                        child: Text(
                          post.author.name.isNotEmpty ? post.author.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      fadeInDuration: const Duration(milliseconds: 300),
                      fadeOutDuration: const Duration(milliseconds: 300),
                      httpHeaders: const {
                        'User-Agent': 'Whispr-Mobile-App/1.0',
                      },
                    )
                  else
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                      child: Text(
                        post.author.name.isNotEmpty ? post.author.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.author.name,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${post.displayDate} • ${post.readingTimeText}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingXS,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getTypeColor(post.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      post.type.toUpperCase(),
                      style: TextStyle(
                        color: _getTypeColor(post.type),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
              Text(
                post.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                post.excerpt ?? _getContentPreview(post.content),
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppTheme.spacingM),
              Row(
                children: [
                  if (post.viewCount != null) ...[
                    Icon(
                      Icons.visibility,
                      size: 16,
                      color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${post.viewCount} views',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                  ],
                  if (post.likesCount != null && post.likesCount! > 0) ...[
                    Icon(
                      Icons.favorite,
                      size: 16,
                      color: Colors.red.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${post.likesCount} likes',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'blog':
        return Colors.blue;
      case 'poem':
        return Colors.purple;
      case 'chronicle':
        return Colors.green;
      default:
        return AppTheme.primaryColor;
    }
  }
}

class SearchResult {
  final String id;
  final String title;
  final String subtitle;
  final String type; // 'post', 'poem', 'blog', 'spoken_word', 'chronicle'
  final String route;

  SearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.route,
  });
}

class GlobalSearchDelegate extends SearchDelegate<SearchResult?> {
  final List<Post> posts;
  final BuildContext context;

  GlobalSearchDelegate(this.posts, this.context);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  List<SearchResult> _getAllSearchResults() {
    List<SearchResult> results = [];

    // Add posts
    for (final post in posts) {
      results.add(SearchResult(
        id: post.id,
        title: post.title,
        subtitle: 'Post by ${post.author.name}',
        type: 'post',
        route: '/post/${post.id}',
      ));
    }

    // Add poems (filter from posts)
    final poems = posts.where((p) => p.type == 'poem');
    for (final poem in poems) {
      results.add(SearchResult(
        id: poem.id,
        title: poem.title,
        subtitle: 'Poem by ${poem.author.name}',
        type: 'poem',
        route: '/spoken-words',
      ));
    }

    // Add blogs (filter from posts)
    final blogs = posts.where((p) => p.type == 'blog');
    for (final blog in blogs) {
      results.add(SearchResult(
        id: blog.id,
        title: blog.title,
        subtitle: 'Blog by ${blog.author.name}',
        type: 'blog',
        route: '/chronicles',
      ));
    }

    // Add static navigation options
    results.addAll([
      SearchResult(
        id: 'spoken-words',
        title: 'Spoken Words',
        subtitle: 'Browse all spoken word content',
        type: 'section',
        route: '/spoken-words',
      ),
      SearchResult(
        id: 'chronicles',
        title: 'Chronicles',
        subtitle: 'Explore blog posts and articles',
        type: 'section',
        route: '/chronicles',
      ),
      SearchResult(
        id: 'whispr-wall',
        title: 'Whispr Wall',
        subtitle: 'Community posts and discussions',
        type: 'section',
        route: '/whispr-wall',
      ),
      SearchResult(
        id: 'writing-chains',
        title: 'Writing Chains',
        subtitle: 'Collaborative writing projects',
        type: 'section',
        route: '/writing-chains',
      ),
    ]);

    return results;
  }

  @override
  Widget buildResults(BuildContext context) {
    final allResults = _getAllSearchResults();
    final results = allResults.where((result) {
      return result.title.toLowerCase().contains(query.toLowerCase()) ||
             result.subtitle.toLowerCase().contains(query.toLowerCase()) ||
             result.type.toLowerCase().contains(query.toLowerCase());
    }).toList();

    if (results.isEmpty) {
      return const Center(
        child: Text('No results found'),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return ListTile(
          leading: Icon(_getIconForType(result.type)),
          title: Text(result.title),
          subtitle: Text(result.subtitle),
          onTap: () {
            close(context, result);
            this.context.go(result.route);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final allResults = _getAllSearchResults();
    final suggestions = allResults.where((result) {
      return result.title.toLowerCase().contains(query.toLowerCase()) ||
             result.type.toLowerCase().contains(query.toLowerCase());
    }).take(10).toList(); // Limit suggestions

    if (query.isEmpty) {
      return const Center(
        child: Text('Search for posts, poems, blogs, or navigate to sections'),
      );
    }

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final result = suggestions[index];
        return ListTile(
          leading: Icon(_getIconForType(result.type)),
          title: Text(result.title),
          subtitle: Text(result.subtitle),
          onTap: () {
            close(context, result);
            this.context.go(result.route);
          },
        );
      },
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'post':
        return Icons.article;
      case 'poem':
        return Icons.format_quote;
      case 'blog':
        return Icons.book;
      case 'spoken_word':
        return Icons.mic;
      case 'chronicle':
        return Icons.history;
      case 'section':
        return Icons.folder;
      default:
        return Icons.search;
    }
  }
}
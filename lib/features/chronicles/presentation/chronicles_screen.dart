import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/post.dart';
import '../../../core/network/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/auth_state.dart';

class ChroniclesScreen extends ConsumerStatefulWidget {
  const ChroniclesScreen({super.key});

  @override
  ConsumerState<ChroniclesScreen> createState() => _ChroniclesScreenState();
}

class _ChroniclesScreenState extends ConsumerState<ChroniclesScreen> with TickerProviderStateMixin {
  List<Post> _posts = [];
  bool _isLoading = false;  // Start as false to allow initial fetch
  String? _error;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _hasAttemptedFetch = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    // Don't fetch immediately - wait for auth state to be ready
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authState = ref.watch(authStateProvider);
    
    // Reset fetch flag if user logs out
    if (!authState.isAuthenticated && _hasAttemptedFetch) {
      _hasAttemptedFetch = false;
      _posts.clear();
      _error = null;
    }
  }

  Future<void> _fetchUserPosts() async {
    final authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated) {
      setState(() {
        _error = 'Please log in to view your chronicles';
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() => _isLoading = true);
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get('/chronicles/creator/posts');
      
      // Check if response has posts
      if (response is! Map<String, dynamic>) {
        throw Exception('Invalid response format');
      }
      
      // Parse posts safely
      final postsList = response['posts'];
      if (postsList == null) {
        // Check if this is a 401 error response
        if (response['error'] != null && response['error'].toString().contains('Unauthorized')) {
          throw Exception('401: Your session has expired. Please log in again.');
        }
        throw Exception('No posts data in response');
      }
      
      if (postsList is! List) {
        throw Exception('Posts data is not a list');
      }
      
      final posts = postsList.map((json) => Post.fromJson(json)).toList();
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      String errorMessage = 'Failed to load your chronicles';
      final errorStr = e.toString();
      final runtimeTypeName = e.runtimeType.toString();
      
      // Handle UnauthorizedException (401) - session expired
      if (runtimeTypeName.contains('UnauthorizedException') ||
          errorStr.contains('UnauthorizedException') ||
          errorStr.contains('401') || errorStr.contains('Unauthorized') || 
          errorStr.contains('invalid JWT') || errorStr.contains('token is expired')) {
        errorMessage = 'Your session has expired. Please log in again.';
        // Show toast notification
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Session expired. Please log in again.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        });
      } else if (errorStr.contains('ForbiddenException')) {
        errorMessage = 'You do not have permission to view your chronicles.';
      } else if (errorStr.contains('NetworkException')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e is Exception) {
        final message = errorStr.replaceAll('Exception: ', '');
        if (message.isNotEmpty && message != 'Exception') {
          errorMessage = message;
        }
      }
      
      if (mounted) {
        setState(() {
          _error = errorMessage;
          _isLoading = false;
        });
      }
      debugPrint('Error fetching user posts: $e');
    }
  }

  Future<void> _deletePost(Post post) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.delete('/chronicles/posts/${post.id}');
      
      if (response['success'] == true || response['message'] == 'Post deleted successfully') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted successfully')),
          );
          // Refresh the posts list
          await _fetchUserPosts();
        }
      } else {
        throw Exception(response['error'] ?? 'Failed to delete post');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete post: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmationDialog(Post post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chronicle'),
        content: Text('Are you sure you want to delete "${post.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deletePost(post);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    // Fetch posts when auth state becomes ready and authenticated (only once)
    if (authState.isAuthenticated && !_isLoading && _posts.isEmpty && _error == null && !_hasAttemptedFetch) {
      _hasAttemptedFetch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchUserPosts();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Chronicles'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        actions: [
          if (authState.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                context.go('/chronicles/create');
              },
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: authState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : authState.isAuthenticated
                ? _buildAuthenticatedView()
                : _buildUnauthenticatedView(),
      ),
    );
  }

  Widget _buildAuthenticatedView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
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
              'Oops! Something went wrong',
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
              onPressed: _fetchUserPosts,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
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
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withValues(alpha: 0.2),
                          AppTheme.primaryColor.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(60),
                    ),
                    child: const Icon(
                      Icons.book_outlined,
                      size: 60,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'Your story begins here',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'Share your thoughts, experiences, and creativity with the world',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingL),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.go('/chronicles/create');
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Write Your First Chronicle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingL,
                        vertical: AppTheme.spacingM,
                      ),
                      elevation: 8,
                      shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // Hero Section
        SliverToBoxAdapter(
          child: Container(
            height: 200,
            margin: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.8),
                  AppTheme.primaryColor.withValues(alpha: 0.6),
                  AppTheme.primaryColor.withValues(alpha: 0.4),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
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
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Text(
                                'Your Chronicles',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Text(
                                '${_posts.length} ${_posts.length == 1 ? 'story' : 'stories'} shared',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          );
                        },
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
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 30 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 12,
                                spreadRadius: 1,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
                            ),
                            child: InkWell(
                              onTap: () {
                                context.go('/post/${post.id}');
                              },
                              borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Cover image if available
                                  if (post.coverImage != null)
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(AppTheme.borderRadiusL),
                                      ),
                                      child: Container(
                                        height: 180,
                                        width: double.infinity,
                                        color: Theme.of(context).cardColor,
                                        child: Stack(
                                          children: [
                                            Image.network(
                                              post.coverImage!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.image_not_supported,
                                                      size: 48,
                                                      color: AppTheme.primaryColor,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            Positioned(
                                              top: AppTheme.spacingM,
                                              right: AppTheme.spacingM,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: AppTheme.spacingS,
                                                  vertical: AppTheme.spacingXS,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.7),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  post.type.toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  // Post content
                                  Padding(
                                    padding: const EdgeInsets.all(AppTheme.spacingM),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header with date
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 16,
                                              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              post.displayDate,
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
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
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),

                                        // Excerpt
                                        if (post.excerpt != null) ...[
                                          const SizedBox(height: AppTheme.spacingS),
                                          Text(
                                            post.excerpt!,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                            ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],

                                        const SizedBox(height: AppTheme.spacingM),

                                        // Stats and actions
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Wrap(
                                                spacing: AppTheme.spacingS,
                                                runSpacing: AppTheme.spacingXS,
                                                children: [
                                                  if (post.likesCount != null && post.likesCount! > 0)
                                                    _StatChip(
                                                      icon: Icons.favorite,
                                                      label: '${post.likesCount}',
                                                      color: Colors.red,
                                                    ),
                                                  if (post.commentsCount != null && post.commentsCount! > 0)
                                                    _StatChip(
                                                      icon: Icons.comment,
                                                      label: '${post.commentsCount}',
                                                      color: Colors.blue,
                                                    ),
                                                  if (post.viewCount != null && post.viewCount! > 0)
                                                    _StatChip(
                                                      icon: Icons.visibility,
                                                      label: '${post.viewCount}',
                                                      color: Colors.grey,
                                                    ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete_outline,
                                                color: Colors.red.withValues(alpha: 0.7),
                                              ),
                                              tooltip: 'Delete',
                                              onPressed: () {
                                                _showDeleteConfirmationDialog(post);
                                              },
                                            ),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: IconButton(
                                                icon: const Icon(
                                                  Icons.arrow_forward,
                                                  color: AppTheme.primaryColor,
                                                ),
                                                onPressed: () {
                                                  context.go('/post/${post.id}');
                                                },
                                              ),
                                            ),
                                          ],
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
                    );
                  },
                );
              },
              childCount: _posts.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnauthenticatedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 64,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'Sign in to view your chronicles',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spacingL),
          ElevatedButton(
            onPressed: () {
              context.go('/login');
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingXS,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

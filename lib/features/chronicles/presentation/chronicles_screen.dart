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
      final posts = (response['posts'] as List).map((json) => Post.fromJson(json)).toList();
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
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
            Text('Error: $_error'),
            const SizedBox(height: AppTheme.spacingM),
            ElevatedButton(
              onPressed: _fetchUserPosts,
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
              Icons.book_outlined,
              size: 64,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'No chronicles yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'Start sharing your stories and thoughts',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingL),
            ElevatedButton.icon(
              onPressed: () {
                context.go('/chronicles/create');
              },
              icon: const Icon(Icons.add),
              label: const Text('Write Your First Chronicle'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (index * 100)),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: Card(
                  margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
                  child: InkWell(
                    onTap: () {
                      context.go('/post/${post.id}');
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover image if available
                        if (post.coverImage != null)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.borderRadiusM)),
                            child: Container(
                              height: 200,
                              width: double.infinity,
                              color: Theme.of(context).cardColor,
                              child: Image.network(
                                post.coverImage!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                    child: const Center(
                                      child: Icon(Icons.image_not_supported),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        // Post header and content
                        Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with type badge and date
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppTheme.spacingXS,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: post.type == 'poem' 
                                        ? Colors.purple.withValues(alpha: 0.1)
                                        : Colors.blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      post.type.toUpperCase(),
                                      style: TextStyle(
                                        color: post.type == 'poem' ? Colors.purple : Colors.blue,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
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
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: AppTheme.spacingM),
                              // Footer with stats
                              Row(
                                children: [
                                  Expanded(
                                    child: Wrap(
                                      spacing: AppTheme.spacingS,
                                      runSpacing: AppTheme.spacingXS,
                                      children: [
                                        if (post.likesCount != null && post.likesCount! > 0)
                                          _StatChip(
                                            icon: Icons.favorite_outline,
                                            label: '${post.likesCount}',
                                            color: Colors.red,
                                          ),
                                        if (post.commentsCount != null && post.commentsCount! > 0)
                                          _StatChip(
                                            icon: Icons.comment_outlined,
                                            label: '${post.commentsCount}',
                                            color: Colors.blue,
                                          ),
                                        if (post.viewCount != null && post.viewCount! > 0)
                                          _StatChip(
                                            icon: Icons.visibility_outlined,
                                            label: '${post.viewCount}',
                                            color: Colors.grey,
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    tooltip: 'Delete',
                                    onPressed: () {
                                      _showDeleteConfirmationDialog(post);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.arrow_forward),
                                    onPressed: () {
                                      context.go('/post/${post.id}');
                                    },
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
            );
          },
        );
      },
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

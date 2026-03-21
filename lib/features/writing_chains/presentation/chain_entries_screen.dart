import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/chronicles.dart';
import '../../../core/network/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/auth_state.dart';

class ChainEntriesScreen extends ConsumerStatefulWidget {
  final String chainId;

  const ChainEntriesScreen({super.key, required this.chainId});

  @override
  ConsumerState<ChainEntriesScreen> createState() => _ChainEntriesScreenState();
}

class _ChainEntriesScreenState extends ConsumerState<ChainEntriesScreen> with TickerProviderStateMixin {
  WritingChain? _chain;
  List<ChainEntry> _entries = [];
  bool _isLoading = false;
  String? _error;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _hasAttemptedFetch = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
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

    if (authState.isAuthenticated && !_isLoading && _chain == null && _error == null && !_hasAttemptedFetch) {
      _hasAttemptedFetch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchChainDetails();
      });
    }
  }

  Future<void> _fetchChainDetails() async {
    final authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated) {
      if (mounted) {
        setState(() {
          _error = 'Please log in to view chain entries';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      if (mounted) setState(() => _isLoading = true);
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get('/chronicles/chains/${widget.chainId}');

      if (response['success'] == true) {
        final data = response['data'];
        final chain = WritingChain(
          id: data['id'],
          title: data['title'],
          description: data['description'],
          createdAt: data['created_at'],
          entriesCount: data['entries']?.length ?? 0,
        );

        final entries = (data['entries'] as List?)?.map((entry) {
          final post = entry['post'];
          return ChainEntry(
            id: entry['id'],
            sequence: entry['sequence'],
            addedAt: entry['added_at'],
            post: post != null ? PostSummary(
              id: post['id'],
              title: post['title'],
              slug: post['slug'],
              excerpt: post['excerpt'],
              content: post['content'],
              coverImageUrl: post['cover_image_url'],
              category: post['category'],
              tags: (post['tags'] as List?)?.cast<String>() ?? [],
              publishedAt: post['published_at'],
              creatorName: post['creator']?['pen_name'],
              creatorId: post['creator']?['id'],
              likesCount: post['likes_count'] ?? 0,
              commentsCount: post['comments_count'] ?? 0,
              sharesCount: post['shares_count'] ?? 0,
            ) : null,
          );
        }).toList() ?? [];

        if (mounted) {
          setState(() {
            _chain = chain;
            _entries = entries;
            _isLoading = false;
          });
        }
      } else {
        throw Exception(response['error'] ?? 'Failed to load chain details');
      }
    } catch (e) {
      String errorMessage = 'Failed to load chain details';
      final errorStr = e.toString();
      final runtimeTypeName = e.runtimeType.toString();
      
      // Handle 401 unauthorized errors - session expired
      if (runtimeTypeName.contains('UnauthorizedException') ||
          errorStr.contains('UnauthorizedException') ||
          errorStr.contains('401') || errorStr.contains('Unauthorized') || 
          errorStr.contains('invalid JWT') || errorStr.contains('token is expired')) {
        errorMessage = 'Your session has expired. Please log in again.';
      }
      
      if (mounted) {
        setState(() {
          _error = errorMessage;
          _isLoading = false;
        });
      }
      debugPrint('Error fetching chain details: $e');
    }
  }

  Future<void> _createEntry() async {
    // Navigate to the create entry screen and wait for it to pop
    await context.push(
      '/writing-chains/${widget.chainId}/create-entry',
      extra: _chain?.title,
    );
    // Refresh the list when returning from create entry screen
    if (mounted) {
      _fetchChainDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/writing-chains'),
        ),
        title: Text(_chain?.title ?? 'Chain Entries'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: authState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : authState.isAuthenticated
                ? _buildAuthenticatedView()
                : _buildUnauthenticatedView(),
      ),
      floatingActionButton: authState.isAuthenticated && _chain != null
          ? FloatingActionButton(
              onPressed: _isLoading ? null : _createEntry,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildAuthenticatedView() {
    if (_isLoading && _chain == null) {
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
              onPressed: _fetchChainDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_chain == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _fetchChainDetails,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        children: [
          // Chain info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _chain!.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_chain!.description != null && _chain!.description!.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      _chain!.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    '${_entries.length} entries',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),

          // Entries
          if (_entries.isEmpty) ...[
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  Text(
                    'No entries yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    'Be the first to add your poem to this chain!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            ..._entries.map((entry) => _buildEntryCard(entry)),
          ],
        ],
      ),
    );
  }

  Widget _buildEntryCard(ChainEntry entry) {
    if (entry.post == null) {
      return const SizedBox.shrink();
    }

    final post = entry.post!;
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Entry sequence and menu
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                    vertical: AppTheme.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                  ),
                  child: Text(
                    '#${entry.sequence}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Text(
                    post.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editEntry(entry);
                    } else if (value == 'delete') {
                      _deleteEntry(entry);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingM),

            // Cover image if available
            if (post.coverImageUrl != null && post.coverImageUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                child: Image.network(
                  post.coverImageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: const Center(child: Icon(Icons.image_not_supported)),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
            ],

            // Creator info if available
            if (post.creatorName != null || post.publishedAt != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (post.creatorName != null) ...[
                    Text(
                      'By ${post.creatorName}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  Text(
                    'Added ${entry.addedAtFormatted}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
            ],

            // Category and tags if available
            if (post.category != null || (post.tags != null && post.tags!.isNotEmpty)) ...[
              Wrap(
                spacing: AppTheme.spacingXS,
                runSpacing: AppTheme.spacingXS,
                children: [
                  if (post.category != null) ...[
                    Chip(
                      label: Text(post.category!),
                      labelStyle: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                  if (post.tags != null && post.tags!.isNotEmpty) ...[
                    ...post.tags!.map((tag) => Chip(
                      label: Text('#$tag'),
                      labelStyle: Theme.of(context).textTheme.labelSmall,
                    )),
                  ],
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
            ],

            // Excerpt
            if (post.excerpt != null && post.excerpt!.isNotEmpty) ...[
              Text(
                post.excerpt!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
            ],

            // Full content with expandable "See more"
            _ExpandableContent(
              content: post.content ?? '',
              maxLines: 10,
              textStyle: Theme.of(context).textTheme.bodyMedium,
            ),

            const SizedBox(height: AppTheme.spacingM),

            // Divider
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),

            const SizedBox(height: AppTheme.spacingS),

            // Engagement buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildEngagementButton(
                  icon: Icons.favorite_outline,
                  label: '${post.likesCount}',
                  onPressed: () => _handleLike(entry),
                ),
                _buildEngagementButton(
                  icon: Icons.comment_outlined,
                  label: '${post.commentsCount}',
                  onPressed: () => _handleComment(entry),
                ),
                _buildEngagementButton(
                  icon: Icons.share_outlined,
                  label: '${post.sharesCount}',
                  onPressed: () => _handleShare(entry),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnauthenticatedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.link_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'Sign in to view chain entries',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: AppTheme.spacingXS),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLike(ChainEntry entry) async {
    if (entry.post == null) return;

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post(
        '/chronicles/chains/entries/reactions',
        data: { 'entry_post_id': entry.post!.id },
      );

      if (response['success'] == true || response['action'] != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Liked!')),
          );
          _fetchChainDetails();
        }
      } else {
        throw Exception(response['error'] ?? 'Failed to like');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _handleComment(ChainEntry entry) async {
    if (entry.post == null) return;

    final commentController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Comment'),
        content: TextField(
          controller: commentController,
          decoration: const InputDecoration(
            labelText: 'Your comment',
            hintText: 'Share your thoughts...',
          ),
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (commentController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(commentController.text.trim());
              }
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final apiService = ref.read(apiServiceProvider);
        final response = await apiService.post(
          '/chronicles/chains/entries/comments',
          data: { 
            'entry_post_id': entry.post!.id,
            'content': result,
          },
        );

        if (response['success'] == true || response['comment'] != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Comment posted!')),
            );
            _fetchChainDetails();
          }
        } else {
          throw Exception(response['error'] ?? 'Failed to post comment');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleShare(ChainEntry entry) async {
    if (entry.post == null) return;

    try {
      // Create a deep link that opens the entry in the app
      final deepLink = 'whisprmobile://writing-chains/${widget.chainId}/entry/${entry.post!.id}';
      final webLink = 'https://whispr.app/writing-chains/${widget.chainId}/entry/${entry.post!.id}';
      
      final shareText = '''
Check out this entry: "${entry.post!.title}"

Opening in Whispr app: $deepLink
Or visit: $webLink
''';

      // Use the Share plugin to share
      await Share.share(
        shareText,
        subject: 'Check out this entry from Whispr: ${entry.post!.title}',
      );

      // Also log the share to the backend
      try {
        final apiService = ref.read(apiServiceProvider);
        await apiService.post(
          '/chronicles/chains/entries/shares',
          data: { 'entry_post_id': entry.post!.id },
        );
      } catch (e) {
        debugPrint('Error logging share: $e');
        // Don't fail even if logging fails
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _editEntry(ChainEntry entry) async {
    if (entry.post == null) return;

    // Navigate to edit entry screen
    await context.push(
      '/writing-chains/${widget.chainId}/edit-entry/${entry.post!.id}',
      extra: {
        'title': entry.post!.title,
        'chainTitle': _chain?.title,
      },
    );

    // Refresh the list when returning from edit entry screen
    if (mounted) {
      _fetchChainDetails();
    }
  }

  Future<void> _deleteEntry(ChainEntry entry) async {
    if (entry.post == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final apiService = ref.read(apiServiceProvider);
      debugPrint('Deleting entry: ${entry.post!.id}');
      
      final response = await apiService.delete(
        '/chronicles/chains/entries/${entry.post!.id}',
      );

      debugPrint('Delete response: $response');

      if (response['success'] == true || response is Map && response['message'] != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entry deleted!')),
          );
          _fetchChainDetails();
        }
      } else {
        final errorMsg = response['error'] ?? response.toString() ?? 'Failed to delete entry';
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Delete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class ChainEntry {
  final String id;
  final int sequence;
  final String addedAt;
  final PostSummary? post;

  ChainEntry({
    required this.id,
    required this.sequence,
    required this.addedAt,
    this.post,
  });

  String get addedAtFormatted {
    try {
      final date = DateTime.parse(addedAt);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return addedAt;
    }
  }
}

/// Expandable content widget with "See more" / "See less" functionality
class _ExpandableContent extends StatefulWidget {
  final String content;
  final int maxLines;
  final TextStyle? textStyle;

  const _ExpandableContent({
    required this.content,
    this.maxLines = 5,
    this.textStyle,
  });

  @override
  State<_ExpandableContent> createState() => _ExpandableContentState();
}

class _ExpandableContentState extends State<_ExpandableContent> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.content,
          style: widget.textStyle ?? Theme.of(context).textTheme.bodyMedium,
          maxLines: _isExpanded ? null : widget.maxLines,
          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        // Check if content actually overflows
        if (_shouldShowExpandButton()) ...[
          const SizedBox(height: AppTheme.spacingS),
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Text(
              _isExpanded ? 'See less' : 'See more',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _shouldShowExpandButton() {
    // Simple heuristic: if content has many lines or characters
    final lineCount = widget.content.split('\n').length;
    final characterCount = widget.content.length;
    return lineCount > widget.maxLines || characterCount > 500;
  }
}

class PostSummary {
  final String id;
  final String title;
  final String slug;
  final String? excerpt;
  final String? content;
  final String? coverImageUrl;
  final String? category;
  final List<String>? tags;
  final String? publishedAt;
  final String? creatorName;
  final String? creatorId;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;

  PostSummary({
    required this.id,
    required this.title,
    required this.slug,
    this.excerpt,
    this.content,
    this.coverImageUrl,
    this.category,
    this.tags,
    this.publishedAt,
    this.creatorName,
    this.creatorId,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
  });
}
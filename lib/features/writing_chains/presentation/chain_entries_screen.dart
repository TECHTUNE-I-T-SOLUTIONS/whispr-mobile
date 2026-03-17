import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
              publishedAt: post['published_at'],
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
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createEntry() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Your Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Give your poem a title',
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                labelText: 'Content',
                hintText: 'Write your poem here...',
              ),
              maxLines: 8,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty && contentController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Add Entry'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        setState(() => _isLoading = true);
        final apiService = ref.read(apiServiceProvider);
        final response = await apiService.post('/chronicles/chains/${widget.chainId}', data: {
          'title': titleController.text.trim(),
          'content': contentController.text.trim(),
          'post_type': 'poem',
          'status': 'published',
        });

        if (response['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Entry added successfully!')),
            );
            _fetchChainDetails(); // Refresh the list
          }
        } else {
          throw Exception(response['error'] ?? 'Failed to add entry');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add entry: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (mounted) {
              // Use canPop to safely check if we can navigate back
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                // If can't pop, navigate to home as fallback
                context.go('/home');
              }
            }
          },
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
            ..._entries.map((entry) => Card(
              margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
              child: InkWell(
                onTap: entry.post != null ? () {
                  // Navigate to post detail using post ID
                  context.go('/post/${entry.post!.id}');
                } : null,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                              entry.post?.title ?? 'Untitled',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (entry.post?.excerpt != null && entry.post!.excerpt!.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spacingS),
                        Text(
                          entry.post!.excerpt!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        'Added ${entry.addedAtFormatted}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      Divider(
                        height: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Row(
                        children: [
                          Icon(
                            Icons.favorite_outline,
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: AppTheme.spacingXS),
                          Text(
                            '${entry.post?.likesCount ?? 0}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingM),
                          Icon(
                            Icons.comment_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: AppTheme.spacingXS),
                          Text(
                            '${entry.post?.commentsCount ?? 0}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingM),
                          Icon(
                            Icons.share_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: AppTheme.spacingXS),
                          Text(
                            '${entry.post?.sharesCount ?? 0}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )),
          ],
        ],
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

class PostSummary {
  final String id;
  final String title;
  final String slug;
  final String? excerpt;
  final String? publishedAt;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;

  PostSummary({
    required this.id,
    required this.title,
    required this.slug,
    this.excerpt,
    this.publishedAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
  });
}
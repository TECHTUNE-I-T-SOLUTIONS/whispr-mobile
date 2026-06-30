import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/stories_service.dart';

final storiesServiceProvider = Provider<StoriesService>((ref) {
  return StoriesService(Supabase.instance.client);
});

class StoryDetailScreen extends ConsumerStatefulWidget {
  final String storySlug;
  final String? chapterSlug;

  const StoryDetailScreen({
    super.key,
    required this.storySlug,
    this.chapterSlug,
  });

  @override
  ConsumerState<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends ConsumerState<StoryDetailScreen> {
  Map<String, dynamic>? _storyData;
  List<Map<String, dynamic>> _chapters = [];
  bool _isLoading = true;
  bool _isLiked = false;
  int _currentChapterIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadStory();
  }

  Future<void> _loadStory() async {
    setState(() => _isLoading = true);
    final service = ref.read(storiesServiceProvider);

    if (widget.chapterSlug != null) {
      final data = await service.getChapterBySlugs(widget.storySlug, widget.chapterSlug!);
      if (data != null && mounted) {
        setState(() {
          _storyData = data;
          _chapters = data['all_chapters'] as List<Map<String, dynamic>>;
          final currentChapter = data['chapter'] as Map<String, dynamic>;
          _currentChapterIndex = _chapters.indexWhere((c) => c['id'] == currentChapter['id']);
          _isLoading = false;
        });
        _checkLikeStatus();
      }
    } else {
      final story = await service.getStoryBySlug(widget.storySlug);
      if (story != null && mounted) {
        setState(() {
          _storyData = {'story': story};
          _isLoading = false;
        });
        _loadChapters(story);
        _checkLikeStatus();
      }
    }
  }

  Future<void> _loadChapters(Map<String, dynamic> story) async {
    final service = ref.read(storiesServiceProvider);
    final chapters = await service.getStoryChapters(
      story['id'],
      story['author_type'],
    );
    if (mounted) {
      setState(() => _chapters = chapters);
    }
  }

  Future<void> _checkLikeStatus() async {
    final story = _storyData?['story'];
    if (story == null) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final service = ref.read(storiesServiceProvider);
    final isLiked = await service.getStoryLikeStatus(
      story['id'],
      user.id,
      story['author_type'],
    );
    if (mounted) {
      setState(() => _isLiked = isLiked);
    }
  }

  Future<void> _toggleLike() async {
    final story = _storyData?['story'];
    if (story == null) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like stories')),
      );
      return;
    }

    final service = ref.read(storiesServiceProvider);
    setState(() => _isLiked = !_isLiked);

    if (_isLiked) {
      await service.likeStory(story['id'], user.id, story['author_type']);
    } else {
      await service.unlikeStory(story['id'], user.id, story['author_type']);
    }

    // Reload story to get updated counts
    _loadStory();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final story = _storyData?['story'];
    final currentChapter = _storyData?['chapter'];

    if (story == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Story Not Found'),
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
        ),
        body: const Center(child: Text('Story not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(story['title'] ?? 'Story'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border),
            color: _isLiked ? Colors.red : null,
            onPressed: _toggleLike,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareStory(story),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildStoryHeader(story)),
          if (currentChapter != null)
            SliverToBoxAdapter(child: _buildChapterContent(currentChapter))
          else if (_chapters.isNotEmpty)
            SliverToBoxAdapter(child: _buildChapterList()),
          SliverToBoxAdapter(child: _buildCommentsSection(story)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildStoryHeader(Map<String, dynamic> story) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (story['cover_image_url'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                story['cover_image_url'],
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.auto_stories,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          Text(
            story['title'] ?? '',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: story['author_avatar'] != null
                    ? NetworkImage(story['author_avatar'])
                    : null,
                child: story['author_avatar'] == null
                    ? Text(
                        (story['author_name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story['author_name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      story['genre'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (story['description'] != null) ...[
            const SizedBox(height: 16),
            Text(
              story['description'],
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStat(Icons.favorite, '${story['likes_count'] ?? 0}'),
              const SizedBox(width: 24),
              _buildStat(Icons.visibility, '${story['views_count'] ?? 0}'),
              const SizedBox(width: 24),
              _buildStat(Icons.comment, '${story['comments_count'] ?? 0}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String count) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Text(count, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildChapterContent(Map<String, dynamic> chapter) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chapter['title'] ?? '',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            chapter['content'] ?? '',
            style: const TextStyle(fontSize: 16, height: 1.6),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentChapterIndex > 0)
                ElevatedButton.icon(
                  onPressed: () => _navigateToChapter(_currentChapterIndex - 1),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                ),
              if (_currentChapterIndex < _chapters.length - 1)
                ElevatedButton.icon(
                  onPressed: () => _navigateToChapter(_currentChapterIndex + 1),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChapterList() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chapters (${_chapters.length})',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ..._chapters.asMap().entries.map((entry) {
            final index = entry.key;
            final chapter = entry.value;
            return ListTile(
              title: Text(chapter['title'] ?? ''),
              subtitle: Text('Chapter ${index + 1}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(
                '/stories/${widget.storySlug}/chapter/${chapter['slug']}',
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(Map<String, dynamic> story) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comments',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showCommentDialog(story),
            icon: const Icon(Icons.add_comment),
            label: const Text('Add Comment'),
          ),
        ],
      ),
    );
  }

  void _navigateToChapter(int index) {
    final chapter = _chapters[index];
    context.push('/stories/${widget.storySlug}/chapter/${chapter['slug']}');
  }

  void _shareStory(Map<String, dynamic> story) {
    // Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon')),
    );
  }

  void _showCommentDialog(Map<String, dynamic> story) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Comment'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Write your comment...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              
              final user = Supabase.instance.client.auth.currentUser;
              final service = ref.read(storiesServiceProvider);
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              
              try {
                await service.addStoryComment(
                  storyId: story['id'],
                  commenterName: user?.userMetadata?['full_name'] ?? 'Anonymous',
                  content: controller.text.trim(),
                  authorType: story['author_type'],
                  userId: user?.id,
                );
                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Comment added')),
                  );
                  _loadStory();
                }
              } catch (e) {
                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }
}

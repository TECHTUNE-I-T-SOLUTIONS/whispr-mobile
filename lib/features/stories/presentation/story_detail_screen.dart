import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/stories_service.dart';
import '../../../core/constants/layout.dart';
import '../../auth/auth_state.dart';

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

    final service = ref.read(storiesServiceProvider);
    final userId = service.currentUserId;
    if (userId == null) return;

    final isLiked = await service.getStoryLikeStatus(
      story['id'],
      userId,
      story['author_type'],
    );
    if (mounted) {
      setState(() => _isLiked = isLiked);
    }
  }

  Future<void> _toggleLike() async {
    final story = _storyData?['story'];
    if (story == null) return;

    final service = ref.read(storiesServiceProvider);
    final userId = service.currentUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like stories')),
      );
      return;
    }

    setState(() => _isLiked = !_isLiked);

    try {
      if (_isLiked) {
        await service.likeStory(story['id'], userId, story['author_type']);
      } else {
        await service.unlikeStory(story['id'], userId, story['author_type']);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLiked = !_isLiked);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update like: $e')),
        );
      }
      return;
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
          const SliverToBoxAdapter(child: SizedBox(height: kBottomNavClearance)),
        ],
      ),
    );
  }

  Widget _buildStoryHeader(Map<String, dynamic> story) {
    // The view exposes `author_avatar`, but older rows only carry the raw
    // profile image, so fall back to it before showing an initial.
    final avatarUrl = (story['author_avatar'] ??
            story['profile_image_url'] ??
            story['creator_avatar'])
        ?.toString();
    final authorName = (story['author_name'] ??
            story['pen_name'] ??
            story['author_username'] ??
            'Unknown')
        .toString();
    final initial = authorName.trim().isEmpty
        ? 'U'
        : authorName.trim().characters.first.toUpperCase();

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
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        initial,
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
                      authorName,
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

  Future<void> _shareStory(Map<String, dynamic> story) async {
    final slug = story['slug'] ?? widget.storySlug;
    final url = 'https://www.whisprwords.com/stories/$slug';
    final title = (story['title'] ?? 'A story on Whispr').toString();
    final text = '$title — read it on Whispr';

    try {
      await Share.share(
        '$text\n$url',
        subject: title,
        sharePositionOrigin: _shareOrigin(),
      );
    } catch (_) {
      // Fall back to the clipboard when no share sheet is available.
      await Clipboard.setData(ClipboardData(text: '$text\n$url'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied to clipboard')),
        );
      }
    }
  }

  /// iPad needs an anchor rect for the share sheet.
  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return box.localToGlobal(Offset.zero) & box.size;
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
              
              // Prefer the app's own session: Supabase's `currentUser` is null
              // whenever the Supabase session could not be restored, which made
              // signed-in readers post comments as "Anonymous".
              final appUser = ref.read(authStateProvider).user;
              final user = Supabase.instance.client.auth.currentUser;
              final service = ref.read(storiesServiceProvider);
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              
              try {
                await service.addStoryComment(
                  storyId: story['id'],
                  commenterName: (appUser?.displayName.isNotEmpty ?? false)
                      ? appUser!.displayName
                      : (appUser?.penName.isNotEmpty ?? false)
                          ? appUser!.penName
                          : user?.userMetadata?['full_name'] ?? 'Anonymous',
                  content: controller.text.trim(),
                  authorType: story['author_type'],
                  userId: appUser?.id ?? user?.id,
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

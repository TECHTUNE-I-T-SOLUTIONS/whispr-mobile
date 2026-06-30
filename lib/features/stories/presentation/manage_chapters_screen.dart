import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/stories_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_state.dart';

class ManageChaptersScreen extends ConsumerStatefulWidget {
  final String storyId;
  final String storyTitle;

  const ManageChaptersScreen({
    super.key,
    required this.storyId,
    required this.storyTitle,
  });

  @override
  ConsumerState<ManageChaptersScreen> createState() => _ManageChaptersScreenState();
}

class _ManageChaptersScreenState extends ConsumerState<ManageChaptersScreen> {
  List<Map<String, dynamic>> _chapters = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(storiesServiceProvider);
      final chapters = await service.getStoryChapters(
        widget.storyId,
        'chronicle',
        includeDrafts: true,
      );

      if (mounted) {
        setState(() {
          _chapters = chapters;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading chapters: $e';
        });
      }
    }
  }

  Future<void> _addChapter() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditChapterScreen(
          storyId: widget.storyId,
          onSave: (chapter) {
            _loadChapters();
          },
        ),
      ),
    );

    if (result == true) {
      _loadChapters();
    }
  }

  Future<void> _editChapter(Map<String, dynamic> chapter) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditChapterScreen(
          storyId: widget.storyId,
          chapter: chapter,
          onSave: (updatedChapter) {
            _loadChapters();
          },
        ),
      ),
    );

    if (result == true) {
      _loadChapters();
    }
  }

  Future<void> _deleteChapter(String chapterId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chapter'),
        content: const Text('Are you sure you want to delete this chapter? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('chronicles_story_chapters')
          .delete()
          .eq('id', chapterId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chapter deleted successfully')),
        );
        _loadChapters();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete chapter: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(widget.storyTitle),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addChapter,
            tooltip: 'Add Chapter',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadChapters,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _chapters.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_book_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No chapters yet',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first chapter to get started',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _chapters.length,
                      itemBuilder: (context, index) {
                        final chapter = _chapters[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            title: Text(
                              chapter['title'] ?? 'Untitled Chapter',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: chapter['status'] == 'published'
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    chapter['status'] == 'published' ? 'Published' : 'Draft',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: chapter['status'] == 'published'
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Seq: ${chapter['sequence'] ?? 0}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).textTheme.bodySmall?.color,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () => _editChapter(chapter),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  onPressed: () => _deleteChapter(chapter['id']),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class EditChapterScreen extends ConsumerStatefulWidget {
  final String storyId;
  final Map<String, dynamic>? chapter;
  final Function(Map<String, dynamic>) onSave;

  const EditChapterScreen({
    super.key,
    required this.storyId,
    this.chapter,
    required this.onSave,
  });

  @override
  ConsumerState<EditChapterScreen> createState() => _EditChapterScreenState();
}

class _EditChapterScreenState extends ConsumerState<EditChapterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _slugController = TextEditingController();
  int _sequence = 0;
  String? _status;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.chapter != null) {
      _titleController.text = widget.chapter!['title'] ?? '';
      _contentController.text = widget.chapter!['content'] ?? '';
      _slugController.text = widget.chapter!['slug'] ?? '';
      _sequence = widget.chapter!['sequence'] ?? 0;
      _status = widget.chapter!['status'] ?? 'draft';
    } else {
      _status = 'draft';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _slugController.dispose();
    super.dispose();
  }

  Future<void> _saveChapter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final service = ref.read(storiesServiceProvider);
      
      // Generate slug from title if not provided
      final slug = _slugController.text.trim().isEmpty
          ? _titleController.text
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
              .replaceAll(' ', '-')
              .replaceAll(RegExp(r'-{2,}'), '-')
              .trim()
          : _slugController.text.trim();

      if (widget.chapter != null) {
        // Update existing chapter
        await service.updateStoryChapter(
          chapterId: widget.chapter!['id'],
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          status: _status,
        );
      } else {
        // Create new chapter
        await service.createStoryChapter(
          storyId: widget.storyId,
          title: _titleController.text.trim(),
          slug: slug,
          content: _contentController.text.trim(),
          sequence: _sequence,
          status: _status,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.chapter != null
                  ? 'Chapter updated successfully'
                  : 'Chapter created successfully',
            ),
          ),
        );
        widget.onSave({});
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save chapter: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(widget.chapter != null ? 'Edit Chapter' : 'New Chapter'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveChapter,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Chapter Title *',
                hintText: 'Enter chapter title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Slug
            TextFormField(
              controller: _slugController,
              decoration: InputDecoration(
                labelText: 'Chapter Slug (URL)',
                hintText: 'Auto-generated from title if empty',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 20),

            // Sequence
            TextFormField(
              initialValue: _sequence.toString(),
              decoration: InputDecoration(
                labelText: 'Sequence Number',
                hintText: 'Order of chapter in story',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                _sequence = int.tryParse(value) ?? 0;
              },
            ),
            const SizedBox(height: 20),

            // Status
            DropdownButtonFormField<String>(
              value: _status,
              decoration: InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              items: const [
                DropdownMenuItem(value: 'draft', child: Text('Draft')),
                DropdownMenuItem(value: 'published', child: Text('Published')),
              ],
              onChanged: (value) {
                setState(() => _status = value);
              },
            ),
            const SizedBox(height: 20),

            // Content
            TextFormField(
              controller: _contentController,
              decoration: InputDecoration(
                labelText: 'Chapter Content *',
                hintText: 'Write your chapter content here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                alignLabelWithHint: true,
              ),
              maxLines: 20,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Content is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Chapters are ordered by sequence number. '
                      'You can use HTML tags for formatting (e.g., <p>, <h2>, <strong>)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
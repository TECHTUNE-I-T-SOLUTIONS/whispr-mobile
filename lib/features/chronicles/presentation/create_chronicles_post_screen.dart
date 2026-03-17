import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_service.dart';
import '../../../core/theme/app_theme.dart';

class CreateChroniclesPostScreen extends ConsumerStatefulWidget {
  const CreateChroniclesPostScreen({super.key});

  @override
  ConsumerState<CreateChroniclesPostScreen> createState() => _CreateChroniclesPostScreenState();
}

class _CreateChroniclesPostScreenState extends ConsumerState<CreateChroniclesPostScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _excerptController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  final _coverImageUrlController = TextEditingController();
  String _postType = 'blog'; // 'blog' or 'poem'
  String _status = 'draft'; // 'draft' or 'published'
  DateTime? _scheduledFor;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _excerptController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _coverImageUrlController.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter content')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiService = ref.read(apiServiceProvider);

      // Generate slug from title
      final slug = _titleController.text
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '-')
          .replaceAll(RegExp(r'-+'), '-')
          .trim();

      // Parse tags
      final tags = _tagsController.text.isNotEmpty
          ? _tagsController.text.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList()
          : [];

      final response = await apiService.post('/chronicles/creator/posts', data: {
        'title': _titleController.text.trim(),
        'slug': slug,
        'content': _contentController.text.trim(),
        'excerpt': _excerptController.text.trim().isNotEmpty ? _excerptController.text.trim() : null,
        'post_type': _postType,
        'category': _categoryController.text.trim().isNotEmpty ? _categoryController.text.trim() : null,
        'tags': tags,
        'status': _status,
        'cover_image_url': _coverImageUrlController.text.trim().isNotEmpty ? _coverImageUrlController.text.trim() : null,
        'scheduled_for': _scheduledFor?.toIso8601String(),
        'formatting_data': {},
      });

      if (response['id'] != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post created successfully!')),
          );
          context.go('/chronicles');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Post'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createPost,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Publish'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'Enter your post title',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppTheme.spacingM),

            // Post Type
            DropdownButtonFormField<String>(
              initialValue: _postType,
              decoration: const InputDecoration(
                labelText: 'Post Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'blog', child: Text('Blog Post')),
                DropdownMenuItem(value: 'poem', child: Text('Poem')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _postType = value);
                }
              },
            ),
            const SizedBox(height: AppTheme.spacingM),

            // Excerpt
            TextField(
              controller: _excerptController,
              decoration: const InputDecoration(
                labelText: 'Excerpt (Optional)',
                hintText: 'Brief summary of your post',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: AppTheme.spacingM),

            // Category
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Category (Optional)',
                hintText: 'e.g., Personal, Technology, Poetry',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // Tags
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (Optional)',
                hintText: 'Comma-separated tags',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // Cover Image URL
            TextField(
              controller: _coverImageUrlController,
              decoration: const InputDecoration(
                labelText: 'Cover Image URL (Optional)',
                hintText: 'Full URL to your cover image',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // Scheduled Date & Time
            InkWell(
              onTap: _isLoading
                  ? null
                  : () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _scheduledFor ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate != null) {
                        if (mounted) {
                          final pickedTime = await showTimePicker(
                            // ignore: use_build_context_synchronously
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(
                              _scheduledFor ?? DateTime.now(),
                            ),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              _scheduledFor = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      }
                    },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Schedule Post (Optional)',
                  hintText: 'Tap to schedule for later',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _scheduledFor == null
                      ? 'Not scheduled'
                      : 'Scheduled for ${_scheduledFor!.toString().split('.')[0]}',
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // Status
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'draft', child: Text('Draft')),
                DropdownMenuItem(value: 'published', child: Text('Published')),
                DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
            ),
            const SizedBox(height: AppTheme.spacingM),

            // Content
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Content *',
                hintText: 'Write your post content here...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 20,
              minLines: 10,
            ),
          ],
        ),
      ),
    );
  }
}
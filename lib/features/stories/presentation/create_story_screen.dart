import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/stories_service.dart';
import '../../../core/theme/app_theme.dart';

final storiesServiceProvider = Provider<StoriesService>((ref) {
  return StoriesService(Supabase.instance.client);
});

class CreateStoryScreen extends ConsumerStatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _excerptController = TextEditingController();
  final _genreController = TextEditingController();
  String? _coverImageUrl;
  bool _isSaving = false;

  final List<String> _genres = [
    'Fiction',
    'Non-Fiction',
    'Poetry',
    'Fantasy',
    'Romance',
    'Mystery',
    'Sci-Fi',
    'Horror',
    'Thriller',
    'Drama',
    'Adventure',
    'Historical',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _excerptController.dispose();
    _genreController.dispose();
    super.dispose();
  }

  Future<void> _saveStory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to create stories')),
        );
        setState(() => _isSaving = false);
      }
      return;
    }

    // Get creator ID from user
    final creatorResponse = await Supabase.instance.client
        .from('chronicles_creators')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (creatorResponse == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Creator profile not found')),
        );
        setState(() => _isSaving = false);
      }
      return;
    }

    final service = ref.read(storiesServiceProvider);
    final slug = _titleController.text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(' ', '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .trim();

    try {
      final story = await service.createChroniclesStory(
        creatorId: creatorResponse['id'],
        title: _titleController.text.trim(),
        slug: slug,
        genre: _genreController.text.trim(),
        description: _descriptionController.text.trim(),
        excerpt: _excerptController.text.trim(),
        coverImageUrl: _coverImageUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story created successfully!')),
        );
        context.pop();
        // Navigate to story detail
        if (story != null) {
          context.push('/stories/${story['slug']}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating story: $e')),
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
        title: const Text('Create Story'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveStory,
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
            _buildTextField(
              controller: _titleController,
              label: 'Title',
              hint: 'Enter your story title',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildDropdownField(
              controller: _genreController,
              label: 'Genre',
              hint: 'Select genre',
              items: _genres,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Genre is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Describe your story',
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _excerptController,
              label: 'Excerpt',
              hint: 'A short excerpt to show readers',
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            _buildCoverImageSection(),
            const SizedBox(height: 20),
            Text(
              'You can add chapters after creating the story.',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          validator: validator,
          maxLines: maxLines,
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required List<String> items,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: controller.text.isEmpty ? null : controller.text,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          items: items.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              controller.text = newValue;
            }
          },
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildCoverImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cover Image URL (Optional)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          decoration: InputDecoration(
            hintText: 'Enter image URL',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          onChanged: (value) {
            setState(() => _coverImageUrl = value.trim().isEmpty ? null : value.trim());
          },
        ),
        if (_coverImageUrl != null) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _coverImageUrl!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Text('Invalid image URL')),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

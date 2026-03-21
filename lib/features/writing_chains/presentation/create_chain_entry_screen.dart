import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/auth_state.dart';

class CreateChainEntryScreen extends ConsumerStatefulWidget {
  final String chainId;
  final String? chainTitle;

  const CreateChainEntryScreen({
    super.key,
    required this.chainId,
    this.chainTitle,
  });

  @override
  ConsumerState<CreateChainEntryScreen> createState() =>
      _CreateChainEntryScreenState();
}

class _CreateChainEntryScreenState extends ConsumerState<CreateChainEntryScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _excerptController = TextEditingController();
  final _coverImageUrlController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  String _selectedStatus = 'published';
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _excerptController.dispose();
    _coverImageUrlController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _createEntry() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('Please enter a title');
      return;
    }

    if (_contentController.text.trim().isEmpty) {
      _showSnackBar('Please enter content');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Parse tags from comma-separated string
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post(
        '/chronicles/chains/${widget.chainId}',
        data: {
          'title': _titleController.text.trim(),
          'content': _contentController.text.trim(),
          'excerpt': _excerptController.text.trim().isEmpty
              ? null
              : _excerptController.text.trim(),
          'cover_image_url': _coverImageUrlController.text.trim().isEmpty
              ? null
              : _coverImageUrlController.text.trim(),
          'category': _categoryController.text.trim().isEmpty
              ? null
              : _categoryController.text.trim(),
          'tags': tags.isEmpty ? null : tags,
          'status': _selectedStatus,
        },
      );

      if (response['success'] == true) {
        if (mounted) {
          _showSnackBar('Entry created successfully!');
          // Navigate back to chain details with a pop to trigger refresh
          context.pop();
        }
      } else {
        throw Exception(response['error'] ?? 'Failed to create entry');
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Entry'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: authState.isAuthenticated
          ? _buildCreateForm()
          : _buildUnauthenticatedView(),
    );
  }

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.chainTitle != null) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Adding entry to:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    widget.chainTitle!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
          ],
          Text(
            'Entry Details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          // Title field
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Title *',
              hintText: 'Enter entry title',
              prefixIcon: const Icon(Icons.title),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
              ),
            ),
            maxLines: 1,
            enabled: !_isLoading,
          ),
          const SizedBox(height: AppTheme.spacingM),
          // Content field
          TextField(
            controller: _contentController,
            decoration: InputDecoration(
              labelText: 'Content *',
              hintText: 'Write your poem or story here...',
              prefixIcon: const Icon(Icons.edit),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
              ),
            ),
            maxLines: 10,
            enabled: !_isLoading,
          ),
          const SizedBox(height: AppTheme.spacingM),
          // Excerpt field
          TextField(
            controller: _excerptController,
            decoration: InputDecoration(
              labelText: 'Excerpt (Optional)',
              hintText: 'Short summary of your entry',
              prefixIcon: const Icon(Icons.short_text),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
              ),
            ),
            maxLines: 3,
            enabled: !_isLoading,
          ),
          const SizedBox(height: AppTheme.spacingM),
          // Cover Image URL field
          TextField(
            controller: _coverImageUrlController,
            decoration: InputDecoration(
              labelText: 'Cover Image URL (Optional)',
              hintText: 'https://example.com/image.jpg',
              prefixIcon: const Icon(Icons.image),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
              ),
            ),
            maxLines: 1,
            enabled: !_isLoading,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: AppTheme.spacingM),
          // Category field
          TextField(
            controller: _categoryController,
            decoration: InputDecoration(
              labelText: 'Category (Optional)',
              hintText: 'e.g., Poetry, Fiction, Essay',
              prefixIcon: const Icon(Icons.category),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
              ),
            ),
            maxLines: 1,
            enabled: !_isLoading,
          ),
          const SizedBox(height: AppTheme.spacingM),
          // Tags field
          TextField(
            controller: _tagsController,
            decoration: InputDecoration(
              labelText: 'Tags (Optional)',
              hintText: 'Separate tags with commas',
              prefixIcon: const Icon(Icons.local_offer),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
              ),
            ),
            maxLines: 1,
            enabled: !_isLoading,
          ),
          const SizedBox(height: AppTheme.spacingM),
          // Status dropdown
          DropdownButtonFormField<String>(
            initialValue: _selectedStatus,
            decoration: InputDecoration(
              labelText: 'Status',
              prefixIcon: const Icon(Icons.publish),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'draft', child: Text('Draft')),
              DropdownMenuItem(value: 'published', child: Text('Published')),
              DropdownMenuItem(value: 'archived', child: Text('Archived')),
            ],
            onChanged: _isLoading
                ? null
                : (value) {
              if (value != null) {
                setState(() => _selectedStatus = value);
              }
            },
          ),
          const SizedBox(height: AppTheme.spacingL),
          // Create button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _createEntry,
              icon: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.check),
              label: Text(_isLoading ? 'Creating...' : 'Create Entry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacingM,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          // Cancel button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : () => context.pop(),
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacingM,
                ),
              ),
            ),
          ),
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
            Icons.lock_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'Sign in required',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Please sign in to create an entry',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingM),
          ElevatedButton(
            onPressed: () => context.go('/login'),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}

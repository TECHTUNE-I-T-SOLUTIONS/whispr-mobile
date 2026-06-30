import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_service.dart';
import '../../../core/services/stories_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_state.dart';

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
  String? _selectedGenre;
  String? _selectedStatus;
  String? _coverImageUrl;
  bool _isSaving = false;
  bool _isLoadingCreator = true;
  String? _creatorId;
  String? _errorMessage;

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
    'Comedy',
    'Philosophy',
    'Biography',
  ];

  final List<String> _statuses = [
    'draft',
    'published',
  ];

  @override
  void initState() {
    super.initState();
    _loadCreatorProfile();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _excerptController.dispose();
    super.dispose();
  }

  Future<void> _loadCreatorProfile() async {
    setState(() {
      _isLoadingCreator = true;
      _errorMessage = null;
    });

    try {
      final authState = ref.read(authStateProvider);
      final appUser = authState.user;
      
      // Use the app's auth state first, fall back to Supabase
      String? userId;
      if (authState.isAuthenticated && appUser != null) {
        userId = appUser.id;
      } else {
        final supabaseUser = Supabase.instance.client.auth.currentUser;
        if (supabaseUser != null) {
          userId = supabaseUser.id;
        }
      }

      if (userId == null) {
        setState(() {
          _isLoadingCreator = false;
          _errorMessage = 'Please log in to create stories';
        });
        return;
      }

      // Get creator ID from user via API
      try {
        final apiService = ApiService.instance;
        final creatorData = await apiService.get('/chronicles/creator/profile');
        final creator = creatorData['creator'] ?? creatorData;
        
        if (creator == null || creator['id'] == null) {
          setState(() {
            _isLoadingCreator = false;
            _errorMessage = 'Creator profile not found. Please create a chronicles creator profile first.';
          });
          return;
        }

        setState(() {
          _creatorId = creator['id'];
          _isLoadingCreator = false;
        });
      } catch (e) {
        // Fallback to direct Supabase query
        final creatorResponse = await Supabase.instance.client
            .from('chronicles_creators')
            .select('id, pen_name, bio, profile_image_url')
            .eq('user_id', userId)
            .maybeSingle();

        if (creatorResponse == null) {
          setState(() {
            _isLoadingCreator = false;
            _errorMessage = 'Creator profile not found. Please create a chronicles creator profile first.';
          });
          return;
        }

        setState(() {
          _creatorId = creatorResponse['id'];
          _isLoadingCreator = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingCreator = false;
        _errorMessage = 'Error loading profile: $e';
      });
    }
  }

  Future<void> _saveStory() async {
    if (!_formKey.currentState!.validate()) return;
    if (_creatorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Creator profile not loaded')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final service = ref.read(storiesServiceProvider);
    final slug = _titleController.text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(' ', '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .trim();

    try {
      final story = await service.createChroniclesStory(
        creatorId: _creatorId!,
        title: _titleController.text.trim(),
        slug: slug,
        genre: _selectedGenre ?? 'Fiction',
        description: _descriptionController.text.trim(),
        excerpt: _excerptController.text.trim(),
        coverImageUrl: _coverImageUrl,
      );

      // If status is published, update it
      if (_selectedStatus == 'published' && story != null) {
        await service.updateChroniclesStory(
          storyId: story['id'],
          status: 'published',
        );
      }

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: (_isSaving || _isLoadingCreator || _creatorId == null) ? null : _saveStory,
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
      body: _isLoadingCreator
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading creator profile...'),
                ],
              ),
            )
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
                          onPressed: _loadCreatorProfile,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Title
                      _buildSectionHeader('Story Title *'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: 'Enter your story title',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          prefixIcon: const Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Title is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Genre dropdown
                      _buildSectionHeader('Genre *'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedGenre,
                        decoration: InputDecoration(
                          hintText: 'Select genre',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          prefixIcon: const Icon(Icons.category),
                        ),
                        items: _genres.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedGenre = newValue;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Genre is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Status dropdown
                      _buildSectionHeader('Status'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: InputDecoration(
                          hintText: 'Select status (default: draft)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          prefixIcon: const Icon(Icons.publish),
                        ),
                        items: _statuses.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value == 'published' ? 'Published' : 'Draft'),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedStatus = newValue;
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // Description
                      _buildSectionHeader('Description'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          hintText: 'Describe your story (optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 24),

                      // Excerpt
                      _buildSectionHeader('Excerpt / Short Description'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _excerptController,
                        decoration: InputDecoration(
                          hintText: 'A short excerpt to show readers (optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),

                      // Cover Image URL
                      _buildSectionHeader('Cover Image URL'),
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: InputDecoration(
                          hintText: 'Paste image URL (optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          prefixIcon: const Icon(Icons.link),
                        ),
                        onChanged: (value) {
                          setState(() => _coverImageUrl = value.trim().isEmpty ? null : value.trim());
                        },
                      ),
                      if (_coverImageUrl != null && _coverImageUrl!.isNotEmpty) ...[
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
                                'You can add chapters to your story after creating it. '
                                'If you choose "Published", your story will be visible to everyone immediately.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }
}
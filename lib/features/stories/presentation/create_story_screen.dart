import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_service.dart';
import '../../../core/services/stories_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/creator_form.dart';
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
    final canSave = !(_isSaving || _isLoadingCreator || _creatorId == null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New story'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/stories'),
        ),
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
              : Column(
                  children: [
                    Expanded(
                      child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      CreatorForm.header(
                        context,
                        'Start a story',
                        'Give it a name and a home. You can add chapters right after this.',
                      ),
                      CreatorForm.label(context, 'Story title', required: true),
                      TextFormField(
                        controller: _titleController,
                        maxLength: CreatorForm.titleLimit,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.35),
                        decoration: InputDecoration(
                          hintText: 'e.g. The Salt Road',
                          counterStyle: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Title is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      CreatorForm.label(context, 'Genre', required: true),
                      CreatorForm.dropdown<String>(
                        value: _selectedGenre,
                        items: _genres,
                        hint: 'Choose a genre',
                        icon: Icons.local_offer_outlined,
                        onChanged: (value) => setState(() => _selectedGenre = value),
                        validator: (value) => (value == null || value.isEmpty) ? 'Pick a genre' : null,
                      ),
                      const SizedBox(height: 20),

                      CreatorForm.label(context, 'Visibility'),
                      CreatorForm.dropdown<String>(
                        value: _selectedStatus,
                        items: _statuses,
                        hint: 'Draft for now',
                        icon: Icons.visibility_outlined,
                        labelOf: (value) => value == 'published' ? 'Published — visible to everyone' : 'Draft — only you can see it',
                        onChanged: (value) => setState(() => _selectedStatus = value),
                      ),
                      const SizedBox(height: 20),

                      CreatorForm.label(context, 'Description'),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        maxLength: CreatorForm.descriptionLimit,
                        style: const TextStyle(fontSize: 14.5, height: 1.55),
                        decoration: InputDecoration(
                          hintText: 'What is this story about?',
                          alignLabelWithHint: true,
                          counterStyle: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      CreatorForm.label(context, 'Excerpt'),
                      TextFormField(
                        controller: _excerptController,
                        maxLines: 3,
                        maxLength: CreatorForm.excerptLimit,
                        style: const TextStyle(fontFamily: AppTheme.serifFamily, fontSize: 15, height: 1.5),
                        decoration: InputDecoration(
                          hintText: 'The line that makes a reader start',
                          alignLabelWithHint: true,
                          counterStyle: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                      CreatorForm.label(context, 'Cover image'),
                      TextFormField(
                        decoration: InputDecoration(
                          hintText: 'Paste an image URL (optional)',
                          prefixIcon: Icon(Icons.image_outlined, size: 19),
                        ),
                        keyboardType: TextInputType.url,
                        onChanged: (value) {
                          setState(() => _coverImageUrl = value.trim().isEmpty ? null : value.trim());
                        },
                      ),
                      if (_coverImageUrl != null && _coverImageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                          child: Image.network(
                            _coverImageUrl!,
                            height: 190,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 190,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'That URL did not load an image',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontSize: 13),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      CreatorForm.note(
                        context,
                        _selectedStatus == 'published'
                            ? 'Chapters come next — you will land on the chapter editor straight after this.'
                            : 'Saved as a draft. Publish it whenever you are ready, from your stories list.',
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                      ),
                    ),
                    CreatorForm.actionBar(
                      context,
                      label: _selectedStatus == 'published' ? 'Publish story' : 'Save draft',
                      busy: _isSaving,
                      busyLabel: 'Saving…',
                      onPressed: canSave ? _saveStory : null,
                    ),
                  ],
                ),
    );
  }
}


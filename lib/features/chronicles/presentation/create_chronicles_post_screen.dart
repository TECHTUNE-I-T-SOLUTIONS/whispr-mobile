import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_service.dart';
import '../../../core/services/daily_challenge_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/creator_form.dart';

class CreateChroniclesPostScreen extends ConsumerStatefulWidget {
  /// Set when the composer was opened from the daily challenge, so the screen
  /// can show the prompt and credit the streak when the entry is published.
  final String? challengeId;
  final String? challengePrompt;

  const CreateChroniclesPostScreen({super.key, this.challengeId, this.challengePrompt});

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
  void initState() {
    super.initState();
    // Live word count for the challenge brief.
    _contentController.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    if (mounted) setState(() {});
  }

  int get _wordCount {
    final text = _contentController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  @override
  void dispose() {
    _contentController.removeListener(_onContentChanged);
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
        // A post written for the daily challenge credits the streak, so the
        // card on the home screen flips to "done" the moment they return.
        if (widget.challengeId != null) {
          await DailyChallengeService.instance.completeToday(
            entryPreview: _contentController.text.trim(),
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.challengeId != null
                    ? 'Challenge complete. Your streak is safe.'
                    : 'Post created successfully!',
              ),
            ),
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
    final canPublish = !_isLoading && _contentController.text.trim().isNotEmpty;
    final isChallenge = widget.challengeId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isChallenge ? 'Daily challenge' : 'New post'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/chronicles'),
        ),
        actions: [
          if (_wordCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: Text(
                  '$_wordCount ${_wordCount == 1 ? 'word' : 'words'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Daily challenge brief
                  if (widget.challengePrompt != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.18)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bolt_rounded, size: 15, color: AppTheme.primaryColor),
                              const SizedBox(width: 6),
                              Text(
                                "TODAY'S CHALLENGE",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryColor.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Text(
                            widget.challengePrompt!,
                            style: const TextStyle(
                              fontFamily: AppTheme.serifFamily,
                              fontSize: 15.5,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Title
                  CreatorForm.label(context, 'Title', required: true),
                  TextField(
                    controller: _titleController,
                    maxLines: 2,
                    minLines: 1,
                    maxLength: CreatorForm.titleLimit,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.3),
                    decoration: InputDecoration(
                      hintText: _postType == 'poem' ? 'Give your poem a name' : 'What is this called?',
                      counterStyle: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Content comes before the metadata: the writing is the point.
                  CreatorForm.label(context, 'Body', required: true),
                  TextField(
                    controller: _contentController,
                    minLines: 12,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      fontFamily: _postType == 'poem' ? AppTheme.serifFamily : null,
                      fontSize: 16,
                      height: 1.65,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Start with one honest line.',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Post type
                  CreatorForm.label(context, 'Format'),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'poem', label: Text('Poem'), icon: Icon(Icons.auto_stories_outlined, size: 16)),
                      ButtonSegment(value: 'blog', label: Text('Prose'), icon: Icon(Icons.notes_rounded, size: 16)),
                    ],
                    selected: {_postType},
                    onSelectionChanged: (selection) => setState(() => _postType = selection.first),
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      textStyle: WidgetStateProperty.all(
                        const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Excerpt
                  CreatorForm.label(context, 'Excerpt'),
                  TextField(
                    controller: _excerptController,
                    maxLines: 3,
                    maxLength: CreatorForm.excerptLimit,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 14.5, height: 1.5),
                    decoration: InputDecoration(
                      hintText: 'The preview shown in the feed',
                      alignLabelWithHint: true,
                      counterStyle: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Category + tags side by side on wide screens
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _categoryController,
                          decoration: const InputDecoration(hintText: 'Category'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _tagsController,
                          decoration: const InputDecoration(hintText: 'tags, comma, separated'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Cover
                  TextField(
                    controller: _coverImageUrlController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      hintText: 'Cover image URL (optional)',
                      prefixIcon: Icon(Icons.image_outlined, size: 19),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Schedule
                  InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                    onTap: _isLoading ? null : _pickSchedule,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.schedule_rounded, size: 19),
                        suffixIcon: _scheduledFor == null
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () => setState(() {
                                  _scheduledFor = null;
                                  if (_status == 'scheduled') _status = 'draft';
                                }),
                              ),
                      ),
                      child: Text(
                        _scheduledFor == null
                            ? 'Publish now'
                            : _formatSchedule(_scheduledFor!),
                        style: TextStyle(
                          fontSize: 14,
                          color: _scheduledFor == null
                              ? Theme.of(context).textTheme.bodySmall?.color
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          CreatorForm.actionBar(
            context,
            label: isChallenge
                ? (_wordCount == 0 ? 'Write something first' : 'Publish & claim streak')
                : (_status == 'published' ? 'Publish' : 'Save draft'),
            busy: _isLoading,
            busyLabel: 'Publishing…',
            onPressed: canPublish ? _createPost : null,
            secondary: isChallenge
                ? null
                : OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() => _status = 'draft');
                            _createPost();
                          },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Draft'),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSchedule() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledFor ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final initialTime = TimeOfDay.fromDateTime(_scheduledFor ?? DateTime.now());
    final pickedTime = await showTimePicker(context: context, initialTime: initialTime);
    if (pickedTime == null || !mounted) return;

    setState(() {
      _scheduledFor = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      _status = 'scheduled';
    });
  }

  String _formatSchedule(DateTime when) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour12 = when.hour % 12 == 0 ? 12 : when.hour % 12;
    final minute = when.minute.toString().padLeft(2, '0');
    final suffix = when.hour < 12 ? 'am' : 'pm';
    return 'Scheduled for ${months[when.month - 1]} ${when.day}, $hour12:$minute$suffix';
  }
}

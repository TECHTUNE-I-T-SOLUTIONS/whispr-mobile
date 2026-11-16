import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_service.dart';
import '../../../core/services/content_cache_service.dart';
import '../../../core/services/creator_service.dart';
import '../../../shared/widgets/creator_form.dart';

final _creatorServiceProvider = Provider(
  (ref) => CreatorService(ApiService.instance, ContentCacheService()),
);

/// Creator profile and feed settings — the mobile counterpart of
/// `/chronicles/settings` on the web.
class CreatorSettingsScreen extends ConsumerStatefulWidget {
  const CreatorSettingsScreen({super.key});

  @override
  ConsumerState<CreatorSettingsScreen> createState() => _CreatorSettingsScreenState();
}

class _CreatorSettingsScreenState extends ConsumerState<CreatorSettingsScreen> {
  final _penNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _websiteController = TextEditingController();
  final _twitterController = TextEditingController();
  final _instagramController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _pushEnabled = true;
  String _visibility = 'public';
  String? _error;

  static const _visibilityOptions = {
    'public': 'Public — anyone can find and read your work',
    'followers': 'Followers only — only people who follow you',
    'private': 'Private — only you',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _penNameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _websiteController.dispose();
    _twitterController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final creator = await ref.read(_creatorServiceProvider).getProfile();
      if (!mounted) return;

      final socials = creator['social_links'] is Map
          ? Map<String, dynamic>.from(creator['social_links'] as Map)
          : <String, dynamic>{};

      setState(() {
        _penNameController.text = (creator['pen_name'] ?? '').toString();
        _bioController.text = (creator['bio'] ?? '').toString();
        _locationController.text = (creator['location'] ?? '').toString();
        _websiteController.text = (socials['website'] ?? '').toString();
        _twitterController.text = (socials['twitter'] ?? socials['x'] ?? '').toString();
        _instagramController.text = (socials['instagram'] ?? '').toString();
        _pushEnabled = creator['push_notifications_enabled'] != false;
        _visibility = (creator['profile_visibility'] ?? 'public').toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your settings.';
      });
    }
  }

  Future<void> _save() async {
    final penName = _penNameController.text.trim();
    if (penName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A pen name is required.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(_creatorServiceProvider).updateProfile(
            penName: penName,
            bio: _bioController.text.trim(),
            location: _locationController.text.trim(),
            profileVisibility: _visibility,
            pushNotificationsEnabled: _pushEnabled,
            socialLinks: {
              if (_websiteController.text.trim().isNotEmpty) 'website': _websiteController.text.trim(),
              if (_twitterController.text.trim().isNotEmpty) 'twitter': _twitterController.text.trim(),
              if (_instagramController.text.trim().isNotEmpty) 'instagram': _instagramController.text.trim(),
            },
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved.')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Creator settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Try again')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        children: [
                          CreatorForm.label(context, 'Pen name', required: true),
                          CreatorForm.field(
                            context,
                            controller: _penNameController,
                            hint: 'How readers know you',
                            maxLength: 40,
                          ),
                          const SizedBox(height: 16),
                          CreatorForm.label(context, 'Bio'),
                          CreatorForm.field(
                            context,
                            controller: _bioController,
                            hint: 'A few lines about your writing',
                            maxLines: 4,
                            maxLength: CreatorForm.descriptionLimit,
                          ),
                          const SizedBox(height: 16),
                          CreatorForm.label(context, 'Location'),
                          CreatorForm.field(
                            context,
                            controller: _locationController,
                            hint: 'City, country',
                            maxLength: 60,
                          ),
                          const SizedBox(height: 22),
                          CreatorForm.label(context, 'Links'),
                          CreatorForm.field(
                            context,
                            controller: _websiteController,
                            hint: 'https://your-site.com',
                            keyboardType: TextInputType.url,
                            icon: Icons.language_rounded,
                          ),
                          const SizedBox(height: 10),
                          CreatorForm.field(
                            context,
                            controller: _twitterController,
                            hint: 'X / Twitter profile URL',
                            keyboardType: TextInputType.url,
                            icon: Icons.alternate_email_rounded,
                          ),
                          const SizedBox(height: 10),
                          CreatorForm.field(
                            context,
                            controller: _instagramController,
                            hint: 'Instagram profile URL',
                            keyboardType: TextInputType.url,
                            icon: Icons.camera_alt_outlined,
                          ),
                          const SizedBox(height: 22),
                          CreatorForm.label(context, 'Who can see your profile'),
                          CreatorForm.dropdown<String>(
                            value: _visibility,
                            items: _visibilityOptions.keys.toList(),
                            labelOf: (value) => _visibilityOptions[value] ?? value,
                            onChanged: (value) => setState(() => _visibility = value ?? 'public'),
                          ),
                          const SizedBox(height: 18),
                          SwitchListTile.adaptive(
                            value: _pushEnabled,
                            onChanged: (value) => setState(() => _pushEnabled = value),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Notifications', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              'Replies, reviews and new followers',
                              style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                            ),
                          ),
                        ],
                      ),
                    ),
                    CreatorForm.actionBar(
                      context,
                      label: 'Save changes',
                      busy: _saving,
                      onPressed: _save,
                    ),
                  ],
                ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_service.dart';
import '../../../features/auth/auth_state.dart';

class ProfileDetailsScreen extends ConsumerStatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  ConsumerState<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends ConsumerState<ProfileDetailsScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Map<String, dynamic>? _stats;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final authState = ref.read(authStateProvider);
    final user = authState.user;
    if (user == null) {
      if (!mounted) return;
      setState(() => _loadingStats = false);
      return;
    }

    try {
      final response = await ApiService.instance.get('/chronicles/creator/stats');
      final stats = Map<String, dynamic>.from(response['creator'] ?? response);
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loadingStats = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingStats = false);
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    if (!authState.isAuthenticated || user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile Details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: Text('User not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Details'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).cardColor,
                Theme.of(context).cardColor.withValues(alpha: 0.8),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            children: [
              // Profile Avatar Section
              Center(
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _animationController,
                          curve: const Interval(0.2, 0.6, curve: Curves.elasticOut),
                        ),
                      ),
                      child: Hero(
                        tag: 'user-avatar',
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                          child: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: user.profileImageUrl!,
                                  imageBuilder: (context, imageProvider) => Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      image: DecorationImage(
                                        image: imageProvider,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  placeholder: (context, url) => SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppTheme.primaryColor.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Text(
                                    user.penName.isNotEmpty ? user.penName[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 32,
                                    ),
                                  ),
                                  fadeInDuration: const Duration(milliseconds: 300),
                                  fadeOutDuration: const Duration(milliseconds: 300),
                                  httpHeaders: const {
                                    'User-Agent': 'Whispr-Mobile-App/1.0',
                                  },
                                )
                              : Text(
                                  user.penName.isNotEmpty ? user.penName[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 32,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Column(
                            children: [
                              Text(
                                user.penName,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingM,
                                  vertical: AppTheme.spacingXS,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.primaryColor.withValues(alpha: 0.1),
                                      AppTheme.primaryColor.withValues(alpha: 0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  'Active Creator',
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingXL),

              // Account Information Section
              _buildDetailSection(
                'Account Information',
                [
                  _buildDetailItem('Pen Name', user.penName),
                  _buildDetailItem('Email', user.email),
                  _buildDetailItem('Display Name', user.displayName),
                  _buildDetailItem('Status', (user.status ?? 'active').replaceAll('_', ' ').toUpperCase()),
                  _buildDetailItem('Role', user.role.toUpperCase(), Icons.verified_user),
                  if (user.location != null && user.location!.isNotEmpty)
                    _buildDetailItem('Location', user.location!, Icons.location_on),
                  if (user.website != null && user.website!.isNotEmpty)
                    _buildDetailItem('Website', user.website!, Icons.language),
                  _buildDetailItem('Verified', user.verifiedBadge ? '✓ Yes' : 'No', user.verifiedBadge ? Icons.verified : Icons.cancel),
                ],
                0,
              ),
              const SizedBox(height: AppTheme.spacingL),

              // Content Type & Categories
              _buildDetailSection(
                'Content & Interests',
                [
                  _buildDetailItem('Content Type', user.contentType.name.toUpperCase()),
                  if (user.categories.isNotEmpty)
                    _buildDetailItem('Categories', user.categories.join(', ')),
                ],
                1,
              ),
              const SizedBox(height: AppTheme.spacingL),

              // Profile Statistics Section
              _buildDetailSection(
                'Profile Statistics',
                _loadingStats ? [_buildDetailItem('Loading', 'Please wait', Icons.hourglass_empty)] : [
                  _buildDetailItem('Total Posts', '${_stats?['postCount'] ?? user.postCount}', Icons.article_outlined),
                  _buildDetailItem('Blog Posts', '${_stats?['totalBlogs'] ?? user.totalBlogs}', Icons.description),
                  _buildDetailItem('Poems', '${_stats?['totalPoems'] ?? user.totalPoems}', Icons.auto_stories),
                  _buildDetailItem('Total Followers', '${_stats?['totalFollowers'] ?? user.totalFollowers}', Icons.people_outline),
                  _buildDetailItem('Total Engagement', '${_stats?['totalEngagement'] ?? user.totalEngagement}', Icons.favorite),
                  _buildDetailItem('Current Streak', '${_stats?['currentStreak'] ?? user.currentStreak}', Icons.local_fire_department),
                  _buildDetailItem('Total Points', '${_stats?['totalPoints'] ?? user.totalPoints}', Icons.star),
                  _buildDetailItem('Member Since', _formatDate(user.createdAt ?? ''), Icons.calendar_today),
                ],
                2,
              ),
              const SizedBox(height: AppTheme.spacingL),

              // Social Links
              if (user.socialLinks.isNotEmpty) ...[
                _buildDetailSection(
                  'Social Links',
                  user.socialLinks.entries.map((entry) => 
                    _buildDetailItem(
                      entry.key.replaceAll('_', ' ').toUpperCase(), 
                      entry.value,
                      Icons.link,
                    )
                  ).toList(),
                  3,
                ),
                const SizedBox(height: AppTheme.spacingL),
              ],

              // Badges
              if (user.badges.isNotEmpty) ...[
                _buildDetailSection(
                  'Badges & Achievements',
                  [
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Wrap(
                        spacing: AppTheme.spacingS,
                        runSpacing: AppTheme.spacingS,
                        children: user.badges.map((badge) =>
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingM,
                              vertical: AppTheme.spacingXS,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryColor.withValues(alpha: 0.2),
                                  AppTheme.primaryColor.withValues(alpha: 0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              badge,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        ).toList(),
                      ),
                    ),
                  ],
                  4,
                ),
                const SizedBox(height: AppTheme.spacingL),
              ],

              // Bio Section
              if (user.bio.isNotEmpty) ...[
                _buildDetailSection(
                  'Bio',
                  [],
                  5,
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      user.bio,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingL),
              ],

              // Action Buttons
              _buildActionButtons(),
              const SizedBox(height: AppTheme.spacingXL),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(
    String title,
    List<Widget> items,
    int animationIndex, {
    Widget? child,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + (animationIndex * 150)),
      curve: Curves.easeOut,
      builder: (context, value, childWidget) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
                if (child != null)
                  child
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      children: items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final isLast = index == items.length - 1;
                        return Column(
                          children: [
                            item,
                            if (!isLast)
                              Divider(
                                color: Colors.grey.withValues(alpha: 0.1),
                                height: 0,
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value, [IconData? icon]) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: AppTheme.primaryColor.withValues(alpha: 0.6),
                ),
                const SizedBox(width: AppTheme.spacingS),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildActionButtons() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to edit profile
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Edit profile coming soon!')),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Settings'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

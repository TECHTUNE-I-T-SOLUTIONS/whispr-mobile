import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/push_notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/auth_state.dart';
import '../../../features/theme/theme_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with TickerProviderStateMixin {
  final PushNotificationService _pushService = PushNotificationService();
  bool _notificationsEnabled = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
    _setupAnimations();
    _refreshUserProfile();
  }

  Future<void> _refreshUserProfile() async {
    final authState = ref.read(authStateProvider);
    if (authState.isAuthenticated) {
      try {
        // Refresh the avatar specifically
        await ref.read(authStateProvider.notifier).refreshAvatar();

        // The auth state should already have fresh data from login/initialization
        // If needed, we can trigger a refresh here
        debugPrint('User profile should be up to date');
      } catch (e) {
        // Silently fail - the existing user data should still work
        debugPrint('Failed to refresh user profile: $e');
      }
    }
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadNotificationSettings() async {
    final enabled = await _pushService.areNotificationsEnabled();
    setState(() {
      _notificationsEnabled = enabled;
    });
  }

  // ignore: unused_element
  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });

    if (value) {
      await _pushService.subscribeToPushNotifications();
      await _pushService.sendTestNotification(); // Send test notification
    } else {
      await _pushService.unsubscribeFromPushNotifications();
    }
  }

  // ignore: unused_element
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

  // ignore: unused_element
  void _showThemeSelectionDialog() {
    final themeNotifier = ref.read(themeModeProvider.notifier);
    final currentTheme = ref.read(themeModeProvider);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Light'),
                leading: Radio<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: currentTheme, // ignore: deprecated_member_use
                  onChanged: (ThemeMode? value) { // ignore: deprecated_member_use
                    if (value != null) {
                      themeNotifier.setThemeMode(value);
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
              ListTile(
                title: const Text('Dark'),
                leading: Radio<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: currentTheme, // ignore: deprecated_member_use
                  onChanged: (ThemeMode? value) { // ignore: deprecated_member_use
                    if (value != null) {
                      themeNotifier.setThemeMode(value);
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
              ListTile(
                title: const Text('System'),
                leading: Radio<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: currentTheme, // ignore: deprecated_member_use
                  onChanged: (ThemeMode? value) { // ignore: deprecated_member_use
                    if (value != null) {
                      themeNotifier.setThemeMode(value);
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // ignore: unused_element
  void _showHelpAndSupport() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Help & Support'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHelpItem(
                  icon: Icons.book,
                  title: 'Getting Started',
                  description: 'Learn how to create your first post and navigate the app.',
                ),
                const SizedBox(height: AppTheme.spacingM),
                _buildHelpItem(
                  icon: Icons.edit,
                  title: 'Writing Guide',
                  description: 'Tips and best practices for writing engaging content.',
                ),
                const SizedBox(height: AppTheme.spacingM),
                _buildHelpItem(
                  icon: Icons.notifications,
                  title: 'Notifications',
                  description: 'Manage your notification preferences and settings.',
                ),
                const SizedBox(height: AppTheme.spacingM),
                _buildHelpItem(
                  icon: Icons.monetization_on,
                  title: 'Monetization',
                  description: 'Learn about earning from your writing and content.',
                ),
                const SizedBox(height: AppTheme.spacingL),
                const Text(
                  'Contact Support',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppTheme.spacingS),
                const Text(
                  'For additional help, you can reach out to our support team through the feedback form or email us at support@whispr.com',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Navigate to feedback form
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Feedback form coming soon!')),
                );
              },
              child: const Text('Send Feedback'),
            ),
          ],
        );
      },
    );
  }

  // ignore: unused_element
  void _showSignOutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out? You will need to log in again to access your account.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _signOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authStateProvider.notifier).logout();
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign out: $e')),
        );
      }
    }
  }

  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
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
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).scaffoldBackgroundColor,
                Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const SizedBox(height: 20),
              // User Info Section
              if (authState.isAuthenticated && authState.user != null) ...[
                _buildUserCard(authState),
                const SizedBox(height: 24),
              ],

              // Settings Section
              _buildSectionHeader('Settings'),
              const SizedBox(height: 8),
              _buildSettingsCard(),

              const SizedBox(height: 24),

              // Features Section
              _buildSectionHeader('Features'),
              const SizedBox(height: 8),
              _buildFeaturesCard(authState),

              const SizedBox(height: 24),

              // Legal & Support Section
              _buildSectionHeader('Legal & Support'),
              const SizedBox(height: 8),
              _buildLegalCard(),

              const SizedBox(height: 24),

              // App Info Section
              _buildAppInfoCard(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildUserCard(AuthState authState) {
    return GestureDetector(
      onTap: () => context.push('/profile-details'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.1),
              AppTheme.primaryColor.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Hero(
              tag: 'user-avatar',
              child: CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                child: authState.user!.profileImageUrl != null && authState.user!.profileImageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: authState.user!.profileImageUrl!,
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
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Text(
                          authState.user!.penName.isNotEmpty
                              ? authState.user!.penName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        fadeInDuration: const Duration(milliseconds: 300),
                        fadeOutDuration: const Duration(milliseconds: 300),
                        httpHeaders: const {
                          'User-Agent': 'Whispr-Mobile-App/1.0',
                        },
                      )
                    : Text(
                        authState.user!.penName.isNotEmpty
                            ? authState.user!.penName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authState.user!.penName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    authState.user!.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha((0.7 * 255).toInt()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Creator',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward,
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).toInt()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingItem(
            icon: Icons.notifications_outlined,
            title: 'Push Notifications',
            subtitle: 'Receive notifications about new content and updates',
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
              activeThumbColor: AppTheme.primaryColor,
            ),
          ),
          _buildDivider(),
          _buildSettingItem(
            icon: Icons.palette_outlined,
            title: 'Theme',
            subtitle: 'Light, Dark, or System',
            onTap: _showThemeSelectionDialog,
          ),
          _buildDivider(),
          _buildSettingItem(
            icon: Icons.logout_outlined,
            title: 'Sign Out',
            subtitle: 'Log out of your account',
            onTap: _showSignOutConfirmation,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesCard(AuthState authState) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildFeatureItem(
            icon: Icons.book_outlined,
            title: 'My Chronicles',
            subtitle: 'View and manage your writing',
            onTap: () => context.go('/chronicles'),
          ),
          _buildDivider(),
          _buildFeatureItem(
            icon: Icons.rule_folder_outlined,
            title: 'Reviews & Appeals',
            subtitle: 'View flagged posts and appeal status',
            onTap: () => context.go('/reviews'),
          ),
          _buildDivider(),
          _buildFeatureItem(
            icon: Icons.link_outlined,
            title: 'Writing Chains',
            subtitle: 'Collaborative writing projects',
            onTap: () => context.go('/writing-chains'),
          ),
          _buildDivider(),
          _buildFeatureItem(
            icon: Icons.forum_outlined,
            title: 'Whispr Wall',
            subtitle: 'Community discussions',
            onTap: () => context.go('/whispr-wall'),
          ),
          _buildDivider(),
          _buildFeatureItem(
            icon: Icons.audiotrack_outlined,
            title: 'Spoken Words',
            subtitle: 'Audio and video content',
            onTap: () => context.go('/spoken-words'),
          ),
          _buildDivider(),
          _buildFeatureItem(
            icon: Icons.smart_toy_outlined,
            title: 'AI Writing Lab',
            subtitle: 'Generate chronicles, poems, and writing chains',
            onTap: () => context.go('/ai-chat'),
          ),
          _buildDivider(),
          _buildFeatureItem(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'View all notifications',
            onTap: () => context.go('/notifications'),
          ),
          _buildDivider(),
          _buildFeatureItem(
            icon: Icons.badge_outlined,
            title: 'Public Portfolio',
            subtitle: 'Showcase your writing identity',
            onTap: () => context.go('/portfolio/${authState.user?.penName ?? 'me'}'),
          ),
          _buildDivider(),
          _buildFeatureItem(
            icon: Icons.sports_esports_outlined,
            title: 'Games',
            subtitle: 'Practice, improve and track streaks',
            onTap: () => context.go('/games'),
          ),
          _buildDivider(),
          _buildFeatureItem(
            icon: Icons.menu_book_outlined,
            title: 'Guides & Tutorials',
            subtitle: 'Learn poetry, blogging and more',
            onTap: () => context.go('/guides'),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildLegalItem(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => _launchUrl('https://whisprwords.vercel.app/privacy'),
          ),
          _buildDivider(),
          _buildLegalItem(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () => _launchUrl('https://whisprwords.vercel.app/terms'),
          ),
          _buildDivider(),
          _buildLegalItem(
            icon: Icons.info_outline,
            title: 'About Whispr',
            onTap: () => _launchUrl('https://whisprwords.vercel.app/about'),
          ),
          _buildDivider(),
          _buildLegalItem(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: _showHelpAndSupport,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.primaryColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.primaryColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildLegalItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.primaryColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.open_in_new, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
    );
  }

  Widget _buildAppInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.08),
            AppTheme.primaryColor.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // App Icon/Logo placeholder
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Image.asset(
                Theme.of(context).brightness == Brightness.dark
                    ? 'assets/images/lightlogo.png'
                    : 'assets/images/darklogo.png',
                fit: BoxFit.contain,
                width: 60,
                height: 60,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // App Name
          Text(
            'Whispr',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          // Version
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Tagline
          Text(
            'Share your thoughts, poems, and stories',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha((0.7 * 255).toInt()),
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          // Social Links
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSocialButton(
                icon: Icons.language,
                label: 'Website',
                onTap: () => _launchUrl('https://whisprwords.vercel.app'),
              ),
              const SizedBox(width: 16),
              _buildSocialButton(
                icon: Icons.mail_outline,
                label: 'Contact',
                onTap: () => _launchUrl('mailto:support@whispr.com'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

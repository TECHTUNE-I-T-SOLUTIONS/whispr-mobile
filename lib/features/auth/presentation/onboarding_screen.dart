import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../auth_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _items = [
    OnboardingItem(
      title: 'Welcome to Whispr',
      subtitle: 'Discover amazing stories and poems from talented writers around the world',
      icon: Icons.explore,
      description: 'Explore a vast collection of creative content, from heartwarming poems to captivating chronicles.',
    ),
    OnboardingItem(
      title: 'Share Your Voice',
      subtitle: 'Express yourself through writing and connect with a community of creators',
      icon: Icons.create,
      description: 'Join our community of writers and share your unique perspective with the world.',
    ),
    OnboardingItem(
      title: 'Engage & Connect',
      subtitle: 'Like, comment, and share content that resonates with you',
      icon: Icons.favorite,
      description: 'Build meaningful connections through engagement and discover content that speaks to your soul.',
    ),
    OnboardingItem(
      title: 'Premium Experience',
      subtitle: 'Unlock exclusive features and support your favorite creators',
      icon: Icons.star,
      description: 'Get access to premium content, advanced features, and help support the creative community.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() {
    if (_currentPage < _items.length - 1) {
      _pageController.nextPage(
        duration: AppTheme.mediumAnimation,
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() {
    // Always go to home screen first - users can browse without logging in
    // Clear any cached login state to ensure fresh start
    final authService = ref.read(authServiceProvider);
    authService.logout().then((_) {
      // Use addPostFrameCallback to ensure context is valid
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/home');
        }
      });
    }).catchError((_) {
      // Ignore logout errors during onboarding
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/home');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  return _buildPage(_items[index]);
                },
              ),
            ),

            // Page indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _items.length,
                (index) => AnimatedContainer(
                  duration: AppTheme.shortAnimation,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppTheme.primaryColor
                        : Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingL),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: AppTheme.mediumAnimation,
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    flex: _currentPage == 0 ? 1 : 2,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      child: Text(
                        _currentPage == _items.length - 1 ? 'Get Started' : 'Next',
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

  Widget _buildPage(OnboardingItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusXL),
            ),
            child: Icon(
              item.icon,
              size: 60,
              color: AppTheme.primaryColor,
            ),
          ),

          const SizedBox(height: AppTheme.spacingXXL),

          // Title
          Text(
            item.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.headlineMedium?.color,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppTheme.spacingM),

          // Subtitle
          Text(
            item.subtitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppTheme.spacingL),

          // Description
          Text(
            item.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class OnboardingItem {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;

  const OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
  });
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
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

  void _purchasePlan(String planName, String price) {
    // TODO: Implement payment integration
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Purchase of $planName plan ($price) - Coming soon!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: Column(
                    children: [
                      Icon(
                        Icons.star,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      Text(
                        'Unlock Premium Features',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        'Get access to exclusive content, advanced analytics, and premium writing tools.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spacingL),

              // Features
              Text(
                'Premium Features',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),

              _buildFeatureCard(
                icon: Icons.analytics,
                title: 'Advanced Analytics',
                description: 'Detailed insights into your writing performance and audience engagement.',
              ),

              _buildFeatureCard(
                icon: Icons.edit,
                title: 'Premium Writing Tools',
                description: 'Access to advanced writing chains, collaboration features, and AI assistance.',
              ),

              _buildFeatureCard(
                icon: Icons.verified,
                title: 'Verified Creator Badge',
                description: 'Get a verified badge on your profile and increased visibility.',
              ),

              _buildFeatureCard(
                icon: Icons.monetization_on,
                title: 'Monetization Features',
                description: 'Earn from your writing through tips, subscriptions, and ad revenue.',
              ),

              _buildFeatureCard(
                icon: Icons.priority_high,
                title: 'Priority Support',
                description: 'Get faster response times and dedicated support from our team.',
              ),

              const SizedBox(height: AppTheme.spacingL),

              // Pricing Plans
              Text(
                'Choose Your Plan',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),

              _buildPricingCard(
                title: 'Monthly',
                price: '\$4.99',
                period: 'per month',
                features: [
                  'All premium features',
                  'Advanced analytics',
                  'Priority support',
                  'Cancel anytime',
                ],
                isPopular: false,
                onPressed: () => _purchasePlan('Monthly', '\$4.99'),
              ),

              const SizedBox(height: AppTheme.spacingM),

              _buildPricingCard(
                title: 'Yearly',
                price: '\$49.99',
                period: 'per year',
                features: [
                  'All premium features',
                  'Advanced analytics',
                  'Priority support',
                  '2 months free',
                  'Cancel anytime',
                ],
                isPopular: true,
                onPressed: () => _purchasePlan('Yearly', '\$49.99'),
              ),

              const SizedBox(height: AppTheme.spacingL),

              // FAQ
              Text(
                'Frequently Asked Questions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),

              _buildFAQItem(
                question: 'Can I cancel my subscription anytime?',
                answer: 'Yes, you can cancel your subscription at any time. You\'ll continue to have access to premium features until the end of your billing period.',
              ),

              _buildFAQItem(
                question: 'What payment methods do you accept?',
                answer: 'We accept all major credit cards, PayPal, and other popular payment methods.',
              ),

              _buildFAQItem(
                question: 'Is there a free trial?',
                answer: 'Yes, we offer a 7-day free trial for new subscribers. No credit card required to start.',
              ),

              const SizedBox(height: AppTheme.spacingL),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Row(
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
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
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

  Widget _buildPricingCard({
    required String title,
    required String price,
    required String period,
    required List<String> features,
    required bool isPopular,
    required VoidCallback onPressed,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
        side: isPopular
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          children: [
            if (isPopular) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingS,
                  vertical: AppTheme.spacingXS,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                ),
                child: Text(
                  'Most Popular',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
            ],
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  price,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingXS),
                Text(
                  period,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            ...features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingXS),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Text(
                        feature,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: AppTheme.spacingM),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPopular
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.secondary,
                  foregroundColor: isPopular
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSecondary,
                ),
                child: Text(isPopular ? 'Start Free Trial' : 'Subscribe'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem({
    required String question,
    required String answer,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: ExpansionTile(
        title: Text(
          question,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Text(
              answer,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
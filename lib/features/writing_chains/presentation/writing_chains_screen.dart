import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/chronicles.dart';
import '../../../core/network/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/auth_state.dart';

class WritingChainsScreen extends ConsumerStatefulWidget {
  const WritingChainsScreen({super.key});

  @override
  ConsumerState<WritingChainsScreen> createState() => _WritingChainsScreenState();
}

class _WritingChainsScreenState extends ConsumerState<WritingChainsScreen> with TickerProviderStateMixin {
  List<WritingChain> _chains = [];
  bool _isLoading = false;  // Start as false to allow initial fetch
  String? _error;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _hasAttemptedFetch = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    // Don't fetch immediately - wait for auth state to be ready
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authState = ref.watch(authStateProvider);
    
    // Reset fetch flag if user logs out
    if (!authState.isAuthenticated && _hasAttemptedFetch) {
      _hasAttemptedFetch = false;
      _chains.clear();
      _error = null;
    }
  }

  Future<void> _fetchChains() async {
    final authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated) {
      if (mounted) {
        setState(() {
          _error = 'Please log in to view writing chains';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      if (mounted) setState(() => _isLoading = true);
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get('/chronicles/chains?limit=20');

      if (response['success'] == true) {
        final chains = (response['data'] as List)
            .map((json) => WritingChain.fromJson(json))
            .toList();
        if (mounted) {
          setState(() {
            _chains = chains;
            _isLoading = false;
          });
        }
      } else {
        throw Exception(response['error'] ?? 'Failed to load chains');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    // Fetch chains when auth state becomes ready and authenticated (only once)
    if (authState.isAuthenticated && !_isLoading && _chains.isEmpty && _error == null && !_hasAttemptedFetch) {
      _hasAttemptedFetch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchChains();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Writing Chains'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        actions: [
          if (authState.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                context.go('/writing-chains/create');
              },
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: authState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : authState.isAuthenticated
                ? _buildAuthenticatedView()
                : _buildUnauthenticatedView(),
      ),
      floatingActionButton: authState.isAuthenticated
          ? FloatingActionButton(
              onPressed: () {
                context.go('/writing-chains/create');
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildAuthenticatedView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: AppTheme.spacingM),
            ElevatedButton(
              onPressed: _fetchChains,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_chains.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.link_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'No writing chains yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'Create your first writing chain to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingL),
            ElevatedButton.icon(
              onPressed: () {
                context.go('/writing-chains/create');
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Chain'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchChains,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        itemCount: _chains.length,
        itemBuilder: (context, index) {
          final chain = _chains[index];
          return Card(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
            child: InkWell(
              onTap: () {
                context.go('/writing-chains/${chain.id}');
              },
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chain.title,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingS,
                            vertical: AppTheme.spacingXS,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                          ),
                          child: Text(
                            '${chain.entriesCount} entries',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (chain.description != null && chain.description!.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        chain.description!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      'Created ${chain.createdAtFormatted}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUnauthenticatedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.link_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'Sign in to view writing chains',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Join the community and start creating writing chains',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          ElevatedButton(
            onPressed: () => context.go('/login'),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}
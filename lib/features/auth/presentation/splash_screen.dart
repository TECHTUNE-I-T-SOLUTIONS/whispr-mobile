import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth_state.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  String _logoPath = 'assets/images/lightlogo.png';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadThemePreference();
    
    // Delay auth initialization until after the frame is built (Riverpod requirement)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndNavigate();
    });
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _animationController.forward();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final theme = prefs.getString('theme') ?? 'light';
      setState(() {
        _logoPath = theme == 'dark' ? 'assets/images/darklogo.png' : 'assets/images/lightlogo.png';
      });
    } catch (e) {
      // Default to light logo if there's an error
      setState(() {
        _logoPath = 'assets/images/lightlogo.png';
      });
    }
  }

  Future<void> _initializeAndNavigate() async {
    try {
      // Initialize auth state from local storage
      debugPrint('[SplashScreen] Starting auth initialization...');
      await ref.read(authStateProvider.notifier).initializeAuth();
      debugPrint('[SplashScreen] Auth initialization completed');
      
      // Wait for animations
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        final authState = ref.read(authStateProvider);
        
        debugPrint('[SplashScreen] Auth state after init: isLoggedIn=${authState.isLoggedIn}');
        
        // Check if user is authenticated after initialization
        if (authState.isLoggedIn && authState.user != null) {
          debugPrint('[SplashScreen] User authenticated, navigating to /home');
          context.go('/home');
        } else {
          debugPrint('[SplashScreen] User not authenticated, navigating to /onboarding');
          context.go('/onboarding');
        }
      }
    } catch (e) {
      debugPrint('[SplashScreen] Auth initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auth error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Image.asset(
              _logoPath,
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
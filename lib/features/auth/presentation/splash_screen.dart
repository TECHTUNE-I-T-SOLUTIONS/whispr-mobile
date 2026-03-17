import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/auth_guard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  String _logoPath = 'assets/images/lightlogo.png';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadThemePreference();
    _checkAuthAndNavigate();
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

  Future<void> _checkAuthAndNavigate() async {
    // Wait a bit for the splash to show
    await Future.delayed(const Duration(seconds: 2));

    final isLoggedIn = await AuthGuard.isLoggedIn();

    if (mounted) {
      if (isLoggedIn) {
        context.go('/home');
      } else {
        context.go('/onboarding');
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
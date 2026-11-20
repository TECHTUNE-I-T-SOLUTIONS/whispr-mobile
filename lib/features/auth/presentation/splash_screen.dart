import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/deep_link_service.dart';
import '../../../core/services/session_bootstrap.dart';
import '../auth_state.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  String _logoPath = 'assets/images/lightlogo.png';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadThemePreference();

    // Start after the frame is built (Riverpod requirement).
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
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final theme = prefs.getString('theme') ?? 'light';
      setState(() {
        _logoPath = theme == 'dark'
            ? 'assets/images/darklogo.png'
            : 'assets/images/lightlogo.png';
      });
    } catch (_) {
      setState(() {
        _logoPath = 'assets/images/lightlogo.png';
      });
    }
  }

  Future<void> _initializeAndNavigate() async {
    try {
      debugPrint('[SplashScreen] Waiting for the shared session bootstrap...');
      // SessionScope started this once. Awaiting it keeps the animation as the
      // first frame without restoring storage a second time.
      await ref.read(sessionBootstrapProvider.future);
      await _animationController.forward();
      debugPrint('[SplashScreen] Session bootstrap completed');

      if (!mounted) return;
      final authState = ref.read(authStateProvider);
      debugPrint(
          '[SplashScreen] Auth state: isLoggedIn=${authState.isLoggedIn}');

      // A cold-start link has been waiting and takes precedence over the
      // usual destination. The router still gates signed-in-only routes.
      DeepLinkService.instance.markAppReady();
      final deepLink = DeepLinkService.instance.takePendingRoute();
      if (deepLink != null) {
        debugPrint('[SplashScreen] Following link: $deepLink');
        context.go(deepLink);
      } else if (authState.isLoggedIn && authState.user != null) {
        context.go('/home');
      } else {
        context.go('/onboarding');
      }
    } catch (e) {
      // Bootstrap guards its own side effects, so this is a genuine failure.
      debugPrint('[SplashScreen] Bootstrap error: $e');
      if (mounted) context.go('/onboarding');
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

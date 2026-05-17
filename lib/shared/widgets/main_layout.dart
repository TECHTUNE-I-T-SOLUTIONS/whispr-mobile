import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  DateTime? _lastBackPress;
  late AnimationController _animationController;
  late List<Animation<double>> _iconAnimations;
  late final GoRouter _router;

  final List<String> _routes = [
    '/home',
    '/chronicles',
    '/whispr-wall',
    '/writing-chains',
    '/more',
  ];

  final List<String> _labels = [
    'Home',
    'Chronicles',
    'Whispr Wall',
    'Writing Chains',
    'More',
  ];

  final List<IconData> _icons = [
    Icons.home_outlined,
    Icons.book_outlined,
    Icons.forum_outlined,
    Icons.link_outlined,
    Icons.more_horiz_outlined,
  ];

  final List<IconData> _selectedIcons = [
    Icons.home,
    Icons.book,
    Icons.forum,
    Icons.link,
    Icons.more_horiz,
  ];

  @override
  void initState() {
    super.initState();
    _router = GoRouter.of(context);
    _animationController = AnimationController(
      duration: AppTheme.mediumAnimation,
      vsync: this,
    );

    _iconAnimations = List.generate(
      _icons.length,
      (index) => Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        ),
      ),
    );

    _updateSelectedIndexFromRoute();

    // Listen to route changes
    _router.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSelectedIndexFromRoute();
  }

  void _updateSelectedIndexFromRoute() {
    final location = _router.routerDelegate.currentConfiguration.uri.toString();
    final index = _routes.indexWhere((route) => location.startsWith(route));
    if (index != -1 && index != _selectedIndex) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _onRouteChanged() {
    _updateSelectedIndexFromRoute();
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_onRouteChanged);
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
      _animationController.forward(from: 0.0);
      context.go(_routes[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_router.canPop()) {
          context.pop();
          return;
        }
        if (_selectedIndex != 0) {
          _onItemTapped(0);
          return;
        }
        final now = DateTime.now();
        final shouldExit = _lastBackPress != null && now.difference(_lastBackPress!) < const Duration(seconds: 2);
        _lastBackPress = now;
        if (shouldExit) {
          context.go('/home');
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Press back again to exit')),
          );
        }
      },
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity.abs() < 200) return;
          if (velocity < 0 && _selectedIndex < _routes.length - 1) {
            _onItemTapped(_selectedIndex + 1);
          } else if (velocity > 0 && _selectedIndex > 0) {
            _onItemTapped(_selectedIndex - 1);
          }
        },
        child: Scaffold(
          body: widget.child,
          bottomNavigationBar: Container(
            height: 86,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        const Color(0xFF1A1A1A).withValues(alpha: 0.8),
                        const Color(0xFF2A2A2A).withValues(alpha: 0.6),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.8),
                        const Color(0xFFF8F9FA).withValues(alpha: 0.6),
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    _icons.length,
                    (index) => _buildNavItem(index),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppTheme.mediumAnimation,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: isDark
                      ? [
                          AppTheme.primaryColor.withValues(alpha: 0.3),
                          AppTheme.primaryColor.withValues(alpha: 0.1),
                        ]
                      : [
                          AppTheme.primaryColor.withValues(alpha: 0.2),
                          AppTheme.primaryColor.withValues(alpha: 0.05),
                        ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _iconAnimations[index],
              builder: (context, child) {
                return Transform.scale(
                  scale: isSelected ? _iconAnimations[index].value : 1.0,
                  child: Icon(
                    isSelected ? _selectedIcons[index] : _icons[index],
                    color: isSelected
                        ? AppTheme.primaryColor
                        : (isDark
                            ? Colors.white70
                            : Colors.black54),
                    size: isSelected ? 26 : 22,
                  ),
                );
              },
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: AppTheme.shortAnimation,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.primaryColor
                    : (isDark
                        ? Colors.white60
                        : Colors.black45),
                fontSize: isSelected ? 11 : 9,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
              child: Text(_labels[index]),
            ),
          ],
        ),
      ),
    );
  }
}

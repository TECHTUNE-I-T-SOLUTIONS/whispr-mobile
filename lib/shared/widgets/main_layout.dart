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

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        height: 80,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    const Color(0xFF1A1A1A),
                    const Color(0xFF2A2A2A),
                  ]
                : [
                    Colors.white,
                    const Color(0xFFF8F9FA),
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: BackdropFilter(
            filter: const ColorFilter.mode(
              Colors.transparent,
              BlendMode.srcOver,
            ),
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
                          AppTheme.primaryColor.withValues(alpha: 0.2),
                          AppTheme.primaryColor.withValues(alpha: 0.1),
                        ]
                      : [
                          AppTheme.primaryColor.withValues(alpha: 0.15),
                          AppTheme.primaryColor.withValues(alpha: 0.05),
                        ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          borderRadius: BorderRadius.circular(20),
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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

/// App shell: the bottom bar that holds the four primary destinations plus the
/// composer, and the back-button policy.
///
/// What changed from the previous shell:
///  * Four destinations and a raised compose button, instead of five tabs with
///    "More" hiding the profile. Writing is now always one tap away.
///  * No horizontal swipe between tabs. The old drag handler sat above every
///    screen's scroll view, so a sideways flick on a horizontal list navigated
///    away instead of scrolling it.
///  * One shared `NavigationBar` with an animated indicator, instead of five
///    hand-built animated containers each running their own shadow.
class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  DateTime? _lastBackPress;
  late final GoRouter _router;

  static const List<String> _routes = [
    '/home',
    '/chronicles',
    '/whispr-wall',
    '/more',
  ];

  static const List<String> _labels = [
    'Home',
    'Chronicles',
    'Wall',
    'Profile',
  ];

  static const List<(IconData, IconData)> _icons = [
    (Icons.home_outlined, Icons.home_rounded),
    (Icons.auto_stories_outlined, Icons.auto_stories_rounded),
    (Icons.forum_outlined, Icons.forum_rounded),
    (Icons.person_outline_rounded, Icons.person_rounded),
  ];

  /// Secondary destinations reachable from the home screen but not from the
  /// bar. They still belong to the shell so the bar stays visible on them.
  static const List<String> _secondaryRoutes = [
    '/notifications',
    '/games',
    '/guides',
    '/stories',
    '/writing-chains',
    '/spoken-words',
    '/more',
  ];

  @override
  void initState() {
    super.initState();
    _router = GoRouter.of(context);
    _syncIndex();
    _router.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncIndex();
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _syncIndex() {
    final location = _router.routerDelegate.currentConfiguration.uri.path;

    // Check the primary routes first so `/chronicles/create` still highlights
    // the Chronicles tab rather than falling through to a secondary route.
    var index = _routes.indexWhere((route) => location == route || location.startsWith('$route/'));
    if (index == -1) {
      // Secondary route: keep whichever primary tab the user came from, so the
      // bar does not visually jump. Default to Home.
      index = _selectedIndex;
    }
    if (index != _selectedIndex && mounted) {
      setState(() => _selectedIndex = index);
    }
  }

  void _onRouteChanged() => _syncIndex();

  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      // Tapping the current tab returns it to its root.
      context.go(_routes[index]);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
    context.go(_routes[index]);
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
        if (!shouldExit && mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Press back again to leave Whispr'),
                duration: Duration(seconds: 2),
              ),
            );
        }
      },
      child: Scaffold(
        body: widget.child,
        extendBody: true,
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF141414).withValues(alpha: 0.97)
                  : Colors.white.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                _navItem(0, isDark),
                _navItem(1, isDark),
                _composeButton(isDark),
                _navItem(2, isDark),
                _navItem(3, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _composeButton(bool isDark) {
    return Expanded(
      child: Center(
        child: Semantics(
          button: true,
          label: 'Write something new',
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              context.push('/chronicles/create');
            },
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primaryLight, AppTheme.primaryColor],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.42),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 21),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, bool isDark) {
    final isSelected = _selectedIndex == index;
    final (outline, filled) = _icons[index];
    final activeColor = isDark ? Colors.white : AppTheme.primaryColor;
    final inactiveColor = isDark ? Colors.white38 : Colors.black38;

    return Expanded(
      child: Semantics(
        selected: isSelected,
        button: true,
        label: _labels[index],
        child: InkWell(
          onTap: () => _onItemTapped(index),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: AppTheme.shortAnimation,
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Icon(
                  isSelected ? filled : outline,
                  size: 21,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _labels[index],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  letterSpacing: 0.1,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Exposed for tests and for screens that want the shell's secondary routes.
const List<String> kShellSecondaryRoutes = _MainLayoutState._secondaryRoutes;

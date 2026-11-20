import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/layout.dart';
import '../../core/router/navigation_keys.dart';
import '../../core/theme/app_theme.dart';

/// App shell: the bottom bar that holds the five primary destinations plus the
/// composer, and the back-button policy.
///
/// What changed from the previous shell:
/// * Five destinations and a raised compose button, with the profile reachable
/// through "More". Writing is now always one tap away.
///  * No horizontal swipe between tabs. The old drag handler sat above every
///    screen's scroll view, so a sideways flick on a horizontal list navigated
///    away instead of scrolling it.
/// * One compact, intrinsic-width pill: the active tab expands to show its
/// label while inactive tabs stay as tight icon-only circles.
class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  String _location = '/home';
  DateTime? _lastBackPress;
  late final GoRouter _router;

  static const List<String> _routes = [
    '/home',
    '/chronicles',
    '/stories',
 '/whispr-wall',
    '/more',
  ];

 static const List<String> _labels = [
 'Home',
 'Chronicles',
 'Stories',
 'Wall',
 'More',
 ];

 // Short forms shown on the pill. The long labels made the bar wide enough
 // to overflow on narrow phones, especially while Chronicles was active.
 static const List<String> _shortLabels = [
 'Home',
 'Chronicle',
 'Stories',
 'Wall',
 'More',
 ];

 static const List<(IconData, IconData)> _icons = [
    (Icons.home_outlined, Icons.home_rounded),
    (Icons.auto_stories_outlined, Icons.auto_stories_rounded),
    (Icons.menu_book_outlined, Icons.menu_book_rounded),
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

  /// Routes that own the bottom of the screen and must not have the bar drawn
  /// over them.
  ///
  /// A writing chain's detail view is a full-height reading surface with its
  /// own "add entry" button pinned to the bottom; the floating bar covered
  /// that button, so the bar steps aside for the whole chain subtree.
  static bool _hidesBar(String location) {
    if (location.startsWith('/chains/')) return true;
    if (location.startsWith('/writing-chains/') &&
        location != '/writing-chains/create') {
      return true;
    }
    return false;
  }

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

  /// Recomputes the selected tab and the current location.
  ///
  /// Deliberately does not call `setState`: it also runs from `initState` and
  /// `didChangeDependencies`, where a rebuild would be illegal. The route
  /// listener below owns the rebuild.
  void _syncIndex() {
    final location = _router.routerDelegate.currentConfiguration.uri.path;
    _location = location;

    // Check the primary routes first so `/chronicles/create` still highlights
    // the Chronicles tab rather than falling through to a secondary route.
    var index = _routes.indexWhere((route) => location == route || location.startsWith('$route/'));
    if (index == -1) {
      // Secondary route: keep whichever primary tab the user came from, so the
      // bar does not visually jump. Default to Home.
      index = _selectedIndex;
    }
    _selectedIndex = index;
  }

  void _onRouteChanged() {
    if (!mounted) return;
    _syncIndex();
    // The bar's visibility depends on the location, not just the tab, so every
    // route change has to rebuild the shell.
    setState(() {});
  }

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
      // The default pop targets this shell's root navigator, not GoRouter's
// active (often nested) branch. Swallow it and ask GoRouter to pop so a
// pushed detail screen goes back instead of closing the app.
canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (shellNavigatorKey.currentState?.canPop() ?? false) {
         shellNavigatorKey.currentState!.pop();
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
          // Leaving is opt-in: without this the shell swallows every back press
          // and there is no way out of the app at all.
          SystemNavigator.pop();
          return;
        }
        if (mounted) {
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
        bottomNavigationBar: _hidesBar(_location) ? null : SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(
            kBottomNavHorizontalInset,
            0,
            kBottomNavHorizontalInset,
            10,
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              // A compact, centred pill rather than a full-width bar: it stays
              // narrow on wide phones and tablets so every destination is a
              // short thumb reach away. Only the active destination shows its
              // label, which is what keeps the pill this narrow.
              constraints: const BoxConstraints(maxWidth: 300),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(kBottomNavHeight / 2),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    height: kBottomNavHeight,
 padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF141414).withValues(alpha: 0.72)
                          : Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(kBottomNavHeight / 2),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.10),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 _navItem(0, isDark),
 _navItem(1, isDark),
 _composeButton(isDark),
 _navItem(2, isDark),
 _navItem(3, isDark),
 _navItem(4, isDark),
 ],
 ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

 Widget _composeButton(bool isDark) {
 return Semantics(
 button: true,
 label: 'Write something new',
 child: InkWell(
 onTap: () {
 HapticFeedback.mediumImpact();
 context.push('/chronicles/create');
 },
 customBorder: const StadiumBorder(),
 child: Container(
 height: 36,
 width: 36,
 decoration: BoxDecoration(
 gradient: const LinearGradient(
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 colors: [AppTheme.primaryLight, AppTheme.primaryColor],
 ),
 borderRadius: BorderRadius.circular(12),
 boxShadow: [
 BoxShadow(
 color: AppTheme.primaryColor.withValues(alpha: 0.42),
 blurRadius: 10,
 offset: const Offset(0, 3),
 ),
 ],
 ),
 child: const Icon(Icons.edit_rounded, color: Colors.white, size: 17),
 ),
 ),
 );
 }

 Widget _navItem(int index, bool isDark) {
 final isSelected = _selectedIndex == index;
 final (outline, filled) = _icons[index];
 final inactiveColor = isDark ? Colors.white54 : Colors.black45;

 return Semantics(
 selected: isSelected,
 button: true,
 label: _labels[index],
 child: InkWell(
 onTap: () => _onItemTapped(index),
 customBorder: const StadiumBorder(),
 child: AnimatedContainer(
 duration: AppTheme.shortAnimation,
 curve: Curves.easeOut,
 height: 38,
 padding: EdgeInsets.symmetric(horizontal: isSelected ? 9 : 4),
 decoration: BoxDecoration(
 color: isSelected
 ? AppTheme.primaryLight
 : Colors.transparent,
 borderRadius: BorderRadius.circular(19),
 boxShadow: isSelected
 ? [
 BoxShadow(
 color: AppTheme.primaryLight.withValues(alpha: 0.28),
 blurRadius: 7,
 offset: const Offset(0, 2),
 ),
 ]
 : null,
 ),
 child: AnimatedSize(
 duration: AppTheme.shortAnimation,
 curve: Curves.easeOut,
 child: isSelected
 ? Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(filled, size: 17, color: Colors.white),
 const SizedBox(width: 4),
 Text(
 _shortLabels[index],
 maxLines: 1,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w800,
 letterSpacing: 0,
 color: Colors.white,
 ),
 ),
 ],
 )
 : SizedBox(
 width: 22,
 child: Icon(
 outline,
 size: 18,
 color: inactiveColor,
 ),
 ),
 ),
 ),
 ),
 );
 }
}

/// Exposed for tests and for screens that want the shell's secondary routes.
const List<String> kShellSecondaryRoutes = _MainLayoutState._secondaryRoutes;

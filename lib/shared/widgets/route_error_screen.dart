import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'back_guard.dart';

/// Shown instead of go_router's default error page.
///
/// The default page is a developer-facing "page not found" with a back button
/// that leads nowhere useful — a shared link that did not resolve dropped the
/// user there. This one explains nothing technical, always has a way home, and
/// participates in the back-button policy so the system back button returns to
/// the app rather than closing it.
class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({super.key, this.location});

  /// The location that failed to resolve, used only for logging.
  final String? location;

  @override
  Widget build(BuildContext context) {
    debugPrint('[Router] no route for ${location ?? '(unknown)'}');

    return BackGuard(
      child: Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.link_off_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  'That link is not available',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'It may have been moved or removed, or the app version you '
                  'have does not support it yet.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 26),
                FilledButton.tonal(
                  onPressed: () => context.go('/home'),
                  child: const Text('Go home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

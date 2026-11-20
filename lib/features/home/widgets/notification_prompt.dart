import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/push_notification_service.dart';
import '../../../core/services/live_update_service.dart';
import '../../../core/theme/app_theme.dart';

/// Asks for notification permission at the moment it is useful.
///
/// The old build never called `initialize()` or requested permission at all,
/// so notifications simply could not reach anyone. Asking cold at first launch
/// is the fastest way to get a permanent denial, so this card is shown once the
/// user has already seen the home screen, and it explains the value first.
class NotificationPrompt extends StatefulWidget {
  const NotificationPrompt({super.key});

  @override
  State<NotificationPrompt> createState() => _NotificationPromptState();
}

class _NotificationPromptState extends State<NotificationPrompt> {
  static const _promptShownKey = 'whispr_notification_prompt_shown';
  static const _reminderTimeKey = 'whispr_daily_reminder_hour';

  bool _visible = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _decideVisibility();
  }

  Future<void> _decideVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool(_promptShownKey) ?? false;
    final enabled = prefs.getBool('push_notifications_enabled') ?? false;
    if (!mounted || alreadyAsked || enabled) return;
    // A beat after the first paint, so the home screen lands before this slides in.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _visible = true);
  }

  Future<void> _dismiss({required bool enable}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptShownKey, true);

    if (enable) {
      setState(() => _busy = true);
      final granted = await PushNotificationService().requestPermission();
      if (granted) {
        final hour = prefs.getInt(_reminderTimeKey) ?? 8;
        await PushNotificationService().scheduleDailyChallengeReminder(hour: hour);
 // Permission just changed; republish the widget and live notification now.
 unawaited(LiveUpdateService.instance.refresh());
      }
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? 'Daily reminders on. We will nudge you at ${prefs.getInt(_reminderTimeKey) ?? 8}:00.'
                : 'Notifications are off. You can turn them on any time from Profile.',
          ),
        ),
      );
    }

    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: AppTheme.mediumAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161616) : const Color(0xFFF7F4F2),
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.notifications_active_outlined, size: 18, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Get a nudge when the daily prompt goes live',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.3),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'One reminder a day at 8am. No noise, and you can turn it off any time.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _busy ? null : () => _dismiss(enable: true),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          minimumSize: const Size(0, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Turn on'),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: _busy ? null : () => _dismiss(enable: false),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Not now'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _busy ? null : () => _dismiss(enable: false),
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

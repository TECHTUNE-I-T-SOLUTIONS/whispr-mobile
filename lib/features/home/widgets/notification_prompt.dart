import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/push_notification_service.dart';
import '../../../core/services/live_update_service.dart';
import '../../../core/theme/app_theme.dart';

/// A slim, one-line permission prompt. It sits between the daily prompt and
/// the tabs, so it never competes with the reading list for attention.
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
        await PushNotificationService().scheduleDailyChallengeReminder(
          hour: hour,
        );
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
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;

    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: AppTheme.mediumAnimation,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161414) : const Color(0xFFF7F4F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.notifications_none_rounded, size: 18, color: primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Get a daily nudge',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'One reminder at 8am. Change it in Profile.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: secondary),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _busy ? null : () => _dismiss(enable: true),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Turn on'),
            ),
            TextButton(
              onPressed: _busy ? null : () => _dismiss(enable: false),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: secondary,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Not now'),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _busy ? null : () => _dismiss(enable: false),
              icon: Icon(
                Icons.close_rounded,
                size: 16,
                color: secondary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

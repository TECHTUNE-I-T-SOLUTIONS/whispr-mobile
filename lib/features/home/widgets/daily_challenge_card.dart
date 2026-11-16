import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/daily_challenge_service.dart';
import '../../../core/theme/app_theme.dart';

/// Today's writing challenge — the first thing on the home screen.
///
/// Shows the streak, the prompt and one clear action. When the challenge is
/// already done it becomes a quiet "you're done today" card instead of
/// disappearing, so the streak stays visible.
class DailyChallengeCard extends StatefulWidget {
  final DailyChallengeState state;
  final VoidCallback onEnter;
  final Future<void> Function() onRefresh;

  const DailyChallengeCard({
    super.key,
    required this.state,
    required this.onEnter,
    required this.onRefresh,
  });

  @override
  State<DailyChallengeCard> createState() => _DailyChallengeCardState();
}

class _DailyChallengeCardState extends State<DailyChallengeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = widget.state;
    final done = s.completedToday;

    return AnimatedContainer(
      duration: AppTheme.mediumAnimation,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusXL),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: done
              ? [
                  (isDark ? const Color(0xFF1B2A1D) : const Color(0xFFEAF5EB)),
                  (isDark ? const Color(0xFF121914) : Colors.white),
                ]
              : isDark
                  ? [const Color(0xFF2A0F10), const Color(0xFF120A0A)]
                  : [AppTheme.primaryColor, const Color(0xFF5E0E0F)],
        ),
        border: Border.all(
          color: done
              ? const Color(0xFF3E7A44).withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.14),
        ),
        boxShadow: [
          if (!done)
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.28 : 0.32),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusXL),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _streakChip(s.currentStreak, done, isDark),
                    const Spacer(),
                    _metaChip(s.challenge.form, done),
                    const SizedBox(width: 6),
                    Icon(
                      _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 20,
                      color: done ? (isDark ? Colors.white38 : Colors.black38) : Colors.white54,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  done ? 'Done for today' : "Today's whisper",
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                    color: done
                        ? (isDark ? Colors.white54 : Colors.black45)
                        : Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.challenge.prompt,
                  maxLines: _expanded ? null : 3,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: _expanded ? 19 : 18,
                    height: 1.42,
                    fontWeight: FontWeight.w600,
                    color: done ? (isDark ? Colors.white70 : Colors.black87) : Colors.white,
                  ),
                ),
                if (_expanded) ...[
                  const SizedBox(height: 14),
                  _detailRow('Kicker', s.challenge.kicker, done, isDark),
                  _detailRow('Length', '${s.challenge.wordTarget} words', done, isDark),
                  _detailRow('Reward', '+${s.challenge.xp} XP', done, isDark),
                  if (s.lastEntryPreview != null && done) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                      ),
                      child: Text(
                        '“${s.lastEntryPreview}”',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                          height: 1.45,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.onEnter();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: done ? (isDark ? Colors.white12 : Colors.black) : Colors.white,
                          foregroundColor: done ? (isDark ? Colors.white : Colors.white) : AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        child: Text(done ? 'Write another' : 'Start writing'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: widget.onRefresh,
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: done ? (isDark ? Colors.white38 : Colors.black38) : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _streakChip(int streak, bool done, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: done
            ? const Color(0xFF3E7A44).withValues(alpha: isDark ? 0.24 : 0.12)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: done
              ? const Color(0xFF3E7A44).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            streak > 0 ? Icons.local_fire_department_rounded : Icons.local_fire_department_outlined,
            size: 15,
            color: streak > 0
                ? (done ? const Color(0xFF6FCF7C) : const Color(0xFFFFB74D))
                : (done ? (isDark ? Colors.white38 : Colors.black38) : Colors.white60),
          ),
          const SizedBox(width: 5),
          Text(
            streak > 0 ? '$streak day${streak == 1 ? '' : 's'}' : 'Start your streak',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: done ? (isDark ? Colors.white70 : Colors.black87) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(String label, bool done) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: done
            ? (Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05))
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: done
              ? (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54)
              : Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, bool done, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.4,
                color: done ? (isDark ? Colors.white38 : Colors.black38) : Colors.white54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: done ? (isDark ? Colors.white70 : Colors.black87) : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small streak strip shown above the challenge when a streak exists.
class StreakStrip extends StatelessWidget {
  final int current;
  final int best;

  const StreakStrip({super.key, required this.current, required this.best});

  @override
  Widget build(BuildContext context) {
    if (current == 0 && best == 0) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            current > 0 ? '$current-day streak' : 'Best streak: $best',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => context.go('/games'),
            icon: const Icon(Icons.emoji_events_outlined, size: 15),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            label: const Text('Games', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

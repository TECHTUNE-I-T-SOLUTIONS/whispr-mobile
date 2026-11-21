import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/daily_challenge_service.dart';
import '../../../core/theme/app_theme.dart';

/// Today's writing prompt — the one deliberate focal point on the home screen.
///
/// Collapsed, it is a compact card with the streak, the prompt and one action.
/// Expanding reveals the brief and the last entry without pushing the rest of
/// the home screen into a second full page of decoration.
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
    final background = done
        ? (isDark ? const Color(0xFF142017) : const Color(0xFFF0F6F0))
        : (isDark ? const Color(0xFF261113) : AppTheme.primaryColor);
    final foreground = done
        ? (isDark ? Colors.white : const Color(0xFF151212))
        : Colors.white;
    final muted = done
        ? (isDark ? Colors.white60 : Colors.black54)
        : Colors.white.withValues(alpha: 0.74);

    final imageUrl = s.challenge.imageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return AnimatedContainer(
      duration: AppTheme.mediumAnimation,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
        border: done
            ? Border.all(
                color: const Color(
                  0xFF3E7A44,
                ).withValues(alpha: isDark ? 0.4 : 0.22),
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_expanded && hasImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      height: 132,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    _streakChip(s.currentStreak, done, isDark),
                    const Spacer(),
                    _metaChip(s.challenge.form, done, isDark),
                    const SizedBox(width: 2),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: muted,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  done ? 'Done for today' : "Today's whisper",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.challenge.prompt,
                  maxLines: _expanded ? null : 3,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.serifFamily,
                    fontSize: 19,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
                if (_expanded) ...[
                  const SizedBox(height: 14),
                  _detailRow('Kicker', s.challenge.kicker, done, isDark),
                  _detailRow(
                    'Length',
                    '${s.challenge.wordTarget} words',
                    done,
                    isDark,
                  ),
                  _detailRow('Reward', '+${s.challenge.xp} XP', done, isDark),
                  if (s.lastEntryPreview != null && done) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: done
                            ? (isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.04))
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '“${s.lastEntryPreview}”',
                        style: TextStyle(
                          fontFamily: AppTheme.serifFamily,
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                          height: 1.45,
                          color: muted,
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.onEnter();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(done ? 'Write another' : 'Start writing'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        tooltip: 'Refresh',
                        onPressed: widget.onRefresh,
                        icon: Icon(
                          Icons.refresh_rounded,
                          size: 19,
                          color: muted,
                        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: done
            ? const Color(0xFF3E7A44).withValues(alpha: isDark ? 0.24 : 0.1)
            : Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            streak > 0
                ? Icons.local_fire_department_rounded
                : Icons.local_fire_department_outlined,
            size: 14,
            color: streak > 0
                ? (done ? const Color(0xFF3E7A44) : const Color(0xFFFFCC80))
                : (done ? Colors.black38 : Colors.white70),
          ),
          const SizedBox(width: 5),
          Text(
            streak > 0
                ? '$streak day${streak == 1 ? '' : 's'}'
                : 'Start your streak',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: done
                  ? (isDark ? Colors.white70 : const Color(0xFF2F5E34))
                  : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(String label, bool done, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: done
            ? (isDark
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
          color: done
              ? (isDark ? Colors.white60 : Colors.black54)
              : Colors.white.withValues(alpha: 0.9),
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
            width: 66,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: done
                    ? (isDark ? Colors.white38 : Colors.black38)
                    : Colors.white54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: done
                    ? (isDark ? Colors.white70 : Colors.black87)
                    : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A teaser of long-form content that fades out and offers "Read more".
///
/// The mobile app used to print a raw `excerpt` truncated mid-word, or
/// nothing at all when no excerpt existed. This clamps the text on a word
/// boundary, fades the last line, and makes the whole block a single obvious
/// tap target. It is a presentation component only — the full post is one tap
/// away on the detail screen.
class GatedPreview extends StatelessWidget {
  final String? text;
  final String fallback;
  final int maxCharacters;
  final VoidCallback? onTap;

  const GatedPreview({
    super.key,
    required this.text,
    required this.fallback,
    this.maxCharacters = 160,
    this.onTap,
  });

  /// Word-safe clamp so previews never end mid-word or mid-sentence.
  static String clamp(String? input, int max, {String fallback = ''}) {
    final clean = (input ?? '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'[#*_>`]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.isEmpty) return fallback;
    if (clean.length <= max) return clean;
    final cut = clean.substring(0, max);
    final lastSpace = cut.lastIndexOf(' ');
    final body = lastSpace > max * 0.6 ? cut.substring(0, lastSpace) : cut;
    return '${body.replaceAll(RegExp(r'[.,;:\-–—]+$'), '')}…';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final body = clamp(text, maxCharacters, fallback: fallback);
    final isTruncated = body.endsWith('…');

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black,
                Colors.black,
                isTruncated ? Colors.black26 : Colors.black,
              ],
              stops: const [0.0, 0.7, 1.0],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: Text(
              body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 14.5,
                height: 1.55,
                color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.72),
              ),
            ),
          ),
          if (isTruncated) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Read more',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Row of engagement stats with consistent icon sizing.
class PostStatsRow extends StatelessWidget {
  final int? reads;
  final int? likes;
  final int? comments;
  final int? minutes;

  const PostStatsRow({
    super.key,
    this.reads,
    this.likes,
    this.comments,
    this.minutes,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38;
    final items = <Widget>[];

    void add(IconData icon, int? value) {
      if (value == null || value == 0) return;
      items.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(value.toString(), style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ));
      items.add(const SizedBox(width: 14));
    }

    add(Icons.visibility_outlined, reads);
    add(Icons.favorite_border_rounded, likes);
    add(Icons.chat_bubble_outline_rounded, comments);
    if (minutes != null && minutes! > 0) {
      items.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text('$minutes min', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();
    if (items.last is SizedBox) items.removeLast();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(spacing: 0, crossAxisAlignment: WrapCrossAlignment.center, children: items),
    );
  }
}

/// Section shell used across the mobile home screen.
class MobileSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MobileSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: Theme.of(context).colorScheme.primary,
                textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Filled card used for list rows on the home screen.
class MobileCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const MobileCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

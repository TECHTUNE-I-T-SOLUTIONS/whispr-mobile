import 'package:flutter/material.dart';

/// How a piece of content is labelled in the UI.
///
/// Whispr publishes its own poems and essays alongside creator work. Readers
/// should be able to tell the two apart at a glance, but the distinction is
/// presented as **Whispr Editions** versus the creator's name — never as
/// "admin", "staff" or "official". The house voice is just another byline.
enum ContentOrigin {
  /// Written and published by Whispr itself.
  whispr,

  /// Written by a Chronicles creator.
  creator;

  static ContentOrigin fromSource(String? source) {
    final value = (source ?? '').toLowerCase();
    // The feed marks house content as 'admin'; chronicles endpoints mark
    // creator work as 'creator'/'user'. Anything unrecognised is treated as
    // creator content, because mislabelling a creator's work as house work
    // would be the worse error.
    if (value == 'admin' || value == 'whispr' || value == 'house' || value == 'editorial') {
      return ContentOrigin.whispr;
    }
    return ContentOrigin.creator;
  }
}

/// Display metadata for a piece of content: what it is and where it came from.
class ContentBadge {
  final ContentOrigin origin;

  /// 'poem', 'blog', 'chronicle', 'story'.
  final String format;

  /// The creator's pen name. Null for Whispr content.
  final String? creatorName;

  const ContentBadge({
    required this.origin,
    required this.format,
    this.creatorName,
  });

  factory ContentBadge.of({
    required String? source,
    required String? type,
    String? creatorName,
  }) {
    return ContentBadge(
      origin: ContentOrigin.fromSource(source),
      format: (type ?? 'poem').toLowerCase(),
      creatorName: creatorName,
    );
  }

  /// "Whispr Edition" / "Chronicle" / "Poem" — the label shown on a card.
  String get editionLabel => origin == ContentOrigin.whispr ? 'Whispr Edition' : _formatLabel;

  String get _formatLabel {
    switch (format) {
      case 'blog':
        return 'Essay';
      case 'chronicle':
        return 'Chronicle';
      case 'story':
        return 'Story';
      case 'chain':
        return 'Chain entry';
      case 'poem':
      default:
        return 'Poem';
    }
  }

  /// By-line: the creator's name, or the house name.
  String get byline =>
      origin == ContentOrigin.whispr ? 'Whispr' : (creatorName?.trim().isNotEmpty == true ? creatorName!.trim() : 'A Whispr creator');

  /// Tint used for the badge. House content reads warm and steady; creator
  /// content takes the accent so a reader can scan the difference.
  Color tint(Brightness brightness) {
    if (origin == ContentOrigin.whispr) {
      return brightness == Brightness.dark ? const Color(0xFFD9B26A) : const Color(0xFF8A6A2F);
    }
    return brightness == Brightness.dark ? const Color(0xFFCF5A5B) : const Color(0xFF911A1B);
  }

  IconData get icon {
    if (origin == ContentOrigin.whispr) return Icons.auto_awesome_outlined;
    switch (format) {
      case 'blog':
        return Icons.notes_rounded;
      case 'chronicle':
        return Icons.auto_stories_outlined;
      case 'story':
        return Icons.menu_book_outlined;
      case 'chain':
        return Icons.link_rounded;
      default:
        return Icons.format_quote_rounded;
    }
  }
}

/// The pill shown on cards and headers.
class ContentBadgeChip extends StatelessWidget {
  final ContentBadge badge;
  final bool compact;

  const ContentBadgeChip({super.key, required this.badge, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = badge.tint(brightness);
    final isHouse = badge.origin == ContentOrigin.whispr;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: brightness == Brightness.dark ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badge.icon, size: compact ? 10 : 11, color: color),
          const SizedBox(width: 4),
          Text(
            badge.editionLabel,
            style: TextStyle(
              fontSize: compact ? 9.5 : 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
          if (isHouse && !compact) ...[
            const SizedBox(width: 4),
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.6), shape: BoxShape.circle),
            ),
          ],
        ],
      ),
    );
  }
}

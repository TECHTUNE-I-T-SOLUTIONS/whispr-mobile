import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_service.dart';

/// One day's writing prompt.
class DailyChallenge {
  final String id;
  final String prompt;
  final String kicker;
  final String form;
  final int wordTarget;
  final int xp;

  /// Server id of today's prompt, when it came from the daily challenge the
  /// cron job creates. Null for the local fallback prompt.
  final String? remoteId;
  final String? description;
  final String? imageUrl;
  final String? prizeDescription;
  final bool isRemote;

  const DailyChallenge({
    required this.id,
    required this.prompt,
    required this.kicker,
    required this.form,
    required this.wordTarget,
    required this.xp,
    this.remoteId,
    this.description,
    this.imageUrl,
    this.prizeDescription,
    this.isRemote = false,
  });
}

/// The user's progress against today's challenge and their streak.
class DailyChallengeState {
  final DailyChallenge challenge;
  final bool completedToday;
  final int currentStreak;
  final int bestStreak;
  final int totalCompleted;
  final String? lastEntryPreview;

  const DailyChallengeState({
    required this.challenge,
    required this.completedToday,
    required this.currentStreak,
    required this.bestStreak,
    required this.totalCompleted,
    this.lastEntryPreview,
  });

  DailyChallengeState copyWith({
    bool? completedToday,
    int? currentStreak,
    int? bestStreak,
    int? totalCompleted,
    String? lastEntryPreview,
  }) {
    return DailyChallengeState(
      challenge: challenge,
      completedToday: completedToday ?? this.completedToday,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      totalCompleted: totalCompleted ?? this.totalCompleted,
      lastEntryPreview: lastEntryPreview ?? this.lastEntryPreview,
    );
  }
}

/// Daily writing challenge, tracked on-device.
///
/// Prompts are chosen deterministically from the calendar day, so every install
/// sees the same challenge on the same date and the streak survives a reinstall
/// the moment the profile is restored. Completion is stored locally now; when
/// the server grows a `daily_challenges` table this class is the only file that
/// changes.
class DailyChallengeService {
  DailyChallengeService._();
  static final DailyChallengeService instance = DailyChallengeService._();

  static const _completedDatesKey = 'daily_challenge_completed_dates';
  static const _bestStreakKey = 'daily_challenge_best_streak';
  static const _lastPreviewKey = 'daily_challenge_last_preview';

  /// 30 prompts — a month of material, indexed by day-of-year so a prompt
  /// repeats only once a month rather than every week.
  static const List<({String kicker, String prompt, String form, int words})> _prompts = [
    (kicker: 'First light', prompt: 'Write about a morning that arrived too early to be forgiven.', form: 'Free verse', words: 60),
    (kicker: 'Small mercy', prompt: 'Describe something that saved you and never knew it did.', form: 'Free verse', words: 60),
    (kicker: 'The unsent', prompt: 'Write the message you never sent. Keep the name out of it.', form: 'Prose poem', words: 80),
    (kicker: 'Weather inside', prompt: 'Invent a weather that only happens in a person. Show it happening.', form: 'Free verse', words: 70),
    (kicker: 'One object', prompt: 'Describe a room entirely through the objects someone left behind.', form: 'Prose poem', words: 80),
    (kicker: 'After the call', prompt: 'Start mid-conversation, end after the phone goes dark.', form: 'Flash fiction', words: 100),
    (kicker: 'Repetition', prompt: 'Use the same line three times. Change what it means each time.', form: 'Free verse', words: 60),
    (kicker: 'Stranger kindness', prompt: 'A stranger does one small thing. That is the whole story.', form: 'Micro fiction', words: 50),
    (kicker: 'The lie', prompt: 'Write a love poem with one lie in it. Do not tell us which.', form: 'Free verse', words: 70),
    (kicker: 'Letters home', prompt: 'Write home from a place you have never been.', form: 'Epistolary', words: 90),
    (kicker: 'Body as map', prompt: 'Write about a body that has been a place, not a person.', form: 'Free verse', words: 70),
    (kicker: 'Thirteen words', prompt: 'Tell a whole betrayal in exactly thirteen words.', form: 'Flash', words: 13),
    (kicker: 'The asking', prompt: 'Someone is about to ask a question they will regret. Stop before they do.', form: 'Micro fiction', words: 50),
    (kicker: 'Interior', prompt: 'Describe a feeling using only what is in the room.', form: 'Free verse', words: 60),
    (kicker: 'Two of us', prompt: 'Write a poem where "we" is doing all the work and "I" is barely there.', form: 'Free verse', words: 70),
    (kicker: 'Fire drill', prompt: 'Everyone knew it was a drill. Something still went wrong.', form: 'Flash fiction', words: 100),
    (kicker: 'Tide', prompt: 'Write about leaving that sounds like a tide going out.', form: 'Free verse', words: 60),
    (kicker: 'The list', prompt: 'A list someone made that reveals what they were afraid of.', form: 'Form poetry', words: 50),
    (kicker: 'Heirloom', prompt: 'Describe an object no one in the family wants to say the truth about.', form: 'Prose poem', words: 80),
    (kicker: 'Night shift', prompt: 'Write from the point of view of a building that is always awake.', form: 'Free verse', words: 70),
    (kicker: 'The explanation', prompt: 'Explain a wound without ever naming the person who caused it.', form: 'Free verse', words: 60),
    (kicker: 'Before the lens', prompt: 'Someone is being photographed and knows it. Write the moment.', form: 'Micro fiction', words: 50),
    (kicker: 'Redaction', prompt: 'Write a poem with a hole in it. The hole is the point.', form: 'Free verse', words: 60),
    (kicker: 'Distance', prompt: 'Two people in the same room, communicating across a distance you invent.', form: 'Prose poem', words: 80),
    (kicker: 'Rite', prompt: 'Describe a ritual no one remembers starting.', form: 'Free verse', words: 70),
    (kicker: 'Last bus', prompt: 'Everything happens on the last bus. Make us miss it too.', form: 'Flash fiction', words: 100),
    (kicker: 'Grief', prompt: 'Write about grief as something domestic.', form: 'Free verse', words: 60),
    (kicker: "In my father's", prompt: 'Write a poem that never leaves one house.', form: 'Free verse', words: 70),
    (kicker: 'Permission', prompt: 'Write the thing you have been giving everyone else permission to write.', form: 'Free verse', words: 70),
    (kicker: 'Weather again', prompt: 'End on a season, but not in a way we expect.', form: 'Free verse', words: 60),
  ];

  /// Today's challenge, resolved from the local date so it flips at midnight.
  DailyChallenge challengeFor(DateTime date) {
    final dayOfYear = DateTime(date.year, date.month, date.day)
        .difference(DateTime(date.year, 1, 1))
        .inDays;
    final p = _prompts[dayOfYear % _prompts.length];
    return DailyChallenge(
      id: _dateKey(date),
      prompt: p.prompt,
      kicker: p.kicker,
      form: p.form,
      wordTarget: p.words,
      xp: 10 + (p.words ~/ 20) * 5,
    );
  }

  Future<DailyChallengeState> load({DateTime? now}) async {
    final today = now ?? DateTime.now();
    // Prefer the live challenge the cron job publishes for today, so the app
    // shows the same prompt as the web. Fall back to the bundled prompt when
    // the device is offline or no active daily challenge exists.
    final remote = await _fetchTodayFromServer(today);
    final challenge = remote ?? challengeFor(today);
    final prefs = await SharedPreferences.getInstance();

    final completed = prefs.getStringList(_completedDatesKey) ?? const [];
    final completedToday = completed.contains(challenge.id);

    return DailyChallengeState(
      challenge: challenge,
      completedToday: completedToday,
      currentStreak: _streakFrom(completed, today),
      bestStreak: prefs.getInt(_bestStreakKey) ?? 0,
      totalCompleted: completed.length,
      lastEntryPreview: prefs.getString(_lastPreviewKey),
    );
  }

  /// Marks today done and returns the refreshed state (so the card flips
  /// without a round trip to the database).
  Future<DailyChallengeState> completeToday({String? entryPreview, DateTime? now}) async {
    final today = now ?? DateTime.now();
    final challenge = challengeFor(today);
    final prefs = await SharedPreferences.getInstance();

    final completed = prefs.getStringList(_completedDatesKey) ?? <String>[];
    if (!completed.contains(challenge.id)) {
      completed.add(challenge.id);
      await prefs.setStringList(_completedDatesKey, completed);
    }

    final streak = _streakFrom(completed, today);
    final best = prefs.getInt(_bestStreakKey) ?? 0;
    if (streak > best) await prefs.setInt(_bestStreakKey, streak);

    if (entryPreview != null && entryPreview.trim().isNotEmpty) {
      final preview = entryPreview.trim();
      await prefs.setString(
        _lastPreviewKey,
        preview.length > 140 ? '${preview.substring(0, 140)}…' : preview,
      );
    }

    debugPrint('[DailyChallenge] completed ${challenge.id}, streak=$streak');
    return load(now: today);
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formLabel(String promptType) {
    switch (promptType.toLowerCase()) {
      case 'poem':
        return 'Poetry';
      case 'story':
        return 'Story';
      case 'blog':
        return 'Blog';
      default:
        return 'Writing';
    }
  }

  int _wordTargetFor(String promptType) {
    switch (promptType.toLowerCase()) {
      case 'poem':
        return 60;
      case 'story':
        return 150;
      case 'blog':
        return 200;
      default:
        return 100;
    }
  }

  /// Today's active daily challenge, as created by the cron job.
  ///
  /// Returns null on any failure so the caller can fall back to the bundled
  /// prompt — a network blip must never leave the home screen without a
  /// challenge.
  Future<DailyChallenge?> _fetchTodayFromServer(DateTime today) async {
    try {
      final response = await ApiService.instance.get(
        '/chronicles/writing-prompts',
        queryParameters: {
          'status': 'active',
          'challenge_type': 'daily',
          'limit': 10,
        },
      );

      final prompts = (response['prompts'] as List?) ?? const [];
      if (prompts.isEmpty) return null;

      Map<String, dynamic>? pick;
      for (final raw in prompts) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final starts = DateTime.tryParse(map['starts_at']?.toString() ?? '')?.toLocal();
        if (starts != null &&
            starts.year == today.year &&
            starts.month == today.month &&
            starts.day == today.day) {
          pick = map;
          break;
        }
      }
      pick ??= Map<String, dynamic>.from(prompts.first as Map);

      final content =
          (pick['content'] ?? pick['description'] ?? '').toString().trim();
      if (content.isEmpty) return null;

      final promptType = (pick['prompt_type'] ?? 'writing').toString();
      final words = _wordTargetFor(promptType);

      return DailyChallenge(
        id: _dateKey(today),
        prompt: content,
        kicker: (pick['title'] ?? "Today's challenge").toString(),
        form: _formLabel(promptType),
        wordTarget: words,
        xp: 10 + (words ~/ 20) * 5,
        remoteId: pick['id']?.toString(),
        description: pick['description']?.toString(),
        imageUrl: pick['featured_image_url']?.toString(),
        prizeDescription: pick['prize_description']?.toString(),
        isRemote: true,
      );
    } catch (e) {
      debugPrint('[DailyChallenge] remote fetch failed, using local prompt: $e');
      return null;
    }
  }

  /// Counts consecutive days ending today (or yesterday, so the streak still
  /// reads correctly before today's entry is written).
  int _streakFrom(List<String> completed, DateTime today) {
    if (completed.isEmpty) return 0;
    final days = completed
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();

    final startOfToday = DateTime(today.year, today.month, today.day);
    var cursor = days.contains(startOfToday) ? startOfToday : startOfToday.subtract(const Duration(days: 1));
    if (!days.contains(cursor)) return 0;

    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

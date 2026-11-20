/// Compact, display-ready snapshot shared by the home widget, the ongoing
/// "live Whispr" notification and the iOS Live Activity.
///
/// Keep this type free of Flutter/UI dependencies: the same shape is passed
/// across the method channel to native code.
class LiveUpdateSnapshot {
  const LiveUpdateSnapshot({
    required this.unreadCount,
    required this.postCount,
    required this.streakDays,
    required this.latestTitle,
    required this.latestBody,
    required this.latestLink,
    required this.updatedAt,
    required this.signedIn,
    this.error,
  });

  final int unreadCount;
  final int postCount;
  final int streakDays;
  final String latestTitle;
  final String latestBody;
  final String latestLink;
  final DateTime updatedAt;
  final bool signedIn;
  final String? error;

  static const String homeLink = 'whispr://app/home';
  static const String notificationsLink = 'whispr://app/notifications';

  factory LiveUpdateSnapshot.empty() {
    return LiveUpdateSnapshot(
      unreadCount: 0,
      postCount: 0,
      streakDays: 0,
      latestTitle: 'Your Whispr is waiting',
      latestBody: 'Open Whispr to load your latest updates.',
      latestLink: homeLink,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      signedIn: false,
    );
  }

  /// Builds a snapshot from the existing production endpoints. Every field is
  /// optional on purpose: one endpoint failing must not blank the widget.
  factory LiveUpdateSnapshot.fromSources({
    required Map<String, dynamic> notifications,
    Map<String, dynamic>? stats,
    List<dynamic>? publicPosts,
    String? error,
  }) {
    final signedIn = notifications.containsKey('unread_count') &&
        notifications.containsKey('notifications');

    final latestNotification = _firstMap(notifications['notifications']);
    final latestPost = _firstMap(publicPosts);

    String title;
    String body;
    String link;
    if (latestNotification != null) {
      title = _cleanText(latestNotification['title']) ??
          _cleanText(latestNotification['message']) ??
          'New Whispr update';
      body = _cleanText(latestNotification['message']) ??
          _cleanText(latestNotification['body']) ??
          'Tap to see what changed.';
      link = _safeLink(latestNotification['link']) ?? notificationsLink;
    } else if (latestPost != null) {
      final creator = _asMap(latestPost['creator']) ??
          _asMap(latestPost['authors']) ??
          const <String, dynamic>{};
      final author = _cleanText(creator['pen_name']) ??
          _cleanText(creator['name']) ??
          'the community';
      title = _cleanText(latestPost['title']) ?? 'Fresh from Whispr';
      body = 'New from $author';
      final slug = _cleanText(latestPost['slug']);
      link = _safeLink(latestPost['link']) ??
          (slug != null && slug.isNotEmpty
              ? 'https://whisprwords.com/chronicles/$slug'
              : homeLink);
    } else {
      title = 'Your Whispr is waiting';
      body = signedIn
          ? 'You are all caught up. Tap to explore.'
          : 'Open Whispr to see the latest stories.';
      link = homeLink;
    }

    return LiveUpdateSnapshot(
      unreadCount: signedIn ? _asInt(notifications['unread_count']) : 0,
      postCount: stats == null ? 0 : _asInt(stats['postCount'] ?? stats['totalPosts']),
      streakDays: stats == null
          ? 0
          : _asInt(stats['currentStreak'] ?? stats['streak_count']),
      latestTitle: title,
      latestBody: body,
      latestLink: link,
      updatedAt: DateTime.now().toUtc(),
      signedIn: signedIn,
      error: error,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'unreadCount': unreadCount,
        'postCount': postCount,
        'streakDays': streakDays,
        'latestTitle': latestTitle,
        'latestBody': latestBody,
        'latestLink': latestLink,
        'updatedAt': updatedAt.toIso8601String(),
        'signedIn': signedIn,
        'error': error,
      };

  factory LiveUpdateSnapshot.fromJson(Map<String, dynamic> json) {
    return LiveUpdateSnapshot(
      unreadCount: _asInt(json['unreadCount']),
      postCount: _asInt(json['postCount']),
      streakDays: _asInt(json['streakDays']),
      latestTitle: _cleanText(json['latestTitle']) ?? 'Whispr',
      latestBody: _cleanText(json['latestBody']) ?? 'Open Whispr for updates.',
      latestLink: _safeLink(json['latestLink']) ?? homeLink,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      signedIn: json['signedIn'] == true,
      error: _cleanText(json['error']),
    );
  }

  /// One-line body for the ongoing notification and the widget counts row.
  String get countsLine {
    if (!signedIn) return 'Live from the Whispr community';
    final parts = <String>[
      '$unreadCount unread',
      if (postCount > 0) '$postCount posts',
      if (streakDays > 0) '${streakDays}d streak',
    ];
    return parts.join(' · ');
  }

  static const Set<String> _placeholderTitles = <String>{
    'Your Whispr is waiting',
    'Whispr',
    'Fresh from Whispr',
  };

  bool get _hasUsefulLatest {
    final title = latestTitle.trim();
    if (title.isEmpty || _placeholderTitles.contains(title)) return false;
    return true;
  }

  /// One-line copy for the ongoing notification. Placeholder feed titles must
  /// never become the notification body: without a signed-in snapshot the
  /// useful message is the community prompt, not "Your Whispr is waiting".
  String get liveNotificationBody {
    if (error != null && error!.trim().isNotEmpty) {
      return 'Sync paused · Open Whispr to retry';
    }
    if (!signedIn) {
      return _hasUsefulLatest
          ? latestTitle
          : 'Fresh stories and daily words from the Whispr community';
    }

    final parts = <String>[
      if (unreadCount > 0) '$unreadCount unread',
      if (postCount > 0) '$postCount posts',
      if (streakDays > 0) '${streakDays}d streak',
    ];
    if (parts.isEmpty) {
      return 'You’re all caught up · Open Whispr to explore';
    }
    final latest = _hasUsefulLatest ? ' · $latestTitle' : '';
    return '${parts.join(' · ')}$latest';
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) {
      return value.map((dynamic k, dynamic v) => MapEntry<String, dynamic>(k.toString(), v));
    }
    return null;
  }

  static Map<String, dynamic>? _firstMap(dynamic value) {
    if (value is List && value.isNotEmpty) return _asMap(value.first);
    return _asMap(value);
  }

  static int _asInt(dynamic value) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is num) return value.isNegative ? 0 : value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String? _cleanText(dynamic value) {
    if (value == null) return null;
    final collapsed = value.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.isEmpty) return null;
    return collapsed.length <= 120 ? collapsed : '${collapsed.substring(0, 117)}…';
  }

  /// Never let an API-provided link launch an arbitrary scheme or host.
  static String? _safeLink(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.scheme == 'whispr') return raw;
    if (uri.scheme == 'https' &&
        (uri.host == 'whisprwords.com' || uri.host == 'www.whisprwords.com')) {
      return raw;
    }
    return null;
  }
}

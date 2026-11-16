/// A creator's aggregate numbers, as `/chronicles/creator/stats` returns them.
///
/// The web dashboard reads `total_posts`, `total_engagement`, `streak_count`,
/// `points`, `badges`, `total_followers`; the public creator endpoint instead
/// uses `current_streak` and `total_points`. Both spellings are accepted so a
/// creator's stats render identically whether they came from their own
/// dashboard or from someone viewing their profile.
class CreatorStats {
  final int totalPosts;
  final int publishedPosts;
  final int draftPosts;
  final int totalStories;
  final int totalEngagement;
  final int totalLikes;
  final int totalComments;
  final int totalViews;
  final int totalShares;
  final int currentStreak;
  final int longestStreak;
  final int points;
  final int totalFollowers;
  final int totalFollowing;
  final List<String> badges;
  final String? penName;
  final String? bio;
  final String? joinedAt;

  const CreatorStats({
    this.totalPosts = 0,
    this.publishedPosts = 0,
    this.draftPosts = 0,
    this.totalStories = 0,
    this.totalEngagement = 0,
    this.totalLikes = 0,
    this.totalComments = 0,
    this.totalViews = 0,
    this.totalShares = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.points = 0,
    this.totalFollowers = 0,
    this.totalFollowing = 0,
    this.badges = const [],
    this.penName,
    this.bio,
    this.joinedAt,
  });

  factory CreatorStats.fromJson(Map<String, dynamic> json) {
    // Some responses nest the numbers under `stats` or `creator`.
    final source = <String, dynamic>{
      ...json,
      if (json['stats'] is Map) ...Map<String, dynamic>.from(json['stats'] as Map),
      if (json['creator'] is Map) ...Map<String, dynamic>.from(json['creator'] as Map),
    };

    int pick(List<String> keys) {
      for (final key in keys) {
        final value = source[key];
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) {
          final parsed = int.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
      return 0;
    }

    List<String> badges() {
      final raw = source['badges'];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return const [];
    }

    return CreatorStats(
      totalPosts: pick(['total_posts', 'totalPosts', 'posts_count']),
      publishedPosts: pick(['published_posts', 'publishedPosts']),
      draftPosts: pick(['draft_posts', 'draftPosts']),
      totalStories: pick(['total_stories', 'totalStories', 'stories_count']),
      totalEngagement: pick(['total_engagement', 'totalEngagement', 'engagement']),
      totalLikes: pick(['total_likes', 'totalLikes', 'likes_count']),
      totalComments: pick(['total_comments', 'totalComments', 'comments_count']),
      totalViews: pick(['total_views', 'totalViews', 'views_count']),
      totalShares: pick(['total_shares', 'totalShares', 'shares_count']),
      currentStreak: pick(['streak_count', 'current_streak', 'currentStreak', 'streak']),
      longestStreak: pick(['longest_streak', 'longestStreak']),
      points: pick(['points', 'total_points', 'totalPoints']),
      totalFollowers: pick(['total_followers', 'totalFollowers', 'followers_count']),
      totalFollowing: pick(['total_following', 'totalFollowing', 'following_count']),
      badges: badges(),
      penName: source['pen_name']?.toString() ?? source['penName']?.toString(),
      bio: source['bio']?.toString(),
      joinedAt: source['created_at']?.toString() ?? source['joined_at']?.toString(),
    );
  }

  bool get isEmpty =>
      totalPosts == 0 &&
      totalStories == 0 &&
      totalEngagement == 0 &&
      totalFollowers == 0 &&
      points == 0;

  /// Engagement is counted differently per source; fall back to the sum of the
  /// parts when the aggregate is absent.
  int get effectiveEngagement =>
      totalEngagement > 0 ? totalEngagement : totalLikes + totalComments + totalShares;

  CreatorStats copyWith({
    int? totalPosts,
    int? publishedPosts,
    int? draftPosts,
    int? totalStories,
    int? totalEngagement,
    int? totalLikes,
    int? totalComments,
    int? totalViews,
    int? totalShares,
    int? currentStreak,
    int? longestStreak,
    int? points,
    int? totalFollowers,
    int? totalFollowing,
    List<String>? badges,
  }) {
    return CreatorStats(
      totalPosts: totalPosts ?? this.totalPosts,
      publishedPosts: publishedPosts ?? this.publishedPosts,
      draftPosts: draftPosts ?? this.draftPosts,
      totalStories: totalStories ?? this.totalStories,
      totalEngagement: totalEngagement ?? this.totalEngagement,
      totalLikes: totalLikes ?? this.totalLikes,
      totalComments: totalComments ?? this.totalComments,
      totalViews: totalViews ?? this.totalViews,
      totalShares: totalShares ?? this.totalShares,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      points: points ?? this.points,
      totalFollowers: totalFollowers ?? this.totalFollowers,
      totalFollowing: totalFollowing ?? this.totalFollowing,
      badges: badges ?? this.badges,
      penName: penName,
      bio: bio,
      joinedAt: joinedAt,
    );
  }
}

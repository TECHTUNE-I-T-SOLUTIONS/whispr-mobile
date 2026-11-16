import '../models/chronicles.dart';
import '../models/creator_stats.dart';
import '../network/api_service.dart';
import 'content_cache_service.dart';

/// Everything a Chronicles creator can do, in one place.
///
/// The web dashboard spreads these across a dozen route handlers; mobile only
/// ever called three of them (profile, posts, stats) and so was missing drafts
/// management, deletion, stories, reviews, feed preferences and monetisation.
/// Every method here maps to an endpoint the web already serves, and every one
/// of them works with the mobile Bearer token.
class CreatorService {
  CreatorService(this._api, this._cache);

  final ApiService _api;
  final ContentCacheService _cache;

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  /// The signed-in creator's own profile.
  Future<Map<String, dynamic>> getProfile({bool forceRefresh = false}) async {
    const key = 'creator_profile';
    if (!forceRefresh) {
      final cached = await _cache.readJson(key);
      if (cached is Map) return Map<String, dynamic>.from(cached);
    }
    final response = await _api.get('/chronicles/creator/profile');
    final creator = Map<String, dynamic>.from(response['creator'] ?? response);
    await _cache.saveJson(key, creator);
    return creator;
  }

  Future<Creator> getCreatorModel({bool forceRefresh = false}) async {
    final data = await getProfile(forceRefresh: forceRefresh);
    return Creator.fromJson(data);
  }

  Future<void> updateProfile({
    String? penName,
    String? displayName,
    String? bio,
    List<String>? categories,
    Map<String, dynamic>? socialLinks,
    String? profileVisibility,
    bool? pushNotificationsEnabled,
    String? location,
  }) async {
    final data = <String, dynamic>{};
    if (penName != null) data['pen_name'] = penName;
    if (displayName != null) data['display_name'] = displayName;
    if (bio != null) data['bio'] = bio;
    if (categories != null) data['categories'] = categories;
    if (socialLinks != null) data['social_links'] = socialLinks;
    if (profileVisibility != null) data['profile_visibility'] = profileVisibility;
    if (pushNotificationsEnabled != null) data['push_notifications_enabled'] = pushNotificationsEnabled;
    if (location != null) data['location'] = location;

    await _api.patch('/chronicles/creator/profile', data: data);
    await _cache.remove('creator_profile');
    await _cache.remove('creator_stats');
  }

  // ---------------------------------------------------------------------------
  // Stats
  // ---------------------------------------------------------------------------

  Future<CreatorStats> getStats({bool forceRefresh = false}) async {
    const key = 'creator_stats';
    if (!forceRefresh) {
      final cached = await _cache.readJson(key);
      if (cached is Map) return CreatorStats.fromJson(Map<String, dynamic>.from(cached));
    }
    final response = await _api.get('/chronicles/creator/stats');
    await _cache.saveJson(key, response);
    return CreatorStats.fromJson(response);
  }

  // ---------------------------------------------------------------------------
  // Posts — the creator's own, including drafts
  // ---------------------------------------------------------------------------

  /// All of the creator's posts. [status] filters to draft/published/scheduled.
  Future<List<Map<String, dynamic>>> getMyPosts({
    String? status,
    bool forceRefresh = false,
  }) async {
    final key = 'creator_posts_${status ?? 'all'}';
    if (!forceRefresh) {
      final cached = await _cache.readJson(key);
      if (cached is List) return cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    final response = await _api.get(
      '/chronicles/creator/posts',
      queryParameters: status == null ? null : {'status': status},
    );
    final posts = _listFrom(response);
    await _cache.saveJson(key, posts);
    return posts;
  }

  /// Drafts, scheduled and published in one round trip so the dashboard can
  /// show counts without three requests.
  Future<({List<Map<String, dynamic>> drafts, List<Map<String, dynamic>> published, List<Map<String, dynamic>> scheduled})>
      getPostsByStatus({bool forceRefresh = false}) async {
    final all = await getMyPosts(forceRefresh: forceRefresh);
    List<Map<String, dynamic>> where(String status) =>
        all.where((p) => (p['status'] ?? '').toString() == status).toList();

    return (
      drafts: where('draft'),
      published: where('published'),
      scheduled: where('scheduled'),
    );
  }

  Future<Map<String, dynamic>> createPost({
    required String title,
    required String content,
    required String postType,
    String? excerpt,
    String? category,
    List<String>? tags,
    String status = 'draft',
    String? coverImageUrl,
    DateTime? scheduledFor,
    String? challengeId,
  }) async {
    final slug = _slugify(title);
    final response = await _api.post('/chronicles/creator/posts', data: {
      'title': title,
      'slug': slug,
      'content': content,
      'excerpt': excerpt,
      'post_type': postType,
      'category': category,
      'tags': tags ?? const <String>[],
      'status': status,
      'cover_image_url': coverImageUrl,
      'scheduled_for': scheduledFor?.toIso8601String(),
      'challenge_id': challengeId,
      'formatting_data': const <String, dynamic>{},
    });
    await _invalidatePostCaches();
    return response;
  }

  Future<Map<String, dynamic>> updatePost(
    String postId, {
    String? title,
    String? content,
    String? excerpt,
    String? postType,
    String? category,
    List<String>? tags,
    String? status,
    String? coverImageUrl,
    DateTime? scheduledFor,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) {
      data['title'] = title;
      data['slug'] = _slugify(title);
    }
    if (content != null) data['content'] = content;
    if (excerpt != null) data['excerpt'] = excerpt;
    if (postType != null) data['post_type'] = postType;
    if (category != null) data['category'] = category;
    if (tags != null) data['tags'] = tags;
    if (status != null) data['status'] = status;
    if (coverImageUrl != null) data['cover_image_url'] = coverImageUrl;
    if (scheduledFor != null) data['scheduled_for'] = scheduledFor.toIso8601String();

    final response = await _api.patch('/chronicles/creator/posts/$postId', data: data);
    await _invalidatePostCaches();
    return response;
  }

  Future<void> deletePost(String postId) async {
    await _api.delete('/chronicles/creator/posts/$postId');
    await _invalidatePostCaches();
  }

  /// Publishes or unpublishes in one call — the action creators actually repeat.
  Future<void> setPostStatus(String postId, String status) =>
      updatePost(postId, status: status);

  // ---------------------------------------------------------------------------
  // Stories
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getMyStories({bool forceRefresh = false}) async {
    const key = 'creator_stories';
    if (!forceRefresh) {
      final cached = await _cache.readJson(key);
      if (cached is List) return cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    final response = await _api.get('/chronicles/creator/stories');
    final stories = _listFrom(response);
    await _cache.saveJson(key, stories);
    return stories;
  }

  Future<Map<String, dynamic>> createStory({
    required String title,
    required String genre,
    String? description,
    String? excerpt,
    String? coverImageUrl,
    String status = 'draft',
  }) async {
    final response = await _api.post('/chronicles/creator/stories', data: {
      'title': title,
      'slug': _slugify(title),
      'genre': genre,
      'description': description,
      'excerpt': excerpt,
      'cover_image_url': coverImageUrl,
      'status': status,
    });
    await _cache.remove('creator_stories');
    return response;
  }

  Future<Map<String, dynamic>> createChapter({
    required String storyId,
    required String title,
    required String content,
    int? chapterNumber,
    String status = 'draft',
  }) async {
    final response = await _api.post('/chronicles/creator/stories/chapters', data: {
      'story_id': storyId,
      'title': title,
      'content': content,
      'chapter_number': chapterNumber,
      'status': status,
    });
    await _cache.remove('creator_stories');
    return response;
  }

  // ---------------------------------------------------------------------------
  // Writing chains
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getMyChains({bool forceRefresh = false}) async {
    const key = 'creator_chains';
    if (!forceRefresh) {
      final cached = await _cache.readJson(key);
      if (cached is List) return cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    final response = await _api.get('/chronicles/creator/chains');
    final chains = _listFrom(response);
    await _cache.saveJson(key, chains);
    return chains;
  }

  // ---------------------------------------------------------------------------
  // Reviews, notifications, preferences
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getReviews({bool forceRefresh = false}) async {
    const key = 'creator_reviews';
    if (!forceRefresh) {
      final cached = await _cache.readJson(key);
      if (cached is List) return cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    final response = await _api.get('/chronicles/creator/reviews');
    final reviews = _listFrom(response);
    await _cache.saveJson(key, reviews);
    return reviews;
  }

  Future<List<Map<String, dynamic>>> getNotifications({bool forceRefresh = false}) async {
    const key = 'creator_notifications';
    if (!forceRefresh) {
      final cached = await _cache.readJson(key, maxAge: const Duration(minutes: 2));
      if (cached is List) return cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    final response = await _api.get('/chronicles/creator/notifications');
    final notifications = _listFrom(response);
    await _cache.saveJson(key, notifications);
    return notifications;
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _api.patch('/chronicles/creator/notifications', data: {'id': notificationId, 'read': true});
    await _cache.remove('creator_notifications');
  }

  Future<Map<String, dynamic>> getFeedPreferences({bool forceRefresh = false}) async {
    const key = 'creator_feed_prefs';
    if (!forceRefresh) {
      final cached = await _cache.readJson(key, maxAge: const Duration(hours: 6));
      if (cached is Map) return Map<String, dynamic>.from(cached);
    }
    final response = await _api.get('/chronicles/creator/feed-preferences');
    await _cache.saveJson(key, response);
    return response;
  }

  Future<void> updateFeedPreferences(Map<String, dynamic> prefs) async {
    await _api.patch('/chronicles/creator/feed-preferences', data: prefs);
    await _cache.remove('creator_feed_prefs');
    await _cache.remove('feed_home');
  }

  Future<Map<String, dynamic>> getMonetization({bool forceRefresh = false}) async {
    const key = 'creator_monetization';
    if (!forceRefresh) {
      final cached = await _cache.readJson(key);
      if (cached is Map) return Map<String, dynamic>.from(cached);
    }
    final response = await _api.get('/chronicles/monetization');
    await _cache.saveJson(key, response);
    return response;
  }

  // ---------------------------------------------------------------------------
  // Public creator profiles (for viewing someone else)
  // ---------------------------------------------------------------------------

  /// A creator's public profile by their creator id.
  Future<Map<String, dynamic>> getCreatorById(String creatorId, {bool forceRefresh = false}) async {
    final key = 'creator_public_$creatorId';
    if (!forceRefresh) {
      final cached = await _cache.readJson(key);
      if (cached is Map) return Map<String, dynamic>.from(cached);
    }
    final response = await _api.get('/chronicles/creators/$creatorId');
    final creator = Map<String, dynamic>.from(response['creator'] ?? response);
    await _cache.saveJson(key, creator);
    return creator;
  }

  /// Resolves a pen name to a creator id, then loads the public profile.
  ///
  /// The portfolio screen is opened by pen name (that is what the share link
  /// contains), but every profile endpoint keys off the creator id. The old
  /// code skipped this lookup and fell back to `/creator/profile`, which is the
  /// *signed-in* user — so opening anyone's portfolio showed your own.
  Future<Map<String, dynamic>> getCreatorByPenName(String penName, {bool forceRefresh = false}) async {
    final key = 'creator_public_pen_$penName';
    if (!forceRefresh) {
      final cached = await _cache.readJson(key);
      if (cached is Map) return Map<String, dynamic>.from(cached);
    }

    final resolved = await _api.get(
      '/chronicles/creators',
      queryParameters: {'pen_name': penName},
    );

    final list = _listFrom(resolved);
    if (list.isEmpty) {
      throw CreatorNotFoundException(penName);
    }
    final creatorId = (list.first['id'] ?? '').toString();
    if (creatorId.isEmpty) throw CreatorNotFoundException(penName);

    final creator = await getCreatorById(creatorId, forceRefresh: forceRefresh);
    await _cache.saveJson(key, creator);
    return creator;
  }

  /// A creator's published posts, for their public portfolio.
  Future<List<Map<String, dynamic>>> getCreatorPosts(
    String creatorId, {
    bool forceRefresh = false,
  }) async {
    final key = 'creator_posts_public_$creatorId';
    if (!forceRefresh) {
      final cached = await _cache.readJson(key);
      if (cached is List) return cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    final response = await _api.get('/chronicles/creators/$creatorId/posts');
    final posts = _listFrom(response);
    await _cache.saveJson(key, posts);
    return posts;
  }

  Future<void> followCreator(String creatorId, {bool follow = true}) async {
    await _api.post('/chronicles/creators/follow', data: {'creator_id': creatorId, 'follow': follow});
    await _cache.remove('creator_public_$creatorId');
  }

  Future<List<Map<String, dynamic>>> discoverCreators({
    String? query,
    bool forceRefresh = false,
  }) async {
    final key = 'creators_discover_${query ?? 'all'}';
    if (!forceRefresh) {
      final cached = await _cache.readJson(key, maxAge: const Duration(minutes: 5));
      if (cached is List) return cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    final response = await _api.get(
      '/chronicles/creators/discover',
      queryParameters: query == null || query.isEmpty ? null : {'q': query},
    );
    final creators = _listFrom(response);
    await _cache.saveJson(key, creators);
    return creators;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _invalidatePostCaches() async {
    await _cache.remove('creator_posts_all');
    await _cache.remove('creator_posts_draft');
    await _cache.remove('creator_posts_published');
    await _cache.remove('creator_posts_scheduled');
    await _cache.remove('creator_stats');
    await _cache.remove('feed_home');
    await _cache.remove('portfolio_self');
  }

  /// Endpoints differ: some return a bare list, some `{posts: [...]}`, some
  /// `{stories: [...]}`. This normalises all three.
  static List<Map<String, dynamic>> _listFrom(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (response is Map) {
      for (final key in ['posts', 'stories', 'chains', 'creators', 'reviews', 'notifications', 'data', 'items']) {
        final value = response[key];
        if (value is List) {
          return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    }
    return const [];
  }

  static String _slugify(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .trim();
  }
}

class CreatorNotFoundException implements Exception {
  final String penName;
  CreatorNotFoundException(this.penName);

  @override
  String toString() => 'No creator found with the pen name "$penName".';
}

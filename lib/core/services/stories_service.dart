import 'package:supabase_flutter/supabase_flutter.dart';

class StoriesService {
  StoriesService(this._supabase);

  final SupabaseClient _supabase;

  // Get published stories with optional filters
  Future<List<Map<String, dynamic>>> getPublishedStories({
    String? genre,
    String? hashtag,
    String? authorType,
    String? query,
    String sortBy = 'latest',
    int limit = 20,
  }) async {
    dynamic storiesQuery = _supabase
        .from('view_all_stories')
        .select('*')
        .eq('status', 'published');

    if (genre != null && genre != 'all') {
      storiesQuery = storiesQuery.eq('genre', genre);
    }

    if (authorType != null) {
      storiesQuery = storiesQuery.eq('author_type', authorType);
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim();
      storiesQuery = storiesQuery.or(
          'title.ilike.%$q%,description.ilike.%$q%,excerpt.ilike.%$q%,author_name.ilike.%$q%');
    }

    if (hashtag != null) {
      storiesQuery = storiesQuery.contains('hashtags', [hashtag]);
    }

    if (sortBy == 'likes') {
      storiesQuery = storiesQuery.order('likes_count', ascending: false);
    } else if (sortBy == 'views') {
      storiesQuery = storiesQuery.order('views_count', ascending: false);
    } else {
      storiesQuery = storiesQuery.order('published_at', ascending: false);
    }

    storiesQuery = storiesQuery.limit(limit);

    final response = await storiesQuery;
    return List<Map<String, dynamic>>.from(response);
  }

  // Get story by slug
  Future<Map<String, dynamic>?> getStoryBySlug(String slug) async {
    final response = await _supabase
        .from('view_all_stories')
        .select('*')
        .eq('slug', slug)
        .single();

    return response;
  }

  // Get story chapters
  Future<List<Map<String, dynamic>>> getStoryChapters(
    String storyId,
    String authorType, {
    bool includeDrafts = false,
  }) async {
    final table = authorType == 'admin' ? 'admin_story_chapters' : 'chronicles_story_chapters';
    dynamic query = _supabase
        .from(table)
        .select('*')
        .eq('story_id', storyId);

    if (!includeDrafts) {
      query = query.eq('status', 'published');
    }

    final response = await query.order('sequence', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // Get chapter by slugs
  Future<Map<String, dynamic>?> getChapterBySlugs(
    String storySlug,
    String chapterSlug,
  ) async {
    final story = await getStoryBySlug(storySlug);
    if (story == null) return null;

    final table = story['author_type'] == 'admin' ? 'admin_story_chapters' : 'chronicles_story_chapters';
    final chapter = await _supabase
        .from(table)
        .select('*')
        .eq('story_id', story['id'])
        .eq('slug', chapterSlug)
        .single();

    if (chapter == null) return null;

    // Record view
    final storyTable = story['author_type'] == 'admin' ? 'admin_stories' : 'chronicles_stories';
    await _supabase.rpc('increment_story_views', params: {
      'story_id': story['id'],
      'story_type': story['author_type']
    }).catchError((_) async {
      // Fallback
      await _supabase
          .from(storyTable)
          .update({'views_count': (story['views_count'] ?? 0) + 1})
          .eq('id', story['id']);
    });

    // Get adjacent chapters
    final allChapters = await getStoryChapters(story['id'], story['author_type'], includeDrafts: false);
    final currentIndex = allChapters.indexWhere((c) => c['id'] == chapter['id']);

    return {
      'story': story,
      'chapter': chapter,
      'all_chapters': allChapters,
      'prev_chapter_slug': currentIndex > 0 ? allChapters[currentIndex - 1]['slug'] : null,
      'next_chapter_slug': currentIndex < allChapters.length - 1 ? allChapters[currentIndex + 1]['slug'] : null,
    };
  }

  // Get like status
  Future<bool> getStoryLikeStatus(String storyId, String userId, String authorType) async {
    final table = authorType == 'admin' ? 'admin_story_likes' : 'chronicles_story_likes';
    final response = await _supabase
        .from(table)
        .select('id')
        .eq('story_id', storyId)
        .eq('user_id', userId)
        .maybeSingle();

    return response != null;
  }

  // Like story
  Future<Map<String, dynamic>?> likeStory(String storyId, String userId, String authorType) async {
    final table = authorType == 'admin' ? 'admin_story_likes' : 'chronicles_story_likes';
    final response = await _supabase
        .from(table)
        .insert({'story_id': storyId, 'user_id': userId})
        .select()
        .single();

    return response;
  }

  // Unlike story
  Future<void> unlikeStory(String storyId, String userId, String authorType) async {
    final table = authorType == 'admin' ? 'admin_story_likes' : 'chronicles_story_likes';
    await _supabase
        .from(table)
        .delete()
        .eq('story_id', storyId)
        .eq('user_id', userId);
  }

  // Get story comments
  Future<List<Map<String, dynamic>>> getStoryComments(String storyId, String authorType) async {
    final table = authorType == 'admin' ? 'admin_story_comments' : 'chronicles_story_comments';
    final response = await _supabase
        .from(table)
        .select('*')
        .eq('story_id', storyId)
        .eq('status', 'approved')
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  // Add comment
  Future<Map<String, dynamic>?> addStoryComment({
    required String storyId,
    required String commenterName,
    required String content,
    required String authorType,
    String? commenterEmail,
    String? userId,
    String? creatorId,
    String? parentCommentId,
  }) async {
    // Content compliance check
    final bannedWords = [
      'sex', 'porn', 'pornographic', 'erotica', 'erotic', 'xxx', 'adult story',
      'adult stories', 'r-rated', 'nude', 'nudity', 'sensual story', 'sensual stories',
      'lust', 'lustful', 'orgasm', 'penis', 'vagina', 'intercourse', 'arousal', 'nsfw'
    ];

    for (final word in bannedWords) {
      if (content.toLowerCase().contains(word) || commenterName.toLowerCase().contains(word)) {
        throw Exception('Your comment contains inappropriate content. Please keep Whispr creative and family-friendly.');
      }
    }

    final table = authorType == 'admin' ? 'admin_story_comments' : 'chronicles_story_comments';
    final payload = <String, dynamic>{
      'story_id': storyId,
      'commenter_name': commenterName,
      'content': content,
      'parent_comment_id': parentCommentId,
      'status': 'approved',
    };

    if (authorType == 'admin') {
      payload['user_id'] = userId;
      payload['commenter_email'] = commenterEmail;
    } else {
      payload['user_id'] = userId;
      payload['creator_id'] = creatorId;
    }

    final response = await _supabase
        .from(table)
        .insert(payload)
        .select()
        .single();

    return response;
  }

  // Share story
  Future<Map<String, dynamic>?> shareStory(
    String storyId,
    String sharedTo,
    String authorType, {
    String? creatorId,
  }) async {
    final table = authorType == 'admin' ? 'admin_story_shares' : 'chronicles_story_shares';
    final payload = <String, dynamic>{
      'story_id': storyId,
      'shared_to': sharedTo,
      'share_metadata': {'user_agent': 'Mobile App'},
    };

    if (authorType == 'chronicle' && creatorId != null) {
      payload['creator_id'] = creatorId;
    }

    final response = await _supabase
        .from(table)
        .insert(payload)
        .select()
        .single();

    return response;
  }

  // Get top hashtags
  Future<List<Map<String, dynamic>>> getTopHashtags({int limit = 10}) async {
    final response = await _supabase
        .from('hashtags')
        .select('*')
        .limit(limit);

    return response;
  }

  // Create chronicles story (for creators)
  Future<Map<String, dynamic>?> createChroniclesStory({
    required String creatorId,
    required String title,
    required String slug,
    required String genre,
    String? description,
    String? excerpt,
    String? coverImageUrl,
  }) async {
    final response = await _supabase
        .from('chronicles_stories')
        .insert({
      'creator_id': creatorId,
      'title': title,
      'slug': slug,
      'genre': genre,
      'description': description,
      'excerpt': excerpt,
      'cover_image_url': coverImageUrl,
      'status': 'draft',
    })
        .select()
        .single();

    return response;
  }

  // Update chronicles story
  Future<Map<String, dynamic>?> updateChroniclesStory({
    required String storyId,
    String? title,
    String? description,
    String? excerpt,
    String? coverImageUrl,
    String? status,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (description != null) payload['description'] = description;
    if (excerpt != null) payload['excerpt'] = excerpt;
    if (coverImageUrl != null) payload['cover_image_url'] = coverImageUrl;
    if (status != null) payload['status'] = status;
    payload['updated_at'] = DateTime.now().toIso8601String();

    if (status == 'published' && payload['published_at'] == null) {
      payload['published_at'] = DateTime.now().toIso8601String();
    }

    final response = await _supabase
        .from('chronicles_stories')
        .update(payload)
        .eq('id', storyId)
        .select()
        .single();

    return response;
  }

  // Create story chapter
  Future<Map<String, dynamic>?> createStoryChapter({
    required String storyId,
    required String title,
    required String slug,
    required String content,
    required int sequence,
    String? status,
  }) async {
    // Determine table based on story
    final story = await _supabase
        .from('chronicles_stories')
        .select('id')
        .eq('id', storyId)
        .maybeSingle();

    if (story == null) {
      throw Exception('Story not found');
    }

    final table = 'chronicles_story_chapters';
    final response = await _supabase
        .from(table)
        .insert({
      'story_id': storyId,
      'title': title,
      'slug': slug,
      'content': content,
      'sequence': sequence,
      'status': status ?? 'published',
    })
        .select()
        .single();

    return response;
  }

  // Update story chapter
  Future<Map<String, dynamic>?> updateStoryChapter({
    required String chapterId,
    String? title,
    String? content,
    String? status,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (content != null) payload['content'] = content;
    if (status != null) payload['status'] = status;
    payload['updated_at'] = DateTime.now().toIso8601String();

    final response = await _supabase
        .from('chronicles_story_chapters')
        .update(payload)
        .eq('id', chapterId)
        .select()
        .single();

    return response;
  }

  // Get creator's stories
  Future<List<Map<String, dynamic>>> getCreatorStories(String creatorId) async {
    final response = await _supabase
        .from('chronicles_stories')
        .select('*')
        .eq('creator_id', creatorId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}

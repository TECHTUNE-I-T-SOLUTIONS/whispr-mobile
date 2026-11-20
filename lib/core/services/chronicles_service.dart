import '../network/api_service.dart';
import 'content_cache_service.dart';

class ChroniclesService {
  ChroniclesService(this._apiService, this._cacheService);

  final ApiService _apiService;
  final ContentCacheService _cacheService;

  Future<List<dynamic>> getCreatorPosts({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cacheService.readJson('creator_posts');
      // An empty cached list is almost always the residue of a request made
      // before the auth token was attached — treat it as a miss.
      if (cached is List && cached.isNotEmpty) return cached;
    }
    final response = await _apiService.get('/chronicles/creator/posts');
    final posts = (response['posts'] as List?) ?? const [];
    if (posts.isNotEmpty) {
      await _cacheService.saveJson('creator_posts', posts);
    }
    return posts;
  }

  Future<List<dynamic>> getPublicChronicles({
    bool forceRefresh = false,
    String? category,
  }) async {
    final suffix = category == null
        ? ''
        : '_${category.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
    final key = 'public_chronicles$suffix';
    if (!forceRefresh) {
      final cached = await _cacheService.readJson(key);
      if (cached is List && cached.isNotEmpty) return cached;
    }
    final response = await _apiService.get(
      '/chronicles/all',
      queryParameters: category == null ? null : {'category': category},
    );
    final posts = (response['posts'] as List? ?? const [])
        .where((post) {
          final map = post is Map ? Map<String, dynamic>.from(post) : <String, dynamic>{};
          final status = (map['status'] ?? '').toString();
          return status == 'published';
        })
        .toList();
    if (posts.isNotEmpty) {
      await _cacheService.saveJson(key, posts);
    }
    return posts;
  }

  /// Categories advertised by the API, falling back to those found on posts.
  Future<List<String>> getChronicleCategories() async {
    try {
      final response = await _apiService.get('/chronicles/all');
      final raw = response['categories'] as List?;
      if (raw != null && raw.isNotEmpty) {
        return raw.map((e) => e.toString()).toList()..sort();
      }
    } catch (_) {
      // The screen derives categories from loaded posts when the API is old.
    }
    final posts = await getPublicChronicles();
    final categories = posts
        .map((post) => post is Map ? post['category']?.toString() : null)
        .whereType<String>()
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return categories;
  }

  Future<Map<String, dynamic>> getPost(String id, {bool isSlug = false}) async {
    if (isSlug) {
      // Use slug endpoint
      final response = await _apiService.get('/chronicles/by-slug/$id');
      return Map<String, dynamic>.from(response['data'] ?? response);
    }
    // Use ID endpoint
    final response = await _apiService.get('/chronicles/posts/$id');
    return Map<String, dynamic>.from(response['data'] ?? response);
  }

  Future<List<dynamic>> getCreatorNotifications() async {
    final response = await _apiService.get('/chronicles/creator/notifications');
    return (response['notifications'] as List?) ?? const [];
  }

  Future<Map<String, dynamic>> getCreatorProfile() async {
    final response = await _apiService.get('/chronicles/creator/profile');
    return Map<String, dynamic>.from(response['creator'] ?? response);
  }

  Future<List<dynamic>> getCreatorPortfolioPosts(String creatorId) async {
    final response = await _apiService.get('/chronicles/creators/$creatorId/posts');
    return (response['posts'] as List?) ?? const [];
  }
}

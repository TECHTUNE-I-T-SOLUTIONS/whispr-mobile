import '../network/api_service.dart';
import 'content_cache_service.dart';

class ChroniclesService {
  ChroniclesService(this._apiService, this._cacheService);

  final ApiService _apiService;
  final ContentCacheService _cacheService;

  Future<List<dynamic>> getCreatorPosts({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cacheService.readJson('creator_posts');
      if (cached is List) return cached;
    }
    final response = await _apiService.get('/chronicles/creator/posts');
    final posts = (response['posts'] as List?) ?? const [];
    await _cacheService.saveJson('creator_posts', posts);
    return posts;
  }

  Future<List<dynamic>> getPublicChronicles({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cacheService.readJson('public_chronicles');
      if (cached is List) return cached;
    }
    final response = await _apiService.get('/chronicles/all');
    final posts = (response['posts'] as List? ?? const [])
        .where((post) {
          final map = post is Map ? Map<String, dynamic>.from(post) : <String, dynamic>{};
          final status = (map['status'] ?? '').toString();
          return status == 'published';
        })
        .toList();
    await _cacheService.saveJson('public_chronicles', posts);
    return posts;
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

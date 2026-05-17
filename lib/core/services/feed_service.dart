import '../network/api_service.dart';
import 'content_cache_service.dart';

class FeedService {
  FeedService(this._apiService, this._cacheService);

  final ApiService _apiService;
  final ContentCacheService _cacheService;

  Future<List<dynamic>> getFeed({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cacheService.readJson('feed_home');
      if (cached is List) return cached;
    }

    final response = await _apiService.get('/feed');
    final posts = (response['posts'] as List?) ?? const [];
    await _cacheService.saveJson('feed_home', posts);
    return posts;
  }
}

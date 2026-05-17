import '../network/api_service.dart';
import 'content_cache_service.dart';

class ProfileService {
  ProfileService(this._apiService, this._cacheService);

  final ApiService _apiService;
  final ContentCacheService _cacheService;

  Future<Map<String, dynamic>> getCreatorProfile(String creatorId) async {
    final cached = await _cacheService.readJson('creator_profile_$creatorId');
    if (cached is Map) return Map<String, dynamic>.from(cached);

    final response = await _apiService.get('/chronicles/creators/$creatorId');
    final creator = Map<String, dynamic>.from(response['creator'] ?? response);
    await _cacheService.saveJson('creator_profile_$creatorId', creator);
    return creator;
  }

  Future<List<dynamic>> getCreatorPosts(String creatorId) async {
    final response = await _apiService.get('/chronicles/creators/$creatorId/posts');
    return (response['posts'] as List?) ?? const [];
  }
}

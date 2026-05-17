import '../network/api_service.dart';
import 'content_cache_service.dart';

class PortfolioService {
  PortfolioService(this._apiService, this._cacheService);

  final ApiService _apiService;
  final ContentCacheService _cacheService;

  Future<Map<String, dynamic>> getPortfolioByPenName(String penName, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cacheService.readJson('portfolio_$penName');
      if (cached is Map) return Map<String, dynamic>.from(cached);
    }

    final profile = await _apiService.get('/chronicles/creator/profile');
    final creator = Map<String, dynamic>.from(profile['creator'] ?? profile);
    final posts = await _apiService.get('/chronicles/creator/posts');
    final response = {
      'creator': creator,
      'posts': (posts['posts'] as List?) ?? const [],
      'chains': <dynamic>[],
    };
    await _cacheService.saveJson('portfolio_$penName', response);
    return response;
  }
}

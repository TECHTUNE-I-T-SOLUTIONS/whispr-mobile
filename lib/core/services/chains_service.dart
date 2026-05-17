import '../network/api_service.dart';
import 'content_cache_service.dart';

class ChainsService {
  ChainsService(this._apiService, this._cacheService);

  final ApiService _apiService;
  final ContentCacheService _cacheService;

  Future<List<dynamic>> getChains({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cacheService.readJson('chains_home');
      if (cached is List) return cached;
    }
    final response = await _apiService.get('/chronicles/chains?limit=20');
    final data = (response['data'] as List?) ?? const [];
    await _cacheService.saveJson('chains_home', data);
    return data;
  }

  Future<Map<String, dynamic>> getChain(String chainId) async {
    final response = await _apiService.get('/chronicles/chains/$chainId');
    return Map<String, dynamic>.from(response['data'] ?? response);
  }

  Future<List<dynamic>> getMyWritings() async {
    final response = await _apiService.get('/chronicles/creator/chains');
    return (response['data'] as List?) ?? const [];
  }
}

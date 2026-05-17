import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/api_service.dart';

class GamesService {
  final _client = Supabase.instance.client;

  Future<void> ensureCatalog() async {
    try {
      await ApiService.instance.post('/games', data: {'action': 'bootstrap_catalog'});
    } catch (_) {
      // If bootstrap fails, fall back to whatever already exists.
    }
  }

  Future<List<Map<String, dynamic>>> listGames() async {
    await ensureCatalog();
    final rows = await _client
        .from('chronicles_games')
        .select('id, slug, title, description, game_type, audience, difficulty, is_offline_ready, is_ai_powered, is_published, config, cover_image_url, created_by, created_at, updated_at')
        .eq('is_published', true)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> listTemplates() => listGames();

  Future<Map<String, dynamic>?> getGameBySlug(String slug) async {
    final row = await _client.from('chronicles_games').select().eq('slug', slug).maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> listModules() async {
    final rows = await _client.from('chronicles_learning_modules').select().eq('is_published', true).order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> listSections(String moduleId) async {
    final rows = await _client.from('chronicles_learning_sections').select().eq('module_id', moduleId).order('order_index');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> listProgress(String creatorId) async {
    final rows = await _client
        .from('chronicles_creator_game_progress')
        .select('*, game:chronicles_games(id, slug, title, game_type, cover_image_url)')
        .eq('creator_id', creatorId)
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> listAchievements() async {
    final rows = await _client.from('chronicles_game_achievements').select().order('points_reward');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> listEarnedAchievements(String creatorId) async {
    final rows = await _client
        .from('chronicles_creator_game_achievements')
        .select('*, achievement:chronicles_game_achievements(*)')
        .eq('creator_id', creatorId)
        .order('earned_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }
}

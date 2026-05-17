import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import 'auth_session_store.dart';

class GamesProgressService {
  final _client = Supabase.instance.client;

  Future<Map<String, dynamic>?> currentCreator() async {
    final storedSession = await AuthSessionStore.restore();
    final storedUser = storedSession?.user;
    if (storedUser != null && storedUser.id.isNotEmpty) {
      return {
        'id': storedUser.id,
        'pen_name': storedUser.penName,
      };
    }

    final session = _client.auth.currentSession;
    final user = _client.auth.currentUser ?? session?.user;
    if (user != null) {
      final row = await _client.from('chronicles_creators').select('id, pen_name').eq('user_id', user.id).maybeSingle();
      if (row != null) return Map<String, dynamic>.from(row);
    }

    final prefs = await SharedPreferences.getInstance();
    final storedUserData = prefs.getString(AppConstants.userDataKey);
    if (storedUserData == null || storedUserData.isEmpty) return null;

    try {
      final parsed = jsonDecode(storedUserData);
      if (parsed is Map<String, dynamic>) {
        final creatorId = parsed['id']?.toString();
        if (creatorId != null && creatorId.isNotEmpty) {
          return {
            'id': creatorId,
            'pen_name': parsed['pen_name'] ?? parsed['penName'] ?? '',
          };
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<void> upsertProgress({
    required String creatorId,
    required String gameId,
    required int score,
    required int streak,
    required int attempts,
    required int completedSessions,
  }) async {
    final existing = await _client
        .from('chronicles_creator_game_progress')
        .select('best_score,total_score,best_streak,attempts_count,completed_sessions')
        .eq('creator_id', creatorId)
        .eq('game_id', gameId)
        .maybeSingle();

    final previous = existing == null ? <String, dynamic>{} : Map<String, dynamic>.from(existing);
    final bestScore = ((previous['best_score'] ?? 0) as num).toInt();
    final totalScore = ((previous['total_score'] ?? 0) as num).toInt();
    final bestStreak = ((previous['best_streak'] ?? 0) as num).toInt();
    final previousAttempts = ((previous['attempts_count'] ?? 0) as num).toInt();
    final previousCompleted = ((previous['completed_sessions'] ?? 0) as num).toInt();

    await _client.from('chronicles_creator_game_progress').upsert({
      'creator_id': creatorId,
      'game_id': gameId,
      'best_score': score > bestScore ? score : bestScore,
      'total_score': totalScore + score,
      'best_streak': streak > bestStreak ? streak : bestStreak,
      'attempts_count': previousAttempts + attempts,
      'completed_sessions': previousCompleted + completedSessions,
      'last_played_at': DateTime.now().toIso8601String(),
    }, onConflict: 'creator_id,game_id');
  }
}

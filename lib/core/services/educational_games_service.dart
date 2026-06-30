import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for educational writing games that use pre-built challenges
/// Uses Supabase client-side access for better performance and reduced API dependency
class EducationalGamesService {
  static final EducationalGamesService instance = EducationalGamesService._internal();
  final _supabase = Supabase.instance.client;

  EducationalGamesService._internal();

  /// Get all published educational games
  Future<List<Map<String, dynamic>>> getGames() async {
    try {
      final response = await _supabase
          .from('chronicles_games')
          .select('*')
          .eq('is_published', true)
          .eq('is_ai_powered', false)
          .order('title');
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Return empty list on error
      return [];
    }
  }

  /// Get a specific game by slug
  Future<Map<String, dynamic>?> getGameBySlug(String slug) async {
    try {
      final response = await _supabase
          .from('chronicles_games')
          .select('*')
          .eq('slug', slug)
          .eq('is_published', true)
          .maybeSingle();
      
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Get challenges for a specific game
  Future<List<Map<String, dynamic>>> getGameChallenges(String gameSlug) async {
    try {
      final game = await getGameBySlug(gameSlug);
      if (game == null) return [];

      final response = await _supabase
          .from('chronicles_game_challenges')
          .select('*')
          .eq('game_id', game['id'])
          .eq('is_active', true)
          .order('challenge_order');
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Return empty list on error
      return [];
    }
  }

  /// Start a new game session
  Future<Map<String, dynamic>> startSession({
    required String gameSlug,
    required String creatorId,
  }) async {
    final game = await getGameBySlug(gameSlug);
    if (game == null) throw Exception('Game not found');

    final response = await _supabase
        .from('chronicles_game_sessions')
        .insert({
          'game_id': game['id'],
          'creator_id': creatorId,
          'mode': 'practice',
          'status': 'active',
          'metadata': {
            'game_slug': game['slug'],
            'game_type': game['game_type'],
            'game_title': game['title'],
          },
        })
        .select()
        .single();

    return response;
  }

  /// Get an active session for a game
  Future<Map<String, dynamic>?> getActiveSession({
    required String gameSlug,
    required String creatorId,
  }) async {
    final game = await getGameBySlug(gameSlug);
    if (game == null) return null;

    final response = await _supabase
        .from('chronicles_game_sessions')
        .select('*')
        .eq('game_id', game['id'])
        .eq('creator_id', creatorId)
        .eq('status', 'active')
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response;
  }

  /// Submit an answer for a challenge (local evaluation for educational games)
  Future<Map<String, dynamic>> submitAnswer({
    required String sessionId,
    required String challengeId,
    required String answer,
    required String creatorId,
  }) async {
    // Get the challenge to evaluate locally
    final challenge = await _supabase
        .from('chronicles_game_challenges')
        .select('*')
        .eq('id', challengeId)
        .single();

    final isCorrect = answer == challenge['correct_answer'];
    final feedback = isCorrect 
        ? challenge['explanation'] 
        : 'Not quite. ${challenge['explanation']}';

    // Insert the round with user answer
    await _supabase
        .from('chronicles_game_rounds')
        .insert({
          'session_id': sessionId,
          'prompt': challenge['question'],
          'prompt_type': 'educational',
          'expected_answer': challenge['correct_answer'],
          'user_answer': answer,
          'is_correct': isCorrect,
          'explanation': challenge['explanation'],
          'options': challenge['options'],
          'points_awarded': isCorrect ? 10 : 0,
          'order_index': 0,
        });

    // Update session stats
    final session = await _supabase
        .from('chronicles_game_sessions')
        .select('*')
        .eq('id', sessionId)
        .single();

    final newScore = (session['score'] ?? 0) + (isCorrect ? 10 : 0);
    final newStreak = isCorrect ? (session['streak_count'] ?? 0) + 1 : 0;
    final newCorrectAnswers = (session['correct_answers'] ?? 0) + (isCorrect ? 1 : 0);
    final newIncorrectAnswers = (session['incorrect_answers'] ?? 0) + (isCorrect ? 0 : 1);
    final newTotalRounds = (session['total_rounds'] ?? 0) + 1;

    await _supabase
        .from('chronicles_game_sessions')
        .update({
          'score': newScore,
          'streak_count': newStreak,
          'correct_answers': newCorrectAnswers,
          'incorrect_answers': newIncorrectAnswers,
          'total_rounds': newTotalRounds,
        })
        .eq('id', sessionId);

    // Update progress
    await _updateProgress(
      creatorId: creatorId,
      gameId: session['game_id'],
      score: newScore,
      streak: newStreak,
      completedSessions: isCorrect ? 1 : 0,
    );

    return {
      'correct': isCorrect,
      'feedback': feedback,
      'score': newScore,
    };
  }

  /// Complete a game session
  Future<void> completeSession({
    required String sessionId,
    required String creatorId,
  }) async {
    await _supabase
        .from('chronicles_game_sessions')
        .update({
          'status': 'completed',
          'ended_at': DateTime.now().toIso8601String(),
        })
        .eq('id', sessionId);

    // Increment completed sessions in progress
    final session = await _supabase
        .from('chronicles_game_sessions')
        .select('game_id')
        .eq('id', sessionId)
        .single();

    final progress = await _supabase
        .from('chronicles_creator_game_progress')
        .select('*')
        .eq('creator_id', creatorId)
        .eq('game_id', session['game_id'])
        .maybeSingle();

    if (progress != null) {
      await _supabase
          .from('chronicles_creator_game_progress')
          .update({
            'completed_sessions': (progress['completed_sessions'] ?? 0) + 1,
            'last_played_at': DateTime.now().toIso8601String(),
          })
          .eq('creator_id', creatorId)
          .eq('game_id', session['game_id']);
    }
  }

  /// Get user progress for a game
  Future<Map<String, dynamic>?> getProgress({
    required String creatorId,
    required String gameId,
  }) async {
    final response = await _supabase
        .from('chronicles_creator_game_progress')
        .select('*')
        .eq('creator_id', creatorId)
        .eq('game_id', gameId)
        .maybeSingle();

    return response;
  }

  /// Update or create progress record
  Future<void> _updateProgress({
    required String creatorId,
    required String gameId,
    required int score,
    required int streak,
    required int completedSessions,
  }) async {
    final existing = await getProgress(creatorId: creatorId, gameId: gameId);

    if (existing != null) {
      await _supabase
          .from('chronicles_creator_game_progress')
          .update({
            'best_score': (existing['best_score'] ?? 0) > score ? existing['best_score'] : score,
            'total_score': (existing['total_score'] ?? 0) + score,
            'best_streak': (existing['best_streak'] ?? 0) > streak ? existing['best_streak'] : streak,
            'attempts_count': (existing['attempts_count'] ?? 0) + 1,
            'completed_sessions': (existing['completed_sessions'] ?? 0) + completedSessions,
            'last_played_at': DateTime.now().toIso8601String(),
          })
          .eq('creator_id', creatorId)
          .eq('game_id', gameId);
    } else {
      await _supabase
          .from('chronicles_creator_game_progress')
          .insert({
            'creator_id': creatorId,
            'game_id': gameId,
            'best_score': score,
            'total_score': score,
            'best_streak': streak,
            'attempts_count': 1,
            'completed_sessions': completedSessions,
            'last_played_at': DateTime.now().toIso8601String(),
          });
    }
  }

  /// Get all progress for a user
  Future<List<Map<String, dynamic>>> getAllProgress(String creatorId) async {
    final response = await _supabase
        .from('chronicles_creator_game_progress')
        .select('*')
        .eq('creator_id', creatorId);

    return List<Map<String, dynamic>>.from(response);
  }
}
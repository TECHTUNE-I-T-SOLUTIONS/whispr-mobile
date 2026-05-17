import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_service.dart';
import '../../../core/services/games_progress_service.dart';

class GamePlayScreen extends StatefulWidget {
  final Map<String, dynamic> game;
  const GamePlayScreen({super.key, required this.game});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  final _progress = GamesProgressService();
  final _answerController = TextEditingController();
  Map<String, dynamic>? _session;
  Map<String, dynamic>? _round;
  bool _loading = true;
  bool _submitting = false;
  int _score = 0;
  int _streak = 0;
  int _attempts = 0;
  int _roundIndex = 0;
  String? _feedback;
  Timer? _feedbackTimer;
  bool _completed = false;

  String get _gameSlug => (widget.game['slug'] ?? widget.game['game_type'] ?? 'poem_next_line').toString();

  String get _gameTitle => (widget.game['title'] ?? widget.game['game']?['title'] ?? 'Game').toString();

  String get _gameDescription => (widget.game['description'] ?? widget.game['game']?['description'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    final creator = await _progress.currentCreator();
    if (creator == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to play.')));
        context.pop();
      }
      return;
    }

    final resume = await ApiService.instance.post('/games', data: {
      'action': 'resume',
      'game_slug': _gameSlug,
      'creator_id': creator['id'],
      'mode': 'practice',
    });

    if (!mounted) return;
    if (resume['resumed'] == true) {
      setState(() {
        _session = Map<String, dynamic>.from(resume['session']);
        _round = resume['round'] == null ? null : Map<String, dynamic>.from(resume['round']);
        _score = _session?['score'] ?? 0;
        _streak = _session?['streak_count'] ?? 0;
        _attempts = _session?['total_rounds'] ?? 0;
        _roundIndex = _round?['order_index'] ?? 0;
        _completed = (_session?['status'] ?? '') == 'completed';
        _loading = false;
      });
      return;
    }

    final response = await ApiService.instance.post('/games', data: {
      'action': 'start',
      'game_slug': _gameSlug,
      'creator_id': creator['id'],
      'mode': 'practice',
    });

    setState(() {
      _session = Map<String, dynamic>.from(response['session']);
      _round = Map<String, dynamic>.from(response['round']);
      _roundIndex = _round?['order_index'] ?? 0;
      _loading = false;
    });
  }

  Future<void> _submitAnswer() async {
    if (_session == null || _round == null) return;
    final answer = _answerController.text.trim();
    if (answer.isEmpty) return;

    _feedbackTimer?.cancel();
    setState(() {
      _submitting = true;
      _feedback = null;
    });
    final response = await ApiService.instance.post('/games', data: {
      'action': 'evaluate',
      'session_id': _session!['id'],
      'round_id': _round!['id'],
      'answer': answer,
      'game_slug': widget.game['slug'],
    });

    final nextRound = response['next_round'];

    setState(() {
      _feedback = response['feedback'] ?? '';
      _score = response['score'] ?? _score;
      _streak = response['streak'] ?? _streak;
      _attempts += 1;
      _roundIndex += 1;
      _submitting = false;
      _answerController.clear();
      _round = nextRound == null ? null : Map<String, dynamic>.from(nextRound);
      _completed = response['completed'] == true;
    });

    if (_feedback != null && _feedback!.isNotEmpty) {
      _feedbackTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _feedback = null);
      });
    }

    if (_session != null) {
      final sessionGameId = _session!['game_id']?.toString();
      if (sessionGameId != null && sessionGameId.isNotEmpty) {
        try {
          await _progress.upsertProgress(
            creatorId: _session!['creator_id'],
            gameId: sessionGameId,
            score: _score,
            streak: _streak,
            attempts: _attempts,
            completedSessions: response['completed'] == true ? 1 : 0,
          );
        } catch (_) {
          // Ignore progress save failures to avoid interrupting active gameplay.
        }
      }
    }
  }

  Future<void> _restartSession() async {
    setState(() {
      _completed = false;
      _loading = true;
      _session = null;
      _round = null;
      _score = 0;
      _streak = 0;
      _attempts = 0;
      _roundIndex = 0;
      _feedback = null;
    });
    await _startSession();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_gameTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_completed || _round == null)
              ? _summary()
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _templateHeader(),
                        const SizedBox(height: 16),
                        _statBar(),
                        const SizedBox(height: 16),
                        if (_round != null) _roundCard(),
                        const SizedBox(height: 16),
                        _answerInput(),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _submitting ? null : _submitAnswer,
                            child: _submitting
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Submit'),
                          ),
                        ),
                        if (_feedback != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Theme.of(context).colorScheme.primaryContainer,
                            ),
                            child: Text(_feedback!),
                          ),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _summary() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_outlined, size: 72),
            const SizedBox(height: 16),
            const Text('Session Summary', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text('You scored $_score points with a best streak of $_streak.', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _chip('Score', '$_score')),
                const SizedBox(width: 8),
                Expanded(child: _chip('Streak', '$_streak')),
                const SizedBox(width: 8),
                Expanded(child: _chip('Rounds', '$_attempts')),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _restartSession,
                icon: const Icon(Icons.replay),
                label: Text(_completed ? 'Play Again' : 'Start New Session'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _answerInput() {
    final options = (_round?['options'] as List?) ?? const [];
    if (options.isNotEmpty) {
      return Column(
        children: options.map((o) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _submitting
                    ? null
                    : () {
                        _answerController.text = o.toString();
                        _submitAnswer();
                      },
                child: Text(o.toString()),
              ),
            ),
          );
        }).toList(),
      );
    }

    return TextField(
      controller: _answerController,
      maxLines: 4,
      decoration: const InputDecoration(
        hintText: 'Write the next line...',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _statBar() => Row(
        children: [
          _chip('Score', '$_score'),
          const SizedBox(width: 8),
          _chip('Streak', '$_streak'),
          const SizedBox(width: 8),
          _chip('Round', '${_roundIndex + 1}'),
        ],
      );

  Widget _chip(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: Theme.of(context).cardColor),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );

  Widget _roundCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_round!['prompt_type'] ?? 'Prompt', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_round!['prompt'] ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const SizedBox(height: 4),
            Text(_round!['explanation'] ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );

  Widget _templateHeader() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceContainerHighest,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _gameSlug.replaceAll('_', ' '),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text('Round ${_roundIndex + 1}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 12),
            Text(_gameTitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w800)),
            if (_gameDescription.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(_gameDescription, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      );
}

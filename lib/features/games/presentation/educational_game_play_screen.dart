import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/educational_games_service.dart';
import '../../../core/services/games_progress_service.dart';

class EducationalGamePlayScreen extends StatefulWidget {
  final Map<String, dynamic> game;
  const EducationalGamePlayScreen({super.key, required this.game});

  @override
  State<EducationalGamePlayScreen> createState() => _EducationalGamePlayScreenState();
}

class _EducationalGamePlayScreenState extends State<EducationalGamePlayScreen> {
  final _gameService = EducationalGamesService.instance;
  final _progressService = GamesProgressService();
  
  List<Map<String, dynamic>> _challenges = [];
  int _currentChallengeIndex = 0;
  int _score = 0;
  int _correctAnswers = 0;
  String? _selectedAnswer;
  bool _showResult = false;
  bool _isCorrect = false;
  bool _loading = true;
  bool _submitting = false;
  String? _sessionId;

  String get _gameSlug => (widget.game['slug'] ?? '').toString();
  String get _gameTitle => (widget.game['title'] ?? 'Game').toString();
  String get _gameDescription => (widget.game['description'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    try {
      final challenges = await _gameService.getGameChallenges(_gameSlug);
      if (!mounted) return;
      setState(() {
        _challenges = challenges;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _submitAnswer() async {
    if (_selectedAnswer == null) return;
    
    final currentChallenge = _challenges[_currentChallengeIndex];
    final correctAnswer = currentChallenge['correct_answer']?.toString();
    final isCorrect = _selectedAnswer == correctAnswer;

    setState(() {
      _submitting = true;
      _isCorrect = isCorrect;
      _showResult = true;
      if (isCorrect) {
        _score += 10;
        _correctAnswers++;
      }
    });

    // Simulate API call for progress tracking
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() => _submitting = false);
  }

  void _nextChallenge() {
    if (_currentChallengeIndex < _challenges.length - 1) {
      setState(() {
        _currentChallengeIndex++;
        _selectedAnswer = null;
        _showResult = false;
      });
    } else {
      _showSummary();
    }
  }

  void _showSummary() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SummaryDialog(
        score: _score,
        correctAnswers: _correctAnswers,
        totalChallenges: _challenges.length,
        gameTitle: _gameTitle,
        onRestart: () {
          context.pop();
          setState(() {
            _currentChallengeIndex = 0;
            _score = 0;
            _correctAnswers = 0;
            _selectedAnswer = null;
            _showResult = false;
          });
        },
        onExit: () => context.pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_gameTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_challenges.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_gameTitle)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No challenges available'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final currentChallenge = _challenges[_currentChallengeIndex];
    final options = List<String>.from(currentChallenge['options'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: Text(_gameTitle),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Chip(
                label: Text('Score: $_score'),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProgressIndicator(
              current: _currentChallengeIndex + 1,
              total: _challenges.length,
            ),
            const SizedBox(height: 24),
            _ChallengeCard(
              challenge: currentChallenge,
              options: options,
              selectedAnswer: _selectedAnswer,
              showResult: _showResult,
              isCorrect: _isCorrect,
              onAnswerSelected: (answer) {
                if (!_showResult) {
                  setState(() => _selectedAnswer = answer);
                }
              },
            ),
            const SizedBox(height: 24),
            if (_showResult) ...[
              _ResultCard(
                isCorrect: _isCorrect,
                explanation: currentChallenge['explanation']?.toString() ?? '',
                teachingPoint: currentChallenge['teaching_point']?.toString(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _nextChallenge,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_currentChallengeIndex < _challenges.length - 1
                          ? 'Next Challenge'
                          : 'View Summary'),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedAnswer == null || _submitting ? null : _submitAnswer,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit Answer'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = current / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Challenge $current of $total',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final Map<String, dynamic> challenge;
  final List<String> options;
  final String? selectedAnswer;
  final bool showResult;
  final bool isCorrect;
  final ValueChanged<String> onAnswerSelected;

  const _ChallengeCard({
    required this.challenge,
    required this.options,
    required this.selectedAnswer,
    required this.showResult,
    required this.isCorrect,
    required this.onAnswerSelected,
  });

  @override
  Widget build(BuildContext context) {
    final question = challenge['question']?.toString() ?? '';
    final contextText = challenge['context']?.toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (contextText != null && contextText.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                contextText,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            question,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          ...options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = selectedAnswer == option;
            final correctAnswer = challenge['correct_answer']?.toString();
            final isOptionCorrect = option == correctAnswer;

            Color? backgroundColor;
            Color? borderColor;
            Color? textColor;

            if (showResult) {
              if (isOptionCorrect) {
                backgroundColor = Colors.green.withValues(alpha: 0.1);
                borderColor = Colors.green;
                textColor = Colors.green.shade700;
              } else if (isSelected && !isCorrect) {
                backgroundColor = Colors.red.withValues(alpha: 0.1);
                borderColor = Colors.red;
                textColor = Colors.red.shade700;
              }
            } else if (isSelected) {
              backgroundColor = Theme.of(context).colorScheme.primaryContainer;
              borderColor = Theme.of(context).colorScheme.primary;
              textColor = Theme.of(context).colorScheme.onPrimaryContainer;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: showResult ? null : () => onAnswerSelected(option),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderColor ?? Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: backgroundColor ?? Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + index),
                            style: TextStyle(
                              color: textColor ?? Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (showResult && isOptionCorrect)
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                      if (showResult && isSelected && !isCorrect)
                        Icon(
                          Icons.cancel,
                          color: Colors.red,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final bool isCorrect;
  final String explanation;
  final String? teachingPoint;

  const _ResultCard({
    required this.isCorrect,
    required this.explanation,
    this.teachingPoint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCorrect
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCorrect ? Colors.green : Colors.orange,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.info,
                color: isCorrect ? Colors.green : Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                isCorrect ? 'Correct!' : 'Not quite',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isCorrect ? Colors.green.shade700 : Colors.orange.shade700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            explanation,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          if (teachingPoint != null && teachingPoint!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb,
                    size: 20,
                    color: isCorrect ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '💡 $teachingPoint',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isCorrect ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryDialog extends StatelessWidget {
  final int score;
  final int correctAnswers;
  final int totalChallenges;
  final String gameTitle;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  const _SummaryDialog({
    required this.score,
    required this.correctAnswers,
    required this.totalChallenges,
    required this.gameTitle,
    required this.onRestart,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (correctAnswers / totalChallenges * 100).toInt();
    final isExcellent = percentage >= 80;
    final isGood = percentage >= 60;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isExcellent ? Icons.emoji_events : isGood ? Icons.thumb_up : Icons.school,
            size: 64,
            color: isExcellent
                ? Colors.amber
                : isGood
                    ? Colors.green
                    : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Session Complete!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            gameTitle,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(label: 'Score', value: '$score'),
              _StatItem(label: 'Correct', value: '$correctAnswers/$totalChallenges'),
              _StatItem(label: 'Accuracy', value: '$percentage%'),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isExcellent
                  ? Colors.amber.withValues(alpha: 0.1)
                  : isGood
                      ? Colors.green.withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              isExcellent
                  ? 'Excellent work! You\'ve mastered this skill!'
                  : isGood
                      ? 'Good job! Keep practicing to improve.'
                      : 'Keep learning! Practice makes perfect.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isExcellent
                    ? Colors.amber.shade700
                    : isGood
                        ? Colors.green.shade700
                        : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onExit,
                  child: const Text('Exit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onRestart,
                  child: const Text('Play Again'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/games_progress_service.dart';
import '../../../core/services/games_service.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  final _service = GamesService();
  final _progressService = GamesProgressService();

  List<Map<String, dynamic>> _games = [];
  List<Map<String, dynamic>> _modules = [];
  List<Map<String, dynamic>> _progress = [];
  List<Map<String, dynamic>> _achievements = [];
  List<Map<String, dynamic>> _earnedAchievements = [];
  bool _loading = true;
  String _selectedTab = 'games';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final games = await _service.listGames();
      final modules = await _service.listModules();
      final progress = await _loadProgress();
      final achievements = await _service.listAchievements();
      final earned = await _loadEarnedAchievements();

      if (!mounted) return;
      setState(() {
        _games = games;
        _modules = modules;
        _progress = progress;
        _achievements = achievements;
        _earnedAchievements = earned;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadProgress() async {
    final creator = await _progressService.currentCreator();
    if (creator == null) return [];
    return _service.listProgress(creator['id'] as String);
  }

  Future<List<Map<String, dynamic>>> _loadEarnedAchievements() async {
    final creator = await _progressService.currentCreator();
    if (creator == null) return [];
    return _service.listEarnedAchievements(creator['id'] as String);
  }

  @override
  Widget build(BuildContext context) {
    final games = _games.isEmpty ? _fallbackGames() : _games;
    final poemGames = games.where((g) => g['game_type'] == 'poem_next_line').toList();
    final blogGames = games.where((g) => g['game_type'] == 'blog_next_line').toList();
    final quizGames = games.where((g) => g['game_type'] == 'guess_next_line').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Games'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/more'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => context.push('/games/profile'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: _hero())),
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _starterCard())),
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _tabSwitcher())),
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _progressHeader(games.length))),
                if (_selectedTab == 'games') ...[
                  SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _modeCards(games))),
                  SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _section('Poetry Games', poemGames, playGames: true))),
                  SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _section('Blog Games', blogGames, playGames: true))),
                  SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _section('Quiz Games', quizGames, playGames: true))),
                ] else ...[
                  SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _section('Guides & Tutorials', _modules))),
                ],
              ],
            ),
    );
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(colors: [Color(0xFF111111), Color(0xFF2B1930)]),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Play, learn and improve.', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('Modes, streaks and progress all saved to your creator profile.', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );

  Widget _starterCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context).cardColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Start with a template', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Pick a preconfigured game and let Whispr generate the first challenge around it.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(label: const Text('Poetry prompt'), onPressed: () => _startGame(_fallbackGames().firstWhere((g) => g['game_type'] == 'poem_next_line'))),
                ActionChip(label: const Text('Blog prompt'), onPressed: () => _startGame(_fallbackGames().firstWhere((g) => g['game_type'] == 'blog_next_line'))),
                ActionChip(label: const Text('Quiz challenge'), onPressed: () => _startGame(_fallbackGames().firstWhere((g) => g['game_type'] == 'guess_next_line'))),
              ],
            ),
          ],
        ),
      );

  Widget _tabSwitcher() => Row(
        children: [
          ChoiceChip(label: const Text('Games'), selected: _selectedTab == 'games', onSelected: (_) => setState(() => _selectedTab = 'games')),
          const SizedBox(width: 8),
          ChoiceChip(label: const Text('Guides'), selected: _selectedTab == 'guides', onSelected: (_) => setState(() => _selectedTab = 'guides')),
        ],
      );

  Widget _modeCards(List<Map<String, dynamic>> games) {
    final cards = [
      ('Poetry', 'poem_next_line', Icons.format_quote, const Color(0xFF2A1B3D), 'Continue poetic lines'),
      ('Blogs', 'blog_next_line', Icons.article_outlined, const Color(0xFF17324D), 'Build clean paragraphs'),
      ('Quiz', 'guess_next_line', Icons.quiz_outlined, const Color(0xFF3B2A16), 'Pick the best next line'),
    ];

    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final card = cards[index];
          final game = games.firstWhere(
            (g) => g['game_type'] == card.$2,
            orElse: () => _fallbackGames().firstWhere((g) => g['game_type'] == card.$2),
          );

          return GestureDetector(
            onTap: () => _startGame(game),
            child: Container(
              width: 210,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [card.$4, card.$4.withValues(alpha: 0.65)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(card.$3, color: Colors.white, size: 28),
                  const Spacer(),
                  Text(card.$1, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(card.$5, style: TextStyle(color: Colors.white.withValues(alpha: 0.82))),
                  const SizedBox(height: 6),
                  if (card.$2 == 'guess_next_line')
                    const Text('Best for quick quizzes', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _progressHeader(int gamesCount) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text('Your Growth', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _metricCard('Games', '$gamesCount', Icons.games_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _metricCard('Modules', '${_modules.length}', Icons.menu_book_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _metricCard('Badges', '${_earnedAchievements.length}', Icons.emoji_events_outlined)),
            ],
          ),
          const SizedBox(height: 12),
          _achievementStrip(),
          const SizedBox(height: 12),
          _progressList(),
        ],
      );

  Widget _metricCard(String label, String value, IconData icon) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).cardColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );

  Widget _achievementStrip() {
    if (_achievements.isEmpty) {
      return const Text('No achievements yet. Play games to start tracking progress.');
    }

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _achievements.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final achievement = _achievements[index];
          final earned = _earnedAchievements.any((e) => e['achievement_id'] == achievement['id']);
          return Container(
            width: 220,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Theme.of(context).cardColor,
              border: Border.all(color: earned ? Colors.amber : Colors.transparent),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events_outlined, color: earned ? Colors.amber : Theme.of(context).iconTheme.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(achievement['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(earned ? 'Earned' : 'Locked', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _progressList() {
    if (_progress.isEmpty) {
      return const Text('No game sessions yet. Your stats will appear here after your first play.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ..._progress.take(3).map(
              (item) => Card(
                child: ListTile(
                  title: Text(item['game']?['title'] ?? 'Game'),
                  subtitle: Text('Best: ${item['best_score'] ?? 0}  •  Streak: ${item['best_streak'] ?? 0}  •  Sessions: ${item['completed_sessions'] ?? 0}'),
                  trailing: Text('${item['total_score'] ?? 0} pts'),
                ),
              ),
            ),
      ],
    );
  }

  Widget _section(String title, List<Map<String, dynamic>> items, {bool playGames = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Card(
              child: ListTile(
                onTap: playGames ? () => _startGame(item) : null,
                leading: CircleAvatar(child: Text((item['title'] ?? '?').toString().substring(0, 1))),
                title: Text(item['title'] ?? ''),
                subtitle: Text(item['description'] ?? item['summary'] ?? ''),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No items yet.'),
            ),
        ],
      );

  Future<void> _startGame(Map<String, dynamic> game) async {
    if (!mounted) return;
    await context.push('/games/play', extra: game);
  }

  List<Map<String, dynamic>> _fallbackGames() => [
        {
          'id': 'poem_next_line',
          'slug': 'poem_next_line',
          'title': 'Poetry Continuation',
          'description': 'Continue a poem with a vivid, emotionally consistent line.',
          'game_type': 'poem_next_line',
          'config': {'starter_prompt': 'A silver wind leans over the rooftops and the next line should feel lyrical.'},
        },
        {
          'id': 'blog_next_line',
          'slug': 'blog_next_line',
          'title': 'Blog Builder',
          'description': 'Continue a blog with a practical, vivid next line.',
          'game_type': 'blog_next_line',
          'config': {'starter_prompt': 'A smart blog intro explains why the topic matters before it teaches the reader.'},
        },
        {
          'id': 'guess_next_line',
          'slug': 'guess_next_line',
          'title': 'Guess the Next Line',
          'description': 'Choose the strongest continuation from a set of options.',
          'game_type': 'guess_next_line',
          'config': {'starter_prompt': 'Which line best continues a calm and thoughtful opening?'},
        },
        {
          'id': 'midnight-poem-flow',
          'slug': 'midnight-poem-flow',
          'title': 'Midnight Poem Flow',
          'description': 'A darker poetic continuation game with moonlit imagery.',
          'game_type': 'poem_next_line',
          'config': {'starter_prompt': 'The city sleeps under a violet moon and the next line should deepen the atmosphere.'},
        },
        {
          'id': 'garden-poem-walk',
          'slug': 'garden-poem-walk',
          'title': 'Garden Poem Walk',
          'description': 'A gentle, sensory poem continuation about growth and movement.',
          'game_type': 'poem_next_line',
          'config': {'starter_prompt': 'A small garden opens after the rain and the next line should feel alive.'},
        },
        {
          'id': 'opinion-blog-builder',
          'slug': 'opinion-blog-builder',
          'title': 'Opinion Blog Builder',
          'description': 'A sharper blog continuation game for opinion pieces and commentary.',
          'game_type': 'blog_next_line',
          'config': {'starter_prompt': 'A strong opinion blog opens with a clear claim and the next line should support it.'},
        },
        {
          'id': 'how-to-blog-builder',
          'slug': 'how-to-blog-builder',
          'title': 'How-To Blog Builder',
          'description': 'A practical blog continuation for tutorials and step-by-step posts.',
          'game_type': 'blog_next_line',
          'config': {'starter_prompt': 'The guide introduces a helpful task and the next line should explain the first step.'},
        },
        {
          'id': 'tone-match-quiz',
          'slug': 'tone-match-quiz',
          'title': 'Tone Match Quiz',
          'description': 'A quiz game that asks you to match tone and style.',
          'game_type': 'guess_next_line',
          'config': {'starter_prompt': 'Which line best matches the soft reflective tone?'},
        },
        {
          'id': 'context-quiz-shift',
          'slug': 'context-quiz-shift',
          'title': 'Context Quiz Shift',
          'description': 'A quiz game focused on preserving context across lines.',
          'game_type': 'guess_next_line',
          'config': {'starter_prompt': 'Which line best preserves the meaning of the sentence?'},
        },
      ];
}
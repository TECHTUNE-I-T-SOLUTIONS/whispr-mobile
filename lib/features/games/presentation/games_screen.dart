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
                  SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _allGamesSection(games))),
                ] else ...[
                  SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _section('Guides & Tutorials', _modules))),
                ],
              ],
            ),
    );
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.school,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Writing Mastery',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Learn writing principles through interactive challenges',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _starterCard() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context).cardColor,
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
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'AI-Powered Learning',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Get personalized hints and feedback as you master writing skills.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _quickStartChip('Word Choice', 'word_choice_wizard', Icons.spellcheck),
                _quickStartChip('Tone', 'tone_detective', Icons.tune),
                _quickStartChip('Show Don\'t Tell', 'show_dont_tell', Icons.visibility),
                _quickStartChip('Metaphors', 'metaphor_forge', Icons.compare_arrows),
                _quickStartChip('Dialogue', 'dialogue_dynamics', Icons.chat_bubble),
                _quickStartChip('Character', 'character_development', Icons.person),
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
      ('Word Choice', 'word_choice_wizard', Icons.spellcheck, Theme.of(context).colorScheme.primary, 'Master vocabulary precision', 'AI hints available'),
      ('Tone Detective', 'tone_detective', Icons.tune, Theme.of(context).colorScheme.secondary, 'Control voice and mood', 'AI feedback enabled'),
      ('Show Don\'t Tell', 'show_dont_tell', Icons.visibility, Theme.of(context).colorScheme.tertiary, 'Create vivid imagery', 'AI suggestions'),
      ('Metaphor Forge', 'metaphor_forge', Icons.compare_arrows, const Color(0xFF7C3AED), 'Build figurative language', 'AI-powered'),
      ('Sentence Lab', 'sentence_structure_lab', Icons.account_tree, const Color(0xFF059669), 'Understand syntax', 'AI explanations'),
      ('Pacing Master', 'pacing_master', Icons.speed, const Color(0xFFDC2626), 'Control story rhythm', 'AI analysis'),
      ('Dialogue Dynamics', 'dialogue_dynamics', Icons.chat_bubble, const Color(0xFF0891B2), 'Master dialogue craft', 'AI coaching'),
      ('Character Lab', 'character_development', Icons.person, const Color(0xFFEA580C), 'Create compelling characters', 'AI insights'),
      ('Setting the Scene', 'setting_scene', Icons.landscape, const Color(0xFF65A30D), 'Build immersive settings', 'AI guidance'),
      ('POV Mastery', 'pov_mastery', Icons.visibility, const Color(0xFF9333EA), 'Master perspectives', 'AI tips'),
      ('Plot Architect', 'plot_structure', Icons.account_tree, const Color(0xFFBE185D), 'Structure narratives', 'AI assistance'),
    ];

    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final card = cards[index];
          final game = games.firstWhere(
            (g) => g['slug'] == card.$2,
            orElse: () => _fallbackGames().firstWhere((g) => g['slug'] == card.$2, orElse: () => {'slug': card.$2, 'title': card.$1, 'description': card.$4, 'game_type': card.$2}),
          );

          return GestureDetector(
            onTap: () => _startGame(game),
            child: Container(
              width: 160,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [card.$4, card.$4.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: card.$4.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(card.$3, color: Colors.white, size: 24),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, color: Colors.white, size: 10),
                            const SizedBox(width: 2),
                            Text(
                              card.$6,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    card.$1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.$5,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 10,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
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

  Widget _allGamesSection(List<Map<String, dynamic>> games) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'All Games',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...games.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: ListTile(
                onTap: () => _startGame(item),
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (item['title'] ?? '?').toString().substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  item['title'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  item['description'] ?? item['summary'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          if (games.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No games yet.',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
        ],
      );

  Widget _quickStartChip(String label, String slug, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: () => _startGame(_fallbackGames().firstWhere((g) => g['slug'] == slug)),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onPrimaryContainer,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Future<void> _startGame(Map<String, dynamic> game) async {
    if (!mounted) return;
    // All games now use the educational game screen
    await context.push('/games/educational-play', extra: game);
  }

  List<Map<String, dynamic>> _fallbackGames() => [
        {
          'id': 'word_choice_wizard',
          'slug': 'word_choice_wizard',
          'title': 'Word Choice Wizard',
          'description': 'Choose the most precise and effective word for each context.',
          'game_type': 'word_choice',
          'config': {'topic': 'vocabulary precision'},
        },
        {
          'id': 'tone_detective',
          'slug': 'tone_detective',
          'title': 'Tone Detective',
          'description': 'Match sentences to their intended tone and audience.',
          'game_type': 'tone_matching',
          'config': {'topic': 'voice control'},
        },
        {
          'id': 'show_dont_tell',
          'slug': 'show_dont_tell',
          'title': 'Show, Don\'t Tell Studio',
          'description': 'Transform telling sentences into vivid showing ones.',
          'game_type': 'show_dont_tell',
          'config': {'topic': 'imagery and sensory details'},
        },
        {
          'id': 'metaphor_forge',
          'slug': 'metaphor_forge',
          'title': 'Metaphor Forge',
          'description': 'Create powerful metaphors that deepen meaning.',
          'game_type': 'metaphor_building',
          'config': {'topic': 'figurative language'},
        },
        {
          'id': 'sentence_structure_lab',
          'slug': 'sentence_structure_lab',
          'title': 'Sentence Structure Lab',
          'description': 'Identify and understand different sentence structures.',
          'game_type': 'sentence_structure',
          'config': {'topic': 'syntax awareness'},
        },
        {
          'id': 'pacing_master',
          'slug': 'pacing_master',
          'title': 'Pacing Master',
          'description': 'Arrange sentences to create different pacing effects.',
          'game_type': 'pacing_control',
          'config': {'topic': 'story rhythm'},
        },
        {
          'id': 'dialogue_dynamics',
          'slug': 'dialogue_dynamics',
          'title': 'Dialogue Dynamics',
          'description': 'Master the art of writing natural, engaging dialogue.',
          'game_type': 'dialogue_writing',
          'config': {'topic': 'dialogue craft'},
        },
        {
          'id': 'character_development',
          'slug': 'character_development',
          'title': 'Character Development Lab',
          'description': 'Create compelling, multi-dimensional characters.',
          'game_type': 'character_building',
          'config': {'topic': 'character creation'},
        },
        {
          'id': 'setting_scene',
          'slug': 'setting_scene',
          'title': 'Setting the Scene',
          'description': 'Create immersive settings that support story and mood.',
          'game_type': 'setting_craft',
          'config': {'topic': 'world building'},
        },
        {
          'id': 'pov_mastery',
          'slug': 'pov_mastery',
          'title': 'Point of View Mastery',
          'description': 'Understand and master different narrative perspectives.',
          'game_type': 'pov_control',
          'config': {'topic': 'narrative perspective'},
        },
        {
          'id': 'plot_structure',
          'slug': 'plot_structure',
          'title': 'Plot Structure Architect',
          'description': 'Understand story structure and create compelling narratives.',
          'game_type': 'plot_building',
          'config': {'topic': 'narrative structure'},
        },
      ];
}
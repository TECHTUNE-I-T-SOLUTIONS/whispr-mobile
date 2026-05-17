import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/games_progress_service.dart';
import '../../../core/services/games_service.dart';

class GameProfileScreen extends StatefulWidget {
  const GameProfileScreen({super.key});

  @override
  State<GameProfileScreen> createState() => _GameProfileScreenState();
}

class _GameProfileScreenState extends State<GameProfileScreen> {
  final _progressService = GamesProgressService();
  final _service = GamesService();
  List<Map<String, dynamic>> _progress = [];
  List<Map<String, dynamic>> _achievements = [];
  List<Map<String, dynamic>> _earned = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final creator = await _progressService.currentCreator();
    if (creator != null) {
      final progress = await _service.listProgress(creator['id'] as String);
      final achievements = await _service.listAchievements();
      final earned = await _service.listEarnedAchievements(creator['id'] as String);
      if (!mounted) return;
      setState(() {
        _progress = progress;
        _achievements = achievements;
        _earned = earned;
        _loading = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Profile'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _summaryCard(),
                const SizedBox(height: 16),
                const Text('Recent Progress', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                ..._progress.map(
                  (item) => Card(
                    child: ListTile(
                      title: Text((item['game'] as Map<String, dynamic>?)?['title'] ?? 'Game'),
                      subtitle: Text('Best: ${item['best_score'] ?? 0}  •  Streak: ${item['best_streak'] ?? 0}'),
                      trailing: Text('${item['total_score'] ?? 0} pts'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Badges', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                ..._achievements.map((achievement) {
                  final earned = _earned.any((e) => e['achievement_id'] == achievement['id']);
                  return Card(
                    child: ListTile(
                      leading: Icon(Icons.emoji_events_outlined, color: earned ? Colors.amber : null),
                      title: Text(achievement['title'] ?? ''),
                      subtitle: Text(earned ? 'Earned' : 'Locked'),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _summaryCard() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(colors: [Color(0xFF111111), Color(0xFF3A1B25)]),
        ),
        child: Row(
          children: [
            Expanded(child: _metric('Sessions', '${_progress.fold<int>(0, (sum, item) => sum + ((item['completed_sessions'] ?? 0) as num).toInt())}')),
            const SizedBox(width: 10),
            Expanded(child: _metric('Badges', '${_earned.length}')),
            const SizedBox(width: 10),
            Expanded(child: _metric('Games', '${_progress.length}')),
          ],
        ),
      );

  Widget _metric(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        ],
      );
}

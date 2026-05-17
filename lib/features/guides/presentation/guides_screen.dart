import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/games_progress_service.dart';
import '../../../core/services/games_service.dart';
import '../../../core/network/api_service.dart';

class GuidesScreen extends StatefulWidget {
  const GuidesScreen({super.key});

  @override
  State<GuidesScreen> createState() => _GuidesScreenState();
}

class _GuidesScreenState extends State<GuidesScreen> {
  final _service = GamesService();
  final _progress = GamesProgressService();
  List<Map<String, dynamic>> _modules = [];
  bool _loading = true;
  bool _generating = false;
  String? _error;
  String _query = '';
  String _category = 'all';
  List<Map<String, dynamic>> _history = [];
  String? _selectedTopic;
  final List<Map<String, String>> _topicOptions = const [
    {'label': 'Poetry Basics', 'category': 'poet'},
    {'label': 'Metaphor and Imagery', 'category': 'poet'},
    {'label': 'Opening Lines', 'category': 'poet'},
    {'label': 'Closing Lines', 'category': 'poet'},
    {'label': 'Creative Confidence', 'category': 'all'},
    {'label': 'Blog Structure', 'category': 'blogger'},
    {'label': 'Narrative Flow', 'category': 'blogger'},
    {'label': 'Tone and Voice', 'category': 'blogger'},
    {'label': 'Editing Tips', 'category': 'all'},
    {'label': 'Writing Habits', 'category': 'all'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final modules = await _service.listModules();
      final creator = await _progress.currentCreator();
      final history = creator == null
          ? <Map<String, dynamic>>[]
          : modules
              .where((m) => m['created_by'] == creator['id'] && (m['is_ai_supported'] == true))
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
      if (!mounted) return;
      setState(() {
        _modules = modules;
        _history = history;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _generateGuide(String topic) async {
    if (_generating) return;
    setState(() => _generating = true);
    _showGeneratingDialog(topic);
    try {
      final result = await ApiService.instance.post('/guides/generate', data: {'topic': topic, 'audience': 'all'});
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).maybePop();
      final module = result['module'] as Map<String, dynamic>?;
      if (module == null) {
        throw Exception('Guide generation did not return a guide.');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generated guide for $topic')),
      );
      setState(() {
        _modules = [module, ..._modules];
        _history = [module, ..._history];
        _selectedTopic = topic;
      });
      await context.push('/guides/${module['id']}');
      await _load();
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate guide: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  void _showGeneratingDialog(String topic) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Generating guide'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Whispr is building a guide for "$topic" using Gemini Flash Lite.'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _modules.where((m) {
      final title = (m['title'] ?? '').toString().toLowerCase();
      final summary = (m['summary'] ?? '').toString().toLowerCase();
      final topic = (m['topic'] ?? '').toString().toLowerCase();
      final matchesQuery = _query.isEmpty || title.contains(_query.toLowerCase()) || summary.contains(_query.toLowerCase()) || topic.contains(_query.toLowerCase());
      final audience = (m['audience'] ?? 'all').toString();
      final matchesCategory = _category == 'all' ||
          (_category == 'all_creators' && audience == 'all') ||
          audience == _category;
      return matchesQuery && matchesCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guides & Tutorials'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/more'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: const [
                  _GuideSkeletonHero(),
                  SizedBox(height: 16),
                  _GuideSkeletonBlock(height: 48),
                  SizedBox(height: 12),
                  _GuideSkeletonBlock(height: 56),
                  SizedBox(height: 12),
                  _GuideSkeletonBlock(height: 56),
                  SizedBox(height: 16),
                  _GuideSkeletonBlock(height: 100),
                  SizedBox(height: 12),
                  _GuideSkeletonBlock(height: 100),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(colors: [Color(0xFF111111), Color(0xFF1E2430)]),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Learn the craft', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                      SizedBox(height: 8),
                      Text('Articles, history, and AI-backed help for poets and bloggers.', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search topics, ideas, and techniques',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'poet', child: Text('Poet')),
                    DropdownMenuItem(value: 'blogger', child: Text('Blogger')),
                    DropdownMenuItem(value: 'all_creators', child: Text('All Creators')),
                  ],
                  onChanged: (value) => setState(() => _category = value ?? 'all'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedTopic,
                  decoration: InputDecoration(
                    labelText: 'Suggested Topic',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  items: _topicOptions
                      .map((topic) => DropdownMenuItem<String>(
                            value: topic['label'],
                            child: Text('${topic['label']} • ${topic['category']}'),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedTopic = value),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Could not load guides', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(_error!, style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 12),
                          TextButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    ),
                  ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome),
                    title: const Text('Generate a guide'),
                    subtitle: Text(_selectedTopic == null
                        ? 'Pick a topic and let AI build the guide outline and sections.'
                        : 'Generate a guide for $_selectedTopic.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _generating ? null : () => _generateGuide(_selectedTopic ?? 'Creative Writing'),
                  ),
                ),
                const SizedBox(height: 8),
                if (_generating) const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _topicChip('Poetry basics'),
                    _topicChip('Blog structure'),
                    _topicChip('Creative writing'),
                    _topicChip('Finding your voice'),
                    _topicChip('Editing tips'),
                    _topicChip('Writing habits'),
                    _topicChip('Metaphor and imagery'),
                    _topicChip('Narrative flow'),
                    _topicChip('Opening lines'),
                    _topicChip('Closing lines'),
                    _topicChip('Tone and voice'),
                    _topicChip('Creative confidence'),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Guide History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (_history.isEmpty)
                  const Text('Your generated guides will appear here.')
                else
                  ..._history.take(5).map((m) => Card(
                        child: ListTile(
                          onTap: () => context.go('/guides/${m['id']}'),
                          title: Text(m['title'] ?? ''),
                          subtitle: Text(m['summary'] ?? ''),
                          trailing: const Icon(Icons.history),
                        ),
                      )),
                const SizedBox(height: 16),
                const Text('Browse Guides', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ...filtered.map((m) => Card(
                      child: ListTile(
                        onTap: () => context.go('/guides/${m['id']}'),
                        title: Text(m['title'] ?? ''),
                        subtitle: Text(m['summary'] ?? ''),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    )),
                ],
              ),
      ),
    );
  }

  Widget _topicChip(String label) => ActionChip(
        label: Text(label),
        onPressed: () => _generateGuide(label),
      );
}

class _GuideSkeletonHero extends StatelessWidget {
  const _GuideSkeletonHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }
}

class _GuideSkeletonBlock extends StatelessWidget {
  final double height;
  const _GuideSkeletonBlock({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }
}

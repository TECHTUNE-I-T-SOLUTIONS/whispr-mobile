import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/games_service.dart';

class GuideDetailScreen extends StatefulWidget {
  final String moduleId;
  const GuideDetailScreen({super.key, required this.moduleId});

  @override
  State<GuideDetailScreen> createState() => _GuideDetailScreenState();
}

class _GuideDetailScreenState extends State<GuideDetailScreen> {
  final _service = GamesService();
  List<Map<String, dynamic>> _sections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sections = await _service.listSections(widget.moduleId);
    if (!mounted) return;
    setState(() {
      _sections = sections;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guide'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/guides'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _sections
                  .map((s) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              Text(s['body'] ?? ''),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}

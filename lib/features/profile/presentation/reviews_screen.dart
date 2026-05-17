import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_service.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final response = await ApiService.instance.get('/chronicles/creator/posts');
    final posts = (response['posts'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e)).toList();
    if (!mounted) return;
    setState(() {
      _posts = posts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'all'
        ? _posts
        : _posts.where((p) {
            final status = (p['flagStatus'] ?? p['status'] ?? '').toString();
            if (_filter == 'flagged') return (p['isFlagged'] == true) || status == 'pending' || status == 'under_review';
            if (_filter == 'published') return (p['status'] ?? '').toString() == 'published';
            if (_filter == 'drafts') return (p['status'] ?? '').toString() == 'draft';
            return true;
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviews & Appeals'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/more')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(label: const Text('All'), selected: _filter == 'all', onSelected: (_) => setState(() => _filter = 'all')),
                      ChoiceChip(label: const Text('Flagged'), selected: _filter == 'flagged', onSelected: (_) => setState(() => _filter = 'flagged')),
                      ChoiceChip(label: const Text('Published'), selected: _filter == 'published', onSelected: (_) => setState(() => _filter = 'published')),
                      ChoiceChip(label: const Text('Drafts'), selected: _filter == 'drafts', onSelected: (_) => setState(() => _filter = 'drafts')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...filtered.map((post) => Card(
                        child: ListTile(
                          title: Text(post['title'] ?? ''),
                          subtitle: Text('${post['status'] ?? 'draft'}${post['isFlagged'] == true ? ' • flagged' : ''}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'appeal' && post['slug'] != null) {
                                await ApiService.instance.post('/chronicles/posts/${post['slug']}/appeal');
                                await _load();
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'appeal', child: Text('Appeal review')),
                            ],
                          ),
                          onTap: () => context.push('/reviews/detail', extra: post),
                        ),
                      )),
                ],
              ),
            ),
    );
  }
}

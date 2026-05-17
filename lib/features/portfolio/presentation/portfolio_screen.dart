import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_service.dart';
import '../../../core/services/content_cache_service.dart';
import '../../../core/services/portfolio_service.dart';

final _portfolioServiceProvider = Provider((ref) => PortfolioService(ApiService.instance, ContentCacheService()));

class PortfolioScreen extends ConsumerStatefulWidget {
  final String penName;
  const PortfolioScreen({super.key, required this.penName});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await ref.read(_portfolioServiceProvider).getPortfolioByPenName(widget.penName);
    setState(() { _data = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final creator = _data?['creator'] as Map<String, dynamic>?;
    final posts = (_data?['posts'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.penName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/more'),
        ),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (creator != null) _Header(creator: creator),
          const SizedBox(height: 16),
          const Text('Latest Publications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ...posts.map((p) => _PostTile(post: Map<String, dynamic>.from(p))),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Map<String, dynamic> creator;
  const _Header({required this.creator});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: const LinearGradient(colors: [Color(0xFF111111), Color(0xFF4B1717)])),
    child: Row(children: [
      CircleAvatar(radius: 34, backgroundImage: creator['profile_image_url'] != null ? CachedNetworkImageProvider(creator['profile_image_url']) : null, child: creator['profile_image_url'] == null ? Text((creator['pen_name'] ?? 'W')[0], style: const TextStyle(fontSize: 24, color: Colors.white)) : null),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(creator['pen_name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(creator['bio'] ?? '', style: const TextStyle(color: Colors.white70)),
      ])),
    ]),
  );
}

class _PostTile extends StatelessWidget {
  final Map<String, dynamic> post;
  const _PostTile({required this.post});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(22)),
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      title: Text(post['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(post['excerpt'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.open_in_new),
    ),
  );
}

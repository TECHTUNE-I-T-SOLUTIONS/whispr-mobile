import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/post.dart';
import '../../../core/services/chronicles_service.dart';
import '../../../core/services/content_cache_service.dart';
import '../../../core/network/api_service.dart';

final _chroniclesServiceProvider = Provider((ref) => ChroniclesService(ApiService.instance, ContentCacheService()));

class ChroniclesScreen extends ConsumerStatefulWidget {
  const ChroniclesScreen({super.key});

  @override
  ConsumerState<ChroniclesScreen> createState() => _ChroniclesScreenState();
}

class _ChroniclesScreenState extends ConsumerState<ChroniclesScreen> {
  List<Post> _posts = [];
  List<Post> _myPosts = [];
  bool _loading = true;
  String _tab = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await ref.read(_chroniclesServiceProvider).getPublicChronicles();
      List<dynamic> mine = const [];
      try {
        mine = await ref.read(_chroniclesServiceProvider).getCreatorPosts();
      } catch (_) {
        mine = const [];
      }
      if (!mounted) return;
      setState(() {
        _posts = data.map((e) => Post.fromJson(Map<String, dynamic>.from(e))).toList();
        _myPosts = mine.map((e) => Post.fromJson(Map<String, dynamic>.from(e))).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _tab == 'all'
        ? _posts
        : _posts.where((p) => p.type == _tab).toList();
    final myChronicles = _myPosts;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chronicles'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/more'),
        ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => context.go('/chronicles/create'), child: const Icon(Icons.edit)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(spacing: 8, children: [
                  _chip('All', _tab == 'all', () => setState(() => _tab = 'all')),
                  _chip('Poems', _tab == 'poem', () => setState(() => _tab = 'poem')),
                  _chip('Blogs', _tab == 'blog', () => setState(() => _tab = 'blog')),
                  _chip('My Chronicles', _tab == 'mine', () => setState(() => _tab = 'mine')),
                ]),
              ),
            ),
            if (_loading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const _SkeletonCard(),
                  childCount: 4,
                ),
              )
            else if (_tab == 'mine' ? myChronicles.isEmpty : filtered.isEmpty)
              const SliverFillRemaining(child: Center(child: Text('No chronicles yet')))
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _Card(post: _tab == 'mine' ? myChronicles[i] : filtered[i]),
                  childCount: _tab == 'mine' ? myChronicles.length : filtered.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) => ChoiceChip(label: Text(label), selected: active, onSelected: (_) => onTap());
}

class _Card extends StatelessWidget {
  final Post post;
  const _Card({required this.post});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: InkWell(
        onTap: () => context.go('/chronicles/${post.id}'),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), color: Theme.of(context).cardColor),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 240,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (post.coverImage != null)
                  CachedNetworkImage(imageUrl: post.coverImage!, fit: BoxFit.cover)
                else
                  Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withValues(alpha: 0.05), Colors.black.withValues(alpha: 0.78)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),
                        Text(post.type.toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(post.excerpt ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        Text(post.author.name, style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: base.withValues(alpha: 0.72)),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(height: 14, width: 90, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 10),
                  Container(height: 24, width: 180, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 10),
                  Container(height: 14, width: double.infinity, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 6),
                  Container(height: 14, width: 140, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/layout.dart';
import '../../../core/models/post.dart';
import '../../../core/network/api_service.dart';
import '../../../core/services/chronicles_service.dart';
import '../../../core/services/content_cache_service.dart';

final _chroniclesServiceProvider = Provider(
  (ref) => ChroniclesService(ApiService.instance, ContentCacheService()),
);

/// A content-first browser for every published chronicle, grouped by the
/// category its author chose. The list on the main Chronicles screen is a
/// format filter (poem/blog); this screen is the subject-matter browser.
class ChronicleCategoriesScreen extends ConsumerStatefulWidget {
  const ChronicleCategoriesScreen({super.key});

  @override
  ConsumerState<ChronicleCategoriesScreen> createState() => _ChronicleCategoriesScreenState();
}

class _ChronicleCategoriesScreenState extends ConsumerState<ChronicleCategoriesScreen> {
  List<Post> _posts = const [];
  List<String> _categories = const [];
  String? _selected;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(_chroniclesServiceProvider);
      final results = await Future.wait([
        service.getPublicChronicles(forceRefresh: true),
        service.getChronicleCategories(),
      ]);
      final posts = (results[0])
          .map((e) => Post.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final apiCategories = (results[1]).map((e) => e.toString()).where((e) => e.isNotEmpty);
      final derived = posts
          .map((post) => post.category)
          .whereType<String>()
          .where((category) => category.isNotEmpty);
      final categories = <String>{...apiCategories, ...derived}.toList()..sort();

      if (!mounted) return;
      setState(() {
        _posts = posts;
        _categories = categories;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[ChronicleCategories] $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load chronicles. Pull down to try again.';
      });
    }
  }

  List<Post> get _visible {
    final selected = _selected;
    if (selected == null) return _posts;
    return _posts
        .where((post) => post.category?.toLowerCase() == selected.toLowerCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chronicle categories'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/chronicles'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Browse blogs, poems and stories by the world they belong to.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ChoiceChip(
                        label: const Text('All'),
                        selected: _selected == null,
                        onSelected: (_) => setState(() => _selected = null),
                      );
                    }
                    final category = _categories[index - 1];
                    return ChoiceChip(
                      label: Text(category),
                      selected: _selected == category,
                      onSelected: (_) => setState(() => _selected = category),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  _selected == null ? 'All chronicles (${visible.length})' : '$_selected (${visible.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            if (_loading && _posts.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (visible.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _selected == null
                          ? 'No published chronicles yet.'
                          : 'Nothing published under $_selected yet.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: visible.length,
                itemBuilder: (context, index) => _CategoryCard(post: visible[index]),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: kBottomNavClearance)),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Post post;
  const _CategoryCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push('/chronicles/${post.id}'),
        child: Container(
          height: 128,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 118,
                child: post.coverImage != null
                    ? CachedNetworkImage(imageUrl: post.coverImage!, fit: BoxFit.cover, height: double.infinity)
                    : Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [post.category, post.type].where((e) => e != null && e.isNotEmpty).join(' · ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Text(
                        'by ${post.author.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

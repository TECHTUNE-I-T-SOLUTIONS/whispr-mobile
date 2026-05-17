import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/chains_service.dart';
import '../../../core/services/content_cache_service.dart';
import '../../../core/network/api_service.dart';

final _chainsServiceProvider = Provider((ref) => ChainsService(ApiService.instance, ContentCacheService()));

class WritingChainsScreen extends ConsumerStatefulWidget {
  const WritingChainsScreen({super.key});

  @override
  ConsumerState<WritingChainsScreen> createState() => _WritingChainsScreenState();
}

class _WritingChainsScreenState extends ConsumerState<WritingChainsScreen> {
  List<dynamic> _chains = [];
  List<dynamic> _myChains = [];
  bool _loading = true;
  String _tab = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final chains = await ref.read(_chainsServiceProvider).getChains();
    final myChains = await ref.read(_chainsServiceProvider).getMyWritings();
    setState(() {
      _chains = chains.where((chain) {
        final map = chain as Map<String, dynamic>;
        final status = (map['status'] ?? 'published').toString();
        return status == 'published';
      }).toList();
      _myChains = myChains;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Writing Chains'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/more'),
        ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => context.go('/writing-chains/create'), child: const Icon(Icons.add)),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(label: const Text('All Chains'), selected: _tab == 'all', onSelected: (_) => setState(() => _tab = 'all')),
                  ChoiceChip(label: const Text('My Writings'), selected: _tab == 'mine', onSelected: (_) => setState(() => _tab = 'mine')),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if ((_tab == 'mine' ? _myChains : _chains).isEmpty)
            const SliverFillRemaining(child: Center(child: Text('No writing chains yet')))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _ChainCard(chain: Map<String, dynamic>.from((_tab == 'mine' ? _myChains : _chains)[i])),
                childCount: (_tab == 'mine' ? _myChains : _chains).length,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChainCard extends StatelessWidget {
  final Map<String, dynamic> chain;
  const _ChainCard({required this.chain});
  @override
  Widget build(BuildContext context) {
    final canEdit = chain['can_edit'] == true;
    final isOwner = chain['is_owner'] == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: InkWell(
        onTap: () => context.go('/writing-chains/${chain['id']}'),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: Theme.of(context).cardColor),
          child: Row(children: [
            Container(width: 56, height: 56, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.link_outlined)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: [
                  Expanded(child: Text(chain['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
                  if (canEdit)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'manage') {
                          context.go('/writing-chains/${chain['id']}');
                        } else if (value == 'edit_latest') {
                          final entries = (chain['entries'] as List?) ?? const [];
                          Map<String, dynamic>? post;
                          for (final entry in entries) {
                            final entryMap = entry is Map ? Map<String, dynamic>.from(entry) : null;
                            final candidate = entryMap?['post'];
                            if (candidate is Map<String, dynamic>) {
                              post = candidate;
                              break;
                            }
                          }
                          if (post != null && post['id'] != null) {
                            context.go('/writing-chains/${chain['id']}/edit-entry/${post['id']}', extra: {
                              'chainTitle': chain['title'],
                              'fromContributorMenu': true,
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No editable entry found for this chain yet.')),
                            );
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'manage', child: Text('Manage Entries')),
                        if (isOwner)
                          const PopupMenuItem(value: 'edit_latest', child: Text('Edit Latest Entry')),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(chain['description'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
              if (canEdit) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Chip(label: Text(isOwner ? 'Owner' : 'Contributor'), visualDensity: VisualDensity.compact),
                    if ((chain['contribution_count'] ?? 0) > 0)
                      Chip(label: Text('${chain['contribution_count']} entries'), visualDensity: VisualDensity.compact),
                  ],
                ),
              ],
            ])),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}

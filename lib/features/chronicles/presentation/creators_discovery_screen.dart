import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/chronicles_service.dart';
import '../../../core/services/content_cache_service.dart';
import '../../../core/network/api_service.dart';

final _chroniclesServiceProvider = Provider((ref) => ChroniclesService(ApiService.instance, ContentCacheService()));

class CreatorsDiscoveryScreen extends ConsumerStatefulWidget {
  const CreatorsDiscoveryScreen({super.key});

  @override
  ConsumerState<CreatorsDiscoveryScreen> createState() => _CreatorsDiscoveryScreenState();
}

class _CreatorsDiscoveryScreenState extends ConsumerState<CreatorsDiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _creators = [];
  List<dynamic> _filteredCreators = [];
  bool _loading = true;
  String _error = '';
  String _selectedCategory = 'all';
  String _selectedContentType = 'all';
  String _sortBy = 'recent';

  @override
  void initState() {
    super.initState();
    _loadCreators();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCreators() async {
    try {
      setState(() => _loading = true);
      final service = ref.read(_chroniclesServiceProvider);
      final creators = await service.getCreatorsDiscover();
      if (!mounted) return;
      setState(() {
        _creators = creators;
        _filteredCreators = creators;
        _loading = false;
        _error = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load creators';
        _creators = [];
        _filteredCreators = [];
      });
    }
  }

  void _applyFilters() {
    var filtered = List<dynamic>.from(_creators);

    // Search filter
    if (_searchController.text.isNotEmpty) {
      final search = _searchController.text.toLowerCase();
      filtered = filtered.where((creator) {
        final map = creator is Map ? creator : Map<String, dynamic>.from(creator);
        final penName = (map['pen_name'] ?? '').toString().toLowerCase();
        final bio = (map['bio'] ?? '').toString().toLowerCase();
        final categories = (map['categories'] as List? ?? []).map((c) => c.toString().toLowerCase()).toList();
        
        return penName.contains(search) ||
               bio.contains(search) ||
               categories.any((cat) => cat.contains(search));
      }).toList();
    }

    // Category filter
    if (_selectedCategory != 'all') {
      filtered = filtered.where((creator) {
        final map = creator is Map ? creator : Map<String, dynamic>.from(creator);
        final categories = (map['categories'] as List? ?? []).map((c) => c.toString()).toList();
        return categories.contains(_selectedCategory);
      }).toList();
    }

    // Content type filter
    if (_selectedContentType != 'all') {
      filtered = filtered.where((creator) {
        final map = creator is Map ? creator : Map<String, dynamic>.from(creator);
        final contentType = (map['content_type'] ?? '').toString();
        return contentType == _selectedContentType;
      }).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'followers':
        filtered.sort((a, b) {
          final aFollowers = (a is Map ? a['followers_count'] : 0) as int? ?? 0;
          final bFollowers = (b is Map ? b['followers_count'] : 0) as int? ?? 0;
          return bFollowers.compareTo(aFollowers);
        });
        break;
      case 'engagement':
        filtered.sort((a, b) {
          final aEngagement = (a is Map ? a['engagement_count'] : 0) as int? ?? 0;
          final bEngagement = (b is Map ? b['engagement_count'] : 0) as int? ?? 0;
          return bEngagement.compareTo(aEngagement);
        });
        break;
      case 'posts':
        filtered.sort((a, b) {
          final aPosts = (a is Map ? a['post_count'] : 0) as int? ?? 0;
          final bPosts = (b is Map ? b['post_count'] : 0) as int? ?? 0;
          return bPosts.compareTo(aPosts);
        });
        break;
      case 'recent':
      default:
        // Keep original order
        break;
    }

    setState(() => _filteredCreators = filtered);
  }

  Future<void> _handleFollow(String creatorId) async {
    try {
      final service = ref.read(_chroniclesServiceProvider);
      final result = await service.followCreator(creatorId);
      
      if (!mounted) return;
      
      // Update local state
      setState(() {
        _creators = _creators.map((creator) {
          final map = creator is Map ? creator : Map<String, dynamic>.from(creator);
          if (map['id'] == creatorId) {
            final updated = Map<String, dynamic>.from(map);
            updated['is_following'] = result['following'] ?? false;
            return updated;
          }
          return creator;
        }).toList();
      });
      
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to follow creator: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Creators'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search creators...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (_) => _applyFilters(),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filters
          _buildFilters(context),
          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadCreators,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredCreators.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: isDark ? Colors.white24 : Colors.black12,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _creators.isEmpty ? 'No creators found' : 'No creators match your filters',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredCreators.length,
                            itemBuilder: (context, index) {
                              final creator = _filteredCreators[index];
                              return _CreatorCard(
                                creator: creator,
                                onFollow: _handleFollow,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final categories = [
      'all',
      'Fiction',
      'Poetry',
      'Non-Fiction',
      'Fantasy',
      'Romance',
      'Sci-Fi',
      'Mystery',
      'Thriller',
      'Horror',
      'Biography',
      'Self-Help',
    ];

    final contentTypes = ['all', 'Short Stories', 'Novels', 'Poetry', 'Essays', 'Articles'];

    final sortOptions = [
      'recent',
      'followers',
      'engagement',
      'posts',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat == 'all' ? 'All' : cat),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedCategory = cat);
                      _applyFilters();
                    },
                    selectedColor: Theme.of(context).colorScheme.primary,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Content type and sort
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedContentType,
                  decoration: const InputDecoration(
                    labelText: 'Content Type',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: contentTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type == 'all' ? 'All Types' : type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedContentType = value);
                      _applyFilters();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _sortBy,
                  decoration: const InputDecoration(
                    labelText: 'Sort By',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: sortOptions.map((option) {
                    return DropdownMenuItem(
                      value: option,
                      child: Text(_getSortLabel(option)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _sortBy = value);
                      _applyFilters();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getSortLabel(String value) {
    switch (value) {
      case 'followers':
        return 'Most Followers';
      case 'engagement':
        return 'Most Engagement';
      case 'posts':
        return 'Most Posts';
      case 'recent':
      default:
        return 'Most Recent';
    }
  }
}

class _CreatorCard extends StatelessWidget {
  final dynamic creator;
  final Function(String) onFollow;

  const _CreatorCard({
    required this.creator,
    required this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    final map = creator is Map ? creator : Map<String, dynamic>.from(creator);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final penName = map['pen_name'] ?? 'Unknown';
    final bio = map['bio'] ?? '';
    final profilePictureUrl = map['profile_picture_url'];
    final isVerified = map['verified_badge'] ?? false;
    final location = map['location'];
    final postCount = map['post_count'] ?? 0;
    final engagementCount = map['engagement_count'] ?? 0;
    final followersCount = map['followers_count'] ?? 0;
    final isFollowing = map['is_following'] ?? false;
    final categories = (map['categories'] as List? ?? []).map((c) => c.toString()).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Profile picture
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              profilePictureUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Text(
                                    penName.isNotEmpty ? penName[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Text(
                              penName.isNotEmpty ? penName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  // Name and bio
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                penName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (isVerified)
                              const Icon(
                                Icons.verified,
                                color: Colors.blue,
                                size: 18,
                              ),
                          ],
                        ),
                        if (location != null && location.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          bio,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Categories
              if (categories.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: categories.take(3).map((cat) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (categories.length > 3)
                  Text(
                    '+${categories.length - 3} more',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              // Stats
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Posts',
                      value: postCount.toString(),
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      label: 'Engagement',
                      value: engagementCount.toString(),
                      color: Colors.pink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      label: 'Followers',
                      value: followersCount.toString(),
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => onFollow(map['id']),
                      style: FilledButton.styleFrom(
                        backgroundColor: isFollowing
                            ? null
                            : Theme.of(context).colorScheme.primary,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isFollowing ? Icons.check : Icons.person_add, size: 18),
                          const SizedBox(width: 8),
                          Text(isFollowing ? 'Following' : 'Follow'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      // Navigate to creator profile
                      context.push('/portfolio/$penName');
                    },
                    icon: const Icon(Icons.book_outlined),
                    tooltip: 'View Portfolio',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}

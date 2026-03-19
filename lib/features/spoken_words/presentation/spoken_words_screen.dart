import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

import '../../../core/models/spoken_word.dart';
import '../../../core/network/api_service.dart';

class SpokenWordsScreen extends ConsumerStatefulWidget {
  const SpokenWordsScreen({super.key});

  @override
  ConsumerState<SpokenWordsScreen> createState() => _SpokenWordsScreenState();
}

class _SpokenWordsScreenState extends ConsumerState<SpokenWordsScreen>
    with TickerProviderStateMixin {
  List<SpokenWord> _spokenWords = [];
  bool _isLoading = true;
  String? _error;
  String _selectedType = 'all';
  final Set<String> _expandedItems = {};
  SharedPreferences? _prefs;
  static const String _cacheKey = 'spoken_words_cache';
  static const String _cacheTimeKey = 'spoken_words_cache_time';
  static const Duration _cacheDuration = Duration(minutes: 10);

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initPrefs().then((_) => _loadCachedSpokenWords());
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> _loadCachedSpokenWords() async {
    if (_prefs == null) return;

    try {
      final cachedData = _prefs!.getString(_cacheKey);
      final cacheTime = _prefs!.getInt(_cacheTimeKey);

      if (cachedData != null && cacheTime != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTime;
        if (cacheAge < _cacheDuration.inMilliseconds) {
          final List<dynamic> jsonList = json.decode(cachedData);
          if (mounted) {
            setState(() {
              _spokenWords = jsonList.map((json) => SpokenWord.fromJson(json)).toList();
              _isLoading = false;
            });
          }
          _scaleController.forward();
          return;
        }
      }
    } catch (e) {
      debugPrint('Error loading cached spoken words: $e');
    }

    _loadSpokenWords();
  }

  Future<void> _loadSpokenWords() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get('/spoken-words');

      if (response['spokenWords'] != null) {
        final List<dynamic> spokenWordsJson = response['spokenWords'];
        final spokenWords = spokenWordsJson.map((json) => SpokenWord.fromJson(json)).toList();

        // Cache the data
        if (_prefs != null) {
          await _prefs!.setString(_cacheKey, json.encode(spokenWordsJson));
          await _prefs!.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
        }

        if (mounted) {
          setState(() {
            _spokenWords = spokenWords;
            _isLoading = false;
          });
        }
        _scaleController.forward();
      } else {
        if (mounted) {
          setState(() {
            _error = 'No spoken words found';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Network error. Please check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  void _filterByType(String type) {
    if (mounted) {
      setState(() {
        _selectedType = type;
      });
    }
  }

  List<SpokenWord> get _filteredSpokenWords {
    if (_selectedType == 'all') return _spokenWords;
    return _spokenWords.where((word) => word.type == _selectedType).toList();
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareSpokenWord(SpokenWord word) async {
    final String baseUrl = 'https://whisprwords.vercel.app';
    final url = '$baseUrl/spoken-words/${word.id}';

    await Share.share(
      'Check out this spoken word: ${word.title}\n$url',
      subject: word.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spoken Words'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/more'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSpokenWords,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          );
        },
        child: Column(
          children: [
            // Filter tabs
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Audio', 'audio'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Video', 'video'),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildErrorView()
                      : _filteredSpokenWords.isEmpty
                          ? _buildEmptyView()
                          : _buildSpokenWordsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String type) {
    final isSelected = _selectedType == type;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _filterByType(type),
        backgroundColor: isSelected
            ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
            : Theme.of(context).cardColor,
        selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
        checkmarkColor: Theme.of(context).primaryColor,
        labelStyle: TextStyle(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadSpokenWords,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.audiotrack,
            size: 64,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No spoken words found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new content',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpokenWordsList() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredSpokenWords.length,
        itemBuilder: (context, index) {
          final word = _filteredSpokenWords[index];
          return _buildSpokenWordCard(word);
        },
      ),
    );
  }

  Widget _buildSpokenWordCard(SpokenWord word) {
    final isExpanded = _expandedItems.contains(word.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _toggleExpansion(word.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with type indicator
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: word.type == 'video'
                          ? Colors.red.withValues(alpha: 0.1)
                          : Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          word.type == 'video' ? Icons.videocam : Icons.audiotrack,
                          size: 16,
                          color: word.type == 'video' ? Colors.red : Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          word.type.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: word.type == 'video' ? Colors.red : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () => _shareSpokenWord(word),
                    iconSize: 20,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Title
              Text(
                word.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              if (word.description != null && word.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  word.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: isExpanded ? null : 2,
                  overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),

              // Media preview
              if (word.mediaUrl != null) ...[
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (word.thumbnailUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: word.thumbnailUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) => Container(
                              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                              child: Icon(
                                word.type == 'video' ? Icons.videocam : Icons.audiotrack,
                                size: 32,
                                color: Theme.of(context).disabledColor,
                              ),
                            ),
                          ),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          word.type == 'video' ? Icons.play_arrow : Icons.play_circle,
                          size: 48,
                          color: Colors.white,
                        ),
                        onPressed: () => _launchUrl(word.mediaUrl!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Footer with stats and actions
              Row(
                children: [
                  if (word.duration != null) ...[
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(word.duration!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (word.viewCount != null) ...[
                    Icon(
                      Icons.visibility,
                      size: 16,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${word.viewCount}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () => _launchUrl(word.mediaUrl ?? 'https://whispr.vercel.app/spoken-words'),
                    child: const Text('Listen/Watch'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleExpansion(String id) {
    if (mounted) {
      setState(() {
        if (_expandedItems.contains(id)) {
          _expandedItems.remove(id);
        } else {
          _expandedItems.add(id);
        }
      });
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
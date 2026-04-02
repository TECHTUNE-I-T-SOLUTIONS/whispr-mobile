import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../../core/network/api_service.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

// Simple NLP keyword extraction utility
class KeywordExtractor {
  static const _stopWords = {
    'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of',
    'with', 'is', 'are', 'am', 'was', 'were', 'be', 'been', 'by', 'from', 'as',
    'if', 'this', 'that', 'these', 'those', 'i', 'you', 'he', 'she', 'it',
    'we', 'they', 'what', 'which', 'who', 'when', 'where', 'why', 'how',
    'can', 'could', 'should', 'would', 'do', 'does', 'did', 'will', 'shall',
    'me', 'him', 'her', 'us', 'them', 'my', 'your', 'his', 'its', 'our',
    'their', 'write', 'writing', 'create', 'creating', 'please', 'help',
    'about', 'get', 'make', 'use', 'just', 'need', 'want', 'like', 'think',
    'ask', 'tell', 'give', 'take', 'come', 'go', 'know', 'see', 'try', 'let',
  };

  static String extractLabel(String prompt) {
    // Split into words and filter
    final words = prompt
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && w.length > 2 && !_stopWords.contains(w))
        .toList();

    // Get unique keywords and limit to 2-3
    final keywordSet = <String>{};
    for (final word in words) {
      if (keywordSet.length >= 2) break;
      keywordSet.add(word);
    }

    if (keywordSet.isEmpty) {
      return 'general_${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    }

    return keywordSet.join('_').replaceAll('_', '_').toLowerCase();
  }

  static String extractTitle(String prompt) {
    final firstSentence = prompt.split(RegExp(r'[.!?]')).first.trim();
    if (firstSentence.length > 60) {
      return '${firstSentence.substring(0, 57)}...';
    }
    return firstSentence.isEmpty ? 'Untitled Chat' : firstSentence;
  }
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> with TickerProviderStateMixin {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _sessionSearchController = TextEditingController();
  final TextEditingController _chainSearchController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  late AnimationController _animationController;
  late AnimationController _sidebarController;
  bool _isLoading = false;
  bool _sidebarOpen = false;
  String? _sessionId;
  String? _sessionTitle;
  String? _lastAiResponse;
  bool _canPublish = false;

  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _filteredSessions = [];
  String _sessionSearchQuery = '';
  String _mode = 'chronicles';
  String _outputType = 'draft';
  List<Map<String, String>> _chains = [];
  List<Map<String, String>> _filteredChains = [];
  Map<String, String>? _selectedChain;

  static const platform = MethodChannel('com.whispr.whisprmobile/screenshot');



  Future<void> _disableScreenshot() async {
    try {
      await platform.invokeMethod('disableScreenshot');
      debugPrint('Screenshot disabled for AI chat screen');
    } catch (e) {
      debugPrint('Could not disable screenshot: $e');
    }
  }

  Future<void> _enableScreenshot() async {
    try {
      await platform.invokeMethod('enableScreenshot');
      debugPrint('Screenshot enabled');
    } catch (e) {
      debugPrint('Could not enable screenshot: $e');
    }
  }

  /// Validates if the user's input is actual content and not just placeholder text
  /// Returns error message if invalid, null if valid
  String? _validateUserContent(String prompt) {
    // Check if longer than minimum
    if (prompt.length < 10) {
      return 'Please write at least 10 characters. The AI will continue from your writing!';
    }

    // Extract words (ignore numbers and special chars)
    final words = prompt
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && w.length > 1)
        .toList();

    // Check if has meaningful words (not just numbers)
    final meaningfulWords = words.where((w) => !RegExp(r'^\d+$').hasMatch(w)).toList();
    
    if (meaningfulWords.isEmpty) {
      return 'Please write actual content, not just numbers or symbols. The AI needs your thoughts to continue!';
    }

    // Check if it seems like a placeholder (e.g., "test", "a", "hello", etc.)
    final lowercasePrompt = prompt.toLowerCase();
    final commonPlaceholders = {
      'test', 'hello', 'hi', 'hey', 'ok', 'sure', 'yes', 'no',
      'a', 'aa', 'aaa', 'abc', 'xyz', 'test123', 'demo', 'sample',
      'placeholder', 'write something', 'something', 'anything', 'blah',
      'random', 'asdf', 'qwerty', 'type here', 'enter text'
    };

    // If the entire prompt is just one of these placeholders
    if (commonPlaceholders.contains(lowercasePrompt.trim())) {
      return 'Please share your actual thoughts or poem idea. What would you like to write about?';
    }

    // Check if it's mostly repeated characters
    if (RegExp(r'(.)\1{4,}').hasMatch(prompt)) {
      return 'Your input looks incomplete. Please write meaningful content and I\'ll continue from there!';
    }

    return null; // Valid content
  }

  Future<void> _sendPrompt() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    // Validate user content using intelligent checking
    final validationError = _validateUserContent(prompt);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _messages.add({'role': 'user', 'text': prompt});
      _canPublish = false;
      _lastAiResponse = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      
      // Check daily limit before sending prompt
      try {
        final limitResponse = await apiService.get('/ai/daily-limit');
        final dailyCount = limitResponse['dailyCount'] as int? ?? 0;
        
        if (dailyCount >= 5) {
          // Show error and revert
          setState(() {
            _messages.removeLast();
            _isLoading = false;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You have reached your daily limit of 5 AI-generated contents. Come back tomorrow!'),
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        }
        
        debugPrint('Daily AI content count: $dailyCount/5');
      } catch (e) {
        debugPrint('Could not check daily limit: $e');
        // Continue anyway, will check on backend
      }
      
      debugPrint('Sending prompt to /ai/chat');
      
      final response = await apiService.post('/ai/chat',
        data: {
          'sessionId': _sessionId,
          'prompt': prompt,
          'mode': _mode,
          'outputType': _outputType,
          'chainId': _selectedChain?['id'] ?? '',
          'chainTitle': _selectedChain?['title'] ?? '',
        },
      );

      debugPrint('AI response received');
      
      final aiText = response['generatedText'] as String? ?? 'No response';
      final newSessionId = response['sessionId'] as String?;
      final targetPostId = response['targetPostId'] as String?;
      
      if (newSessionId != null && _sessionId == null) {
        setState(() {
          _sessionId = newSessionId;
        });
        debugPrint('New session created: $newSessionId');
        await _fetchSessions();
      }

      setState(() {
        // Add AI label marker to distinguish from user messages
        _messages.add({'role': 'assistant', 'text': aiText, 'isAiGenerated': 'true'});
        _lastAiResponse = aiText;
        _canPublish = true; // Enable publish button
        _promptController.clear(); // Clear input field
      });

      if (targetPostId != null) {
        debugPrint('Content saved: targetPostId=$targetPostId, mode=$_mode, status=$_outputType');
      }

    } catch (e) {
      debugPrint('_sendPrompt error: $e');
      // Check if it's a timeout but response was actually processed
      if (e.toString().contains('receive timeout')) {
        debugPrint('Request timed out but may have been processed. Response was received and saved.');
        setState(() {
          _promptController.clear(); // Still clear input if timeout
        });
      } else {
        setState(() {
          _messages.add({'role': 'assistant', 'text': 'Failed to generate AI text: $e'});
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }

    _promptController.clear();
  }

  Future<void> _publishContentWithStatus(String status) async {
    if (_lastAiResponse == null || _lastAiResponse!.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      
      // Auto-generate excerpt (first 160 characters)
      final excerpt = _lastAiResponse!.length > 160 
          ? '${_lastAiResponse!.substring(0, 160)}...'
          : _lastAiResponse!;
      
      // Extract meaningful tags from content (top 3 keywords)
      final contentWords = _lastAiResponse!
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty && w.length > 3)
          .toList();
      
      final tagSet = <String>{};
      for (final word in contentWords) {
        if (tagSet.length >= 3) break;
        if (!KeywordExtractor._stopWords.contains(word)) {
          tagSet.add(word);
        }
      }
      
      final tags = tagSet.toList();
      
      if (_mode == 'writing_chains' && _selectedChain != null) {
        // Create writing chain entry
        await apiService.post('/chronicles/chains/${_selectedChain!['id']}/entries', data: {
          'title': 'AI-Generated Entry',
          'content': _lastAiResponse,
          'status': status,
          'sequence': 0,
        });
        debugPrint('Chain entry created with status: $status');
      } else {
        // Create chronicle post using correct route with auto-generated fields
        await apiService.post('/chronicles/creator/posts', data: {
          'title': 'AI-Generated Chronicle',
          'slug': 'ai-generated-${DateTime.now().millisecondsSinceEpoch}',
          'content': _lastAiResponse,
          'excerpt': excerpt,
          'post_type': 'poem',
          'category': 'AI Generated',
          'tags': tags,
          'status': status,
          'formatting_data': {},
        });
        debugPrint('Chronicle post created with status: $status, category: AI Generated, tags: $tags');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Content saved as ${status == 'published' ? 'published' : 'draft'}'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF911A1B),
          ),
        );
      }

      setState(() => _canPublish = false);
    } catch (e) {
      debugPrint('Publish error: $e');
      
      // Handle different error types
      String errorMessage = 'Failed to save content';
      if (e.toString().contains('already exists') || e.toString().contains('duplicate')) {
        errorMessage = 'This content has already been saved';
      } else if (e.toString().contains('unauthorized') || e.toString().contains('403')) {
        errorMessage = 'You are not authorized to save this content';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please try again';
      } else if (e.toString().contains('400')) {
        errorMessage = 'Invalid content data. Please check and try again';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _disableScreenshot();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _sidebarController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _sidebarController.reverse(); // Start as closed
    _fetchChains();
    _fetchSessions();
    _sessionSearchController.addListener(_onSessionSearchChanged);
    _chainSearchController.addListener(_onChainSearchChanged);
  }

  @override
  void dispose() {
    _enableScreenshot();
    _promptController.dispose();
    _sessionSearchController.dispose();
    _chainSearchController.dispose();
    _animationController.dispose();
    _sidebarController.dispose();
    super.dispose();
  }

  void _onSessionSearchChanged() {
    final query = _sessionSearchController.text.toLowerCase();
    setState(() {
      _sessionSearchQuery = query;
      _filteredSessions = _sessions
          .where((s) => (s['title'] as String? ?? '').toLowerCase().contains(query))
          .toList();
    });
  }

  void _onChainSearchChanged() {
    final query = _chainSearchController.text.toLowerCase();
    setState(() {
      _filteredChains = _chains
          .where((chain) => chain['title']!.toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _fetchSessions() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final res = await apiService.get('/ai/chat/sessions');
      
      if (res != null && (res as Map<String, dynamic>)['data'] != null) {
        final data = List<Map<String, dynamic>>.from(res['data'] as List);
        setState(() {
          _sessions = data;
          _filteredSessions = data;
        });
      }
    } catch (e) {
      debugPrint('_fetchSessions error: $e');
    }
  }

  Future<void> _selectSession(String sessionId) async {
    try {
      final session = _sessions.firstWhere(
        (s) => s['id'] == sessionId,
        orElse: () => {},
      );

      setState(() {
        _sessionId = sessionId;
        _sessionTitle = session['title'] as String? ?? 'Untitled';
        _canPublish = false;
        _lastAiResponse = null;
      });

      final res = await ref.read(apiServiceProvider).get('/ai/chat/sessions/$sessionId');
      if (res != null && (res as Map<String, dynamic>)['data'] != null) {
        final messages = (res['data'] as List)
            .map((msg) => {'role': msg['sender'] as String, 'text': msg['content'] as String})
            .toList();
        
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
          
          // Check if last message is from assistant (AI generated content)
          // If so, show publish button so user can save it if not already saved
          if (messages.isNotEmpty && messages.last['role'] == 'assistant') {
            _lastAiResponse = messages.last['text'];
            _canPublish = true; // Allow user to publish existing AI responses
          }
        });
      }

      // Auto-close sidebar after session selection
      if (_sidebarOpen) {
        setState(() => _sidebarOpen = false);
        _sidebarController.reverse();
      }
    } catch (e) {
      debugPrint('_selectSession error: $e');
    }
  }

  void _newSession() {
    setState(() {
      _sessionId = null;
      _sessionTitle = null;
      _messages.clear();
      _selectedChain = null;
      _chainSearchController.clear();
      _canPublish = false;
      _lastAiResponse = null;
    });
  }

  Future<void> _fetchChains() async {
    try {
      final res = await ref.read(apiServiceProvider).get('/chronicles/chains');
      if (res != null && (res as Map<String, dynamic>)['data'] != null) {
        final list = ((res['data'] as List).map((item) => {
              'id': item['id'] as String,
              'title': item['title'] as String,
            })).toList();
        setState(() {
          _chains = List<Map<String, String>>.from(list);
          _filteredChains = List.from(_chains);
        });
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF911A1B);
    final sidebarColor = isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
    final backgroundColor = isDarkMode ? const Color(0xFF0F0F0F) : const Color(0xFFF8F8F8);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/more'),
          tooltip: 'Back to Profile',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('AI Writing Lab', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (_sessionTitle != null && _sessionTitle!.isNotEmpty)
              Text(
                _sessionTitle!,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_sidebarOpen ? Icons.close : Icons.menu),
            onPressed: () {
              setState(() => _sidebarOpen = !_sidebarOpen);
              if (_sidebarOpen) {
                _sidebarController.forward();
              } else {
                _sidebarController.reverse();
              }
            },
            tooltip: _sidebarOpen ? 'Hide sessions' : 'Show sessions',
          ),
        ],
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
      ),
      body: Stack(
        children: [
          // Main chat area (full width/height)
          Column(
            children: [
              // Chat config (modes, chain selection)
              if (_messages.isEmpty)
                _buildChatConfig(isDarkMode, primaryColor),

              // Messages area
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState(context, primaryColor)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final item = _messages[index];
                          final isUser = item['role'] == 'user';
                          return _buildMessageBubble(context, item, isUser, isDarkMode, primaryColor, index);
                        },
                      ),
              ),

              // Loading indicator
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 4,
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'AI is writing...',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // Publish button (when AI response available)
              if (_canPublish && !_isLoading && _lastAiResponse != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF911A1B).withValues(alpha: 0.1),
                    border: Border(top: BorderSide(color: Colors.grey[300]!, width: 0.5)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _canPublish = false);
                          },
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Discard'),
                          style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _publishContentWithStatus('draft'),
                          icon: const Icon(Icons.save, size: 18),
                          label: const Text('Draft'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF911A1B),
                            side: const BorderSide(color: Color(0xFF911A1B)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _publishContentWithStatus('published'),
                          icon: const Icon(Icons.publish, size: 18),
                          label: const Text('Publish'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF911A1B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Prompt input area
              Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey[300]!, width: 0.5)),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mode selector
                    if (_messages.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildCompactDropdown(
                                value: _mode,
                                items: const ['chronicles', 'writing_chains'],
                                labels: const ['Chronicles', 'Chains'],
                                onChanged: (val) => setState(() => _mode = val),
                                isDark: isDarkMode,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildCompactDropdown(
                                value: _outputType,
                                items: const ['draft', 'publish'],
                                labels: const ['Draft', 'Publish'],
                                onChanged: (val) => setState(() => _outputType = val),
                                isDark: isDarkMode,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Prompt input
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.grey[300]!, width: 0.5),
                            ),
                            child: TextField(
                              controller: _promptController,
                              maxLines: null,
                              minLines: 1,
                              maxLength: 500,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: 'Write your poem/content first... (min 10 chars, then AI continues)',
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                counterText: '',
                                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                              ),
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white, size: 20),
                            onPressed: _isLoading ? null : _sendPrompt,
                            tooltip: 'Send',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Sidebar overlay - positioned on left side
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 280,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _sidebarController,
                curve: Curves.easeOut,
              )),
              child: Container(
                decoration: BoxDecoration(
                  color: sidebarColor,
                  border: Border(right: BorderSide(color: Colors.grey[300]!, width: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(4, 0),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header with New button
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 0.5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Sessions',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(Icons.add, size: 20, color: primaryColor),
                              onPressed: _newSession,
                              tooltip: 'New session',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search field
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _sessionSearchController,
                        decoration: InputDecoration(
                          hintText: 'Search sessions...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          filled: true,
                          fillColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[50],
                        ),
                        style: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white : Colors.black),
                      ),
                    ),

                    // Sessions list
                    Expanded(
                      child: _filteredSessions.isEmpty
                          ? Center(
                              child: Text(
                                _sessionSearchQuery.isEmpty ? 'No sessions yet' : 'No matches',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: _filteredSessions.length,
                              itemBuilder: (context, index) {
                                final session = _filteredSessions[index];
                                final isSelected = _sessionId == session['id'];
                                final title = session['title'] as String? ?? 'Untitled';
                                final updatedAt = session['updated_at'] as String?;
                                final timeAgo = _formatTimeAgo(updatedAt);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: GestureDetector(
                                    onTap: () => _selectSession(session['id'] as String),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? primaryColor.withValues(alpha: 0.12)
                                            : (isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[50]),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected ? primaryColor : Colors.transparent,
                                          width: isSelected ? 1.5 : 0,
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              height: 1.3,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            timeAgo,
                                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Scrim/backdrop when sidebar is open (covers only chat area, not sidebar)
          if (_sidebarOpen)
            Positioned(
              left: 280,
              top: 0,
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  setState(() => _sidebarOpen = false);
                  _sidebarController.reverse();
                },
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Build chat configuration panel
  Widget _buildChatConfig(bool isDarkMode, Color primaryColor) {
    return Container(
      color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Chat Configuration',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryColor),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _mode,
                  decoration: InputDecoration(
                    labelText: 'Type',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'chronicles', child: Text('Chronicles')),
                    DropdownMenuItem(value: 'writing_chains', child: Text('Writing Chains')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _mode = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _outputType,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(value: 'publish', child: Text('Publish')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _outputType = value);
                  },
                ),
              ),
            ],
          ),
          if (_mode == 'writing_chains') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _chainSearchController,
              decoration: InputDecoration(
                labelText: 'Search Chains',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedChain?['id'],
              hint: const Text('Select Chain'),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: _filteredChains
                  .map(
                    (c) => DropdownMenuItem<String>(
                      value: c['id'],
                      child: Text(c['title'] ?? 'Unnamed chain'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                final selected = _chains.firstWhere((c) => c['id'] == value, orElse: () => {});
                setState(() => _selectedChain = selected.isNotEmpty ? selected : null);
              },
            ),
          ],
        ],
      ),
    );
  }

  // Build empty state
  Widget _buildEmptyState(BuildContext context, Color primaryColor) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: primaryColor,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Start Your AI Writing Journey',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Type a prompt below to generate Chronicles, poems, or writing chain entries.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                '✨ Tips:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryColor),
              ),
              const SizedBox(height: 8),
              Text(
                '• Be specific about what you want\n• Include mood, tone, or style\n• Mention length or format preferences',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build message bubble with animations
  Widget _buildMessageBubble(
    BuildContext context,
    Map<String, String> item,
    bool isUser,
    bool isDarkMode,
    Color primaryColor,
    int index,
  ) {
    final isAiGenerated = item['isAiGenerated'] == 'true';
    
    return FadeInSlide(
      delay: Duration(milliseconds: index * 100),
      duration: const Duration(milliseconds: 500),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // AI-Generated label
            if (isAiGenerated)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '✨ AI-Generated',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            // Message bubble
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
              decoration: BoxDecoration(
                color: isUser
                    ? primaryColor
                    : (isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[200]),
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                  bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: isAiGenerated
                  ? // Disable selection for AI messages
                    SelectableText.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: item['text'] ?? '',
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black87,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                      enableInteractiveSelection: false,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    )
                  : // User messages - selectable
                    SelectableText(
                      item['text'] ?? '',
                      style: TextStyle(
                        color: isUser ? Colors.white : (isDarkMode ? Colors.white : Colors.black87),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Build compact dropdown for quick mode selection
  Widget _buildCompactDropdown({
    required String value,
    required List<String> items,
    required List<String> labels,
    required Function(String) onChanged,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 0.5),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        items: List.generate(
          items.length,
          (i) => DropdownMenuItem(
            value: items[i],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(labels[i], style: const TextStyle(fontSize: 13)),
            ),
          ),
        ),
        onChanged: (val) => val != null ? onChanged(val) : null,
      ),
    );
  }

  String _formatTimeAgo(String? dateTimeStr) {
    if (dateTimeStr == null) return 'recently';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) return 'now';
      if (difference.inHours < 1) return '${difference.inMinutes}m ago';
      if (difference.inDays < 1) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      return 'older';
    } catch (_) {
      return 'recently';
    }
  }
}

// Fade and slide animation widget
class FadeInSlide extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const FadeInSlide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

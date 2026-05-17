import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_service.dart';
import '../../../core/services/notifications_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/auth_state.dart';

final _notificationsServiceProvider = Provider((ref) => NotificationsService(ApiService.instance));

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String type; // 'like', 'comment', 'follow', 'system'

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.isRead,
    required this.type,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      isRead: json['isRead'] ?? false,
      type: json['type'] ?? 'system',
    );
  }

  IconData get icon {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'follow':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  Color get color {
    switch (type) {
      case 'like':
        return Colors.red;
      case 'comment':
        return Colors.blue;
      case 'follow':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String get displayTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated) {
      setState(() {
        _error = 'Please log in to view notifications';
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() => _isLoading = true);
      final notifications = await ref.read(_notificationsServiceProvider).getNotifications();
      setState(() {
        _notifications = notifications.map((json) => NotificationItem.fromJson(Map<String, dynamic>.from(json))).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await ref.read(_notificationsServiceProvider).markRead(notificationId);
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = NotificationItem(
            id: _notifications[index].id,
            title: _notifications[index].title,
            message: _notifications[index].message,
            timestamp: _notifications[index].timestamp,
            isRead: true,
            type: _notifications[index].type,
          );
        }
      });
    } catch (e) {
      // Handle error silently for now
      debugPrint('Failed to mark notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await ref.read(_notificationsServiceProvider).markAllRead();
      setState(() {
        _notifications = _notifications.map((notification) => NotificationItem(
          id: notification.id,
          title: notification.title,
          message: notification.message,
          timestamp: notification.timestamp,
          isRead: true,
          type: notification.type,
        )).toList();
      });
    } catch (e) {
      // Handle error silently for now
      debugPrint('Failed to mark all notifications as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Mark All Read'),
            ),
        ],
      ),
      body: authState.isAuthenticated
          ? _buildAuthenticatedView()
          : _buildUnauthenticatedView(),
    );
  }

  Widget _buildAuthenticatedView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: AppTheme.spacingM),
            ElevatedButton(
              onPressed: _fetchNotifications,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'No notifications yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'You\'ll see updates here when people interact with your content',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spacingS),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return Card(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingXS),
            color: notification.isRead
                ? Theme.of(context).cardColor
                : Theme.of(context).primaryColor.withValues(alpha: 0.05),
            child: InkWell(
              onTap: () {
                if (!notification.isRead) {
                  _markAsRead(notification.id);
                }
                // TODO: Navigate to relevant content based on notification type
              },
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingXS),
                      decoration: BoxDecoration(
                        color: notification.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        notification.icon,
                        color: notification.color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            notification.message,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppTheme.spacingXS),
                          Text(
                            notification.displayTime,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!notification.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUnauthenticatedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'Sign in to see notifications',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Get notified about interactions with your content',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          ElevatedButton(
            onPressed: () {
              context.go('/login');
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}

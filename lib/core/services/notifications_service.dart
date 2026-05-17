import '../network/api_service.dart';

class NotificationsService {
  NotificationsService(this._apiService);

  final ApiService _apiService;

  Future<List<dynamic>> getNotifications() async {
    final response = await _apiService.get('/chronicles/creator/notifications');
    return (response['notifications'] as List?) ?? const [];
  }

  Future<void> markRead(String notificationId) => _apiService.post(
        '/chronicles/creator/notifications',
        data: {'notificationId': notificationId},
      );
  Future<void> markAllRead() => _apiService.post(
        '/chronicles/creator/notifications',
        data: {'all': true, 'read': true},
      );
}

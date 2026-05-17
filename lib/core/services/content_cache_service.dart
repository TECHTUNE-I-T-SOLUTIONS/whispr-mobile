import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ContentCacheService {
  static const String _prefix = 'whispr_cache_';

  Future<void> saveJson(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$key', jsonEncode(value));
    await prefs.setInt('$_prefix${key}_time', DateTime.now().millisecondsSinceEpoch);
  }

  Future<dynamic> readJson(String key, {Duration maxAge = const Duration(minutes: 10)}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('$_prefix$key');
    final savedAt = prefs.getInt('$_prefix${key}_time');
    if (data == null || savedAt == null) return null;

    final age = DateTime.now().millisecondsSinceEpoch - savedAt;
    if (age > maxAge.inMilliseconds) return null;
    return jsonDecode(data);
  }
}

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class ScreenshotPreventionService {
  static const platform = MethodChannel('com.whispr.whisprmobile/screenshot');

  /// Disables screenshot capability on the current screen
  static Future<void> disableScreenshot() async {
    try {
      await platform.invokeMethod<void>('disableScreenshot');
    } catch (e) {
      debugPrint('Error disabling screenshot: $e');
    }
  }

  /// Enables screenshot capability on the current screen
  static Future<void> enableScreenshot() async {
    try {
      await platform.invokeMethod<void>('enableScreenshot');
    } catch (e) {
      debugPrint('Error enabling screenshot: $e');
    }
  }
}

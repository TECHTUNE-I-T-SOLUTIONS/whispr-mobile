import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // API Configuration
  static String get baseUrl {
    if (!dotenv.isInitialized) {
      return 'https://whisprwords.vercel.app/api';
    }
    return dotenv.env['API_BASE_URL'] ?? 'https://whisprwords.vercel.app/api';
  }

  static String get localBaseUrl {
    if (!dotenv.isInitialized) {
      return 'https://whisprwords.vercel.app/api';
    }
    return dotenv.env['API_BASE_URL'] ?? 'https://whisprwords.vercel.app/api';
  }

  // Share URL Configuration (for generating shareable links)
  static String get shareBaseUrl {
    if (!dotenv.isInitialized) {
      return 'https://whisprwords.vercel.app';
    }
    return dotenv.env['SHARE_BASE_URL'] ?? 'https://whisprwords.vercel.app';
  }

  // Gemini API key stored in .env
  static String get geminiApiKey {
    if (!dotenv.isInitialized) {
      return '';
    }
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }


  // API Endpoints
  static const String postsEndpoint = '/posts';
  static const String chroniclesAuthEndpoint = '/chronicles/auth';
  static const String chroniclesPostsEndpoint = '/chronicles/posts';
  static const String wallEndpoint = '/wall';
  static const String notificationsEndpoint = '/chronicles/push-notify';
  static const String premiumEndpoint = '/chronicles/monetization';

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String themeModeKey = 'theme_mode';
  static const String isLoggedInKey = 'is_logged_in';

  // Paystack Configuration
  static const String paystackPublicKey = 'pk_test_your_paystack_public_key';

  // App Configuration
  static const String appName = 'Whispr';
  static const int postsPerPage = 20;
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration cacheTimeout = Duration(hours: 1);

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Validation
  static const int minPasswordLength = 8;
  static const int maxPostTitleLength = 100;
  static const int maxPostContentLength = 10000;

  // Social Sharing
  static const String appUrl = 'https://whisprwords.vercel.app';
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=com.whispr.mobile';
  static const String appStoreUrl = 'https://apps.apple.com/app/whispr/id1234567890';

  // Error Messages
  static const String networkError = 'Network connection failed. Please check your internet connection.';
  static const String serverError = 'Server error occurred. Please try again later.';
  static const String unauthorizedError = 'Session expired. Please login again.';
  static const String validationError = 'Please check your input and try again.';
}
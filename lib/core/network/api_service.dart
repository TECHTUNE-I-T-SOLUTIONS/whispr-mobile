import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

// Provider for ApiService
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService.instance;
});

class ApiService {
  // Singleton instance
  static final ApiService _instance = ApiService._internal();
  static ApiService get instance => _instance;

  late final dio.Dio _dio;
  late final dio.Dio _refreshDio;
  SharedPreferences? _prefs;
  final Completer<void> _initCompleter = Completer<void>();
  bool _isRefreshingToken = false;

  // Private constructor
  ApiService._internal() {
    _initService();
  }

  // Factory constructor for backward compatibility
  factory ApiService() {
    return _instance;
  }

  Future<void> _initService() async {
    if (_initCompleter.isCompleted) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _dio = dio.Dio(
        dio.BaseOptions(
          baseUrl: AppConstants.baseUrl,
          connectTimeout: AppConstants.apiTimeout,
          receiveTimeout: AppConstants.apiTimeout,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500, // Accept 4xx errors for custom handling
        ),
      );
      _refreshDio = dio.Dio(
        dio.BaseOptions(
          baseUrl: AppConstants.baseUrl,
          connectTimeout: AppConstants.apiTimeout,
          receiveTimeout: AppConstants.apiTimeout,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      _setupInterceptors();
      _initCompleter.complete();
    } catch (e) {
      _initCompleter.completeError(e);
      rethrow;
    }
  }

  Future<void> ensureInitialized() async {
    return _initCompleter.future;
  }

  void _setupInterceptors() {
    _dio.interceptors.addAll([
      // Auth interceptor
      dio.InterceptorsWrapper(
        onRequest: (options, handler) async {
          await ensureInitialized();
          final token = _prefs?.getString(AppConstants.accessTokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          await ensureInitialized();
          
          // Handle token expiration (401 or 403)
          if ((error.response?.statusCode == 401 || error.response?.statusCode == 403)) {
            try {
              if (_isRefreshingToken) {
                return handler.next(error);
              }

              // Attempt to refresh token
              final refreshToken = _prefs?.getString(AppConstants.refreshTokenKey);
              if (refreshToken != null) {
                _isRefreshingToken = true;
                final refreshResponse = await _refreshDio.post(
                  '/chronicles/auth/refresh',
                  data: {'refresh_token': refreshToken},
                  options: dio.Options(
                    validateStatus: (status) => status != null && status < 500,
                  ),
                );

                if (refreshResponse.statusCode == 200) {
                  final newAccessToken = refreshResponse.data?['access_token'];
                  final newRefreshToken = refreshResponse.data?['refresh_token'];
                  
                  if (newAccessToken != null) {
                    // Store new tokens
                    await _prefs?.setString(AppConstants.accessTokenKey, newAccessToken);
                    if (newRefreshToken != null) {
                      await _prefs?.setString(AppConstants.refreshTokenKey, newRefreshToken);
                    }

                    // Update request headers and retry
                    error.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                    return handler.resolve(await _dio.fetch(error.requestOptions));
                  }
                }
              }
            } catch (e) {
              // Token refresh failed, user needs to login again
              debugPrint('Token refresh failed: $e');
            } finally {
              _isRefreshingToken = false;
            }
          }

          handler.next(error);
        },
      ),

      // Logging interceptor
      if (kDebugMode)
        dio.LogInterceptor(
          request: true,
          requestHeader: true,
          requestBody: true,
          error: true,
        ),
    ]);
  }

  // Generic GET request
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    await ensureInitialized();
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return fromJson != null ? fromJson(response.data) : response.data as T;
    } on dio.DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Generic POST request
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    await ensureInitialized();
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return fromJson != null ? fromJson(response.data) : response.data as T;
    } on dio.DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Generic PUT request
  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    await ensureInitialized();
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return fromJson != null ? fromJson(response.data) : response.data as T;
    } on dio.DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Generic DELETE request
  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    await ensureInitialized();
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return fromJson != null ? fromJson(response.data) : response.data as T;
    } on dio.DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Multipart upload
  Future<T> uploadFile<T>(
    String path,
    File file, {
    String fieldName = 'file',
    Map<String, dynamic>? additionalData,
    T Function(dynamic)? fromJson,
  }) async {
    await ensureInitialized();
    try {
      final formData = dio.FormData.fromMap({
        fieldName: await dio.MultipartFile.fromFile(file.path),
        if (additionalData != null) ...additionalData,
      });

      final response = await _dio.post(path, data: formData);
      return fromJson != null ? fromJson(response.data) : response.data as T;
    } on dio.DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Error handling
  Exception _handleError(dio.DioException error) {
    if (error.type == dio.DioExceptionType.connectionTimeout ||
        error.type == dio.DioExceptionType.receiveTimeout ||
        error.type == dio.DioExceptionType.sendTimeout) {
      return NetworkException(AppConstants.networkError);
    }

    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final data = error.response!.data;
      final message = _extractErrorMessage(data);

      switch (statusCode) {
        case 400:
          return ValidationException(message ?? AppConstants.validationError);
        case 401:
          return UnauthorizedException(message ?? AppConstants.unauthorizedError);
        case 403:
          return ForbiddenException(message ?? 'Access denied');
        case 404:
          return NotFoundException(message ?? 'Resource not found');
        case 422:
          return ValidationException(message ?? AppConstants.validationError);
        case 500:
        case 502:
        case 503:
          return ServerException(message ?? AppConstants.serverError);
        default:
          return ApiException(message ?? 'An unexpected error occurred');
      }
    }

    return NetworkException(AppConstants.networkError);
  }

  String? _extractErrorMessage(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) {
      final value = data['error'] ?? data['message'] ?? data['detail'];
      return value?.toString();
    }
    if (data is String) {
      final trimmed = data.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return data.toString();
  }
}

// Custom exceptions
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => message;
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);

  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);

  @override
  String toString() => message;
}

class ForbiddenException implements Exception {
  final String message;
  ForbiddenException(this.message);

  @override
  String toString() => message;
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException(this.message);

  @override
  String toString() => message;
}

class ServerException implements Exception {
  final String message;
  ServerException(this.message);

  @override
  String toString() => message;
}

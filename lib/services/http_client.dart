import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/response_model.dart';
import '../services/error_handler.dart';

class HttpClient {
  static final HttpClient _instance = HttpClient._internal();
  factory HttpClient() => _instance;
  HttpClient._internal();

  static const String baseUrl = 'https://collie-humorous-goose.ngrok-free.app/api/v1';
  static const Duration connectTimeout = Duration(seconds: 5);
  static const Duration receiveTimeout = Duration(seconds: 10);
  static const Duration sendTimeout = Duration(seconds: 10);

  late Dio _dio;
  String? _accessToken;
  String? _refreshToken;

  Dio get dio => _dio;

  Future<void> initialize() async {
    try {
      _dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));

      // Add interceptors
      _dio.interceptors.add(_createAuthInterceptor());
      _dio.interceptors.add(_createRetryInterceptor());
      
      if (kDebugMode) {
        _dio.interceptors.add(_createLoggingInterceptor());
      }

      // Load stored tokens (non-blocking)
      _loadTokens().catchError((e) => debugPrint('Token load error: $e'));
      
      debugPrint('✅ HttpClient initialized');
    } catch (e) {
      debugPrint('❌ HttpClient init error: $e');
      // Don't rethrow - create a basic dio instance
      _dio = Dio();
    }
  }

  // Auth Interceptor - Adds token to requests and handles token refresh
  Interceptor _createAuthInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (_accessToken != null) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 && _refreshToken != null) {
          // Try to refresh token
          try {
           // await _refreshAccessToken();
            // Retry the original request
            final retryOptions = error.requestOptions;
            retryOptions.headers['Authorization'] = 'Bearer $_accessToken';
            final response = await _dio.fetch(retryOptions);
            if (response != null) {
              handler.resolve(response);
            } else {
              handler.next(error);
            }
          } catch (refreshError) {
            // Refresh failed, clear tokens and let error handler deal with it
            await _clearTokens();
            handler.next(error);
          }
        } else {
          handler.next(error);
        }
      },
    );
  }

  // Retry Interceptor - Retries failed requests
  Interceptor _createRetryInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) async {
        final shouldRetry = _shouldRetryRequest(error);
        if (shouldRetry && (error.requestOptions.extra['retryCount'] ?? 0) < 3) {
          error.requestOptions.extra['retryCount'] = 
              (error.requestOptions.extra['retryCount'] ?? 0) + 1;
          
          // Wait before retry
          await Future.delayed(Duration(seconds: error.requestOptions.extra['retryCount'] ?? 1));
          
          try {
            final response = await _dio.fetch(error.requestOptions);
            if (response != null) {
              handler.resolve(response);
            } else {
              handler.next(error);
            }
          } catch (retryError) {
            handler.next(error);
          }
        } else {
          handler.next(error);
        }
      },
    );
  }

  // Logging Interceptor - Logs requests and responses in debug mode
  Interceptor _createLoggingInterceptor() {
    return LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: true,
      responseHeader: false,
      error: true,
      logPrint: (object) => debugPrint(object.toString()),
    );
  }

  bool _shouldRetryRequest(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
           error.type == DioExceptionType.receiveTimeout ||
           error.type == DioExceptionType.sendTimeout ||
           (error.response?.statusCode != null && 
            error.response!.statusCode! >= 500);
  }

  // Generic API call method
  Future<ApiResponse<T>> apiCall<T>({
    required String method,
    required String endpoint,
    Map<String, dynamic>? queryParameters,
    dynamic data,
    Map<String, dynamic>? headers,
    T Function(dynamic)? fromJson,
    Duration? timeout,
  }) async {
    try {
      final options = Options(
        method: method.toUpperCase(),
        headers: headers,
        sendTimeout: timeout ?? sendTimeout,
        receiveTimeout: timeout ?? receiveTimeout,
      );

      final response = await _dio.request(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

      return _handleSuccessResponse<T>(response, fromJson);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException('Unexpected error: ${e.toString()}');
    }
  }

  // Convenience methods
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    T Function(dynamic)? fromJson,
  }) async {
    return apiCall<T>(
      method: 'GET',
      endpoint: endpoint,
      queryParameters: queryParameters,
      headers: headers,
      fromJson: fromJson,
    );
  }

  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    T Function(dynamic)? fromJson,
  }) async {
    return apiCall<T>(
      method: 'POST',
      endpoint: endpoint,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      fromJson: fromJson,
    );
  }

  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    T Function(dynamic)? fromJson,
  }) async {
    return apiCall<T>(
      method: 'PUT',
      endpoint: endpoint,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      fromJson: fromJson,
    );
  }

  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    T Function(dynamic)? fromJson,
  }) async {
    return apiCall<T>(
      method: 'DELETE',
      endpoint: endpoint,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      fromJson: fromJson,
    );
  }

  Future<ApiResponse<T>> patch<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    T Function(dynamic)? fromJson,
  }) async {
    return apiCall<T>(
      method: 'PATCH',
      endpoint: endpoint,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      fromJson: fromJson,
    );
  }

  // File upload method
  Future<ApiResponse<T>> uploadFile<T>({
    required String endpoint,
    required String filePath,
    required String fieldName,
    Map<String, dynamic>? additionalData,
    Map<String, dynamic>? headers,
    T Function(dynamic)? fromJson,
    Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final fileName = filePath.split('/').last;
      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(filePath, filename: fileName),
        ...?additionalData,
      });

      final response = await _dio.post(
        endpoint,
        data: formData,
        options: Options(headers: headers),
        onSendProgress: onSendProgress,
      );

      return _handleSuccessResponse<T>(response, fromJson);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException('File upload failed: ${e.toString()}');
    }
  }

  // Token management
  void setTokens(String accessToken, String? refreshToken) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _saveTokens();
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
    _clearTokens();
  }

  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null) {
      throw UnauthorizedException('No refresh token available');
    }

    final response = await _dio.post(
      '/auth/refresh',
      data: {'refresh_token': _refreshToken},
      options: Options(headers: {'Authorization': null}),
    );

    if (response.statusCode == 200 && response.data != null) {
      final authResponse = AuthResponse.fromJson(response.data);
      setTokens(authResponse.accessToken, authResponse.refreshToken);
    } else {
      throw UnauthorizedException('Token refresh failed');
    }
  }

  Future<void> _loadTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      _refreshToken = prefs.getString('refresh_token');
    } catch (e) {
      debugPrint('Error loading tokens: $e');
    }
  }

  Future<void> _saveTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_accessToken != null) {
        await prefs.setString('access_token', _accessToken!);
      }
      if (_refreshToken != null) {
        await prefs.setString('refresh_token', _refreshToken!);
      }
    } catch (e) {
      debugPrint('Error saving tokens: $e');
    }
  }

  Future<void> _clearTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
    } catch (e) {
      debugPrint('Error clearing tokens: $e');
    }
  }

  ApiResponse<T> _handleSuccessResponse<T>(Response response, T Function(dynamic)? fromJson) {
    final data = response.data;
    
    if (data is Map<String, dynamic>) {
      // If the response follows standard API response format
      if (data.containsKey('success') || data.containsKey('data') || data.containsKey('message')) {
        return ApiResponse.fromJson(data, fromJson);
      }
      // If the response data is the actual content
      else {
        return ApiResponse<T>(
          success: true,
          message: 'Success',
          data: fromJson != null ? fromJson(data) : data as T?,
          statusCode: response.statusCode,
        );
      }
    }
    // For direct data responses (lists, strings, etc.)
    else {
      return ApiResponse<T>(
        success: true,
        message: 'Success',
        data: fromJson != null ? fromJson(data) : data as T?,
        statusCode: response.statusCode,
      );
    }
  }

  Exception _handleDioError(DioException error) {
    debugPrint('Dio error: ${error.type} - ${error.message}');
    
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException('Request timeout. Please try again.');
      
      case DioExceptionType.connectionError:
        if (error.error is SocketException) {
          return NetworkException('No internet connection');
        }
        return NetworkException('Connection error: ${error.message}');
      
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 500;
        final responseData = error.response?.data;
        
        String message = 'Request failed';
        if (responseData is Map<String, dynamic>) {
          message = responseData['message'] ?? responseData['error'] ?? message;
          
          // Handle validation errors
          if (statusCode == 422 && responseData['errors'] != null) {
            return ValidationException(message, errors: Map<String, List<String>>.from(
              responseData['errors'].map((key, value) => MapEntry(key, List<String>.from(value)))
            ));
          }
        }
        
        return ErrorHandler.createHttpException(statusCode, message, data: responseData);
      
      case DioExceptionType.cancel:
        return ApiException('Request cancelled');
      
      case DioExceptionType.badCertificate:
        return NetworkException('Invalid certificate');
      
      case DioExceptionType.unknown:
      default:
        if (error.error is SocketException) {
          return NetworkException('No internet connection');
        }
        return ApiException('Unknown error: ${error.message}');
    }
  }
}
import 'package:flutter/material.dart';
import '../models/response_model.dart';
import '../services/auth_service.dart';
import '../utils/graphics.dart';

class ErrorHandler {
  // Service locator instance (implement your own)
  static AuthService? _authService;
  static GlobalKey<NavigatorState>? _navigatorKey;

  // Add a flag and timestamp
  static bool _isShowingNetworkError = false;
  static DateTime? _lastErrorTime;

  /// Initialize ErrorHandler with required services
  static void initialize({
    AuthService? authService,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    _authService = authService;
    _navigatorKey = navigatorKey;
  }

  // Centralized error handling
  static void handleError(dynamic error) {
    debugPrint('ErrorHandler: Handling error: $error');

    if (error is CancelledRequestException) {
      debugPrint('Request was cancelled, no toast shown.');
      return;
    } else if (error is AuthenticationException) {
      _handleAuthenticationError(error);
    } else if (error is ValidationException) {
      _handleValidationError(error);
    } else if (error is NetworkException) {
      _handleNetworkError(error);
    } else if (error is ApiException) {
      _handleApiError(error);
    } else {
      _handleUnexpectedError(error);
    }
  }

  static void _handleAuthenticationError(AuthenticationException e) {
    debugPrint('Authentication required: ${e.message}');
    
    // Clear stored tokens
    _clearUserSession();
    
    // Navigate to login screen
    _navigateToLogin();
    
    // Show authentication error message
    _showErrorMessage('Please login to continue');
  }

  static void _handleValidationError(ValidationException e) {
    debugPrint('Validation error: ${e.message}');
    
    String errorMessage = 'Please check your input: ${e.message}';
    
    // If we have specific field errors, format them nicely
    if (e.errors != null && e.errors!.isNotEmpty) {
      final fieldErrors = <String>[];
      e.errors!.forEach((field, errors) {
        fieldErrors.add('$field: ${errors.join(', ')}');
      });
      errorMessage = fieldErrors.join('\n');
    }
    
    _showErrorMessage(errorMessage);
  }

  static void _handleNetworkError(NetworkException e) {
    debugPrint('Network error: ${e.message}');
    
    String message;
    switch (e.statusCode) {
      case 408:
        message = 'Request timeout. Please try again.';
        break;
      case null:
        message = 'Please check your internet connection';
        break;
      default:
        message = 'Network error: ${e.message}';
    }
    
    // _showErrorMessage(message);
    _showErrorMessageOnce(message);
  }

  static void _handleApiError(ApiException e) {
    debugPrint('API error: ${e.message}');
    
    String message;
    switch (e.statusCode) {
      case 400:
        message = 'Bad request: ${e.message}';
        break;
      case 401:
        _handleAuthenticationError(AuthenticationException(e.message, statusCode: 401));
        return;
      case 403:
        message = 'Access forbidden: ${e.message}';
        break;
      case 404:
        message = 'Resource not found: ${e.message}';
        break;
      case 422:
        message = 'Validation failed: ${e.message}';
        break;
      case 429:
        message = 'Too many requests. Please try again later.';
        break;
      case 500:
      case 502:
      case 503:
      case 504:
        message = 'Server error. Please try again later.';
        break;
      default:
        message = e.message;
    }

    if ([500, 502, 503, 504, 403].contains(e.statusCode)) {
      _showErrorMessageOnce(message);
    } else {
      _showErrorMessage(message);
    }
  }

  static void _handleUnexpectedError(dynamic e) {
    debugPrint('Unexpected error: $e');
    _showErrorMessage('Something went wrong. Please try again.');
  }

  static void _clearUserSession() {
    try {
      _authService?.signOut();
    } catch (e) {
      debugPrint('Error clearing user session: $e');
    }
  }

  static void _navigateToLogin() {
    try {
      if (_navigatorKey?.currentState != null) {
        _navigatorKey!.currentState!.pushNamedAndRemoveUntil(
          '/auth',
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error navigating to login: $e');
    }
  }

  static void _showErrorMessageOnce(String message) {
    final now = DateTime.now();

    // Allow new error if no error before or last one was > 3 sec ago
    if (!_isShowingNetworkError ||
        _lastErrorTime == null ||
        now.difference(_lastErrorTime!) > const Duration(seconds: 3)) {
      _isShowingNetworkError = true;
      _lastErrorTime = now;

      _showErrorMessage(message);

      // Reset flag after delay (prevents spam)
      Future.delayed(const Duration(seconds: 3), () {
        _isShowingNetworkError = false;
      });
    } else {
      debugPrint("Suppressed duplicate error: $message");
    }
  }


  static void _showErrorMessage(String message) {
    try {
      final context = _navigatorKey?.currentContext;
      if (context != null) {
        Graphics.showTopDialog(
          context,
          "Error",
          message,
          type: ToastType.error,
        );
      } else {
        // Fallback to debug print if no context available
        debugPrint('Error: $message');
      }
    } catch (e) {
      debugPrint('Error showing error message: $e');
      debugPrint('Original error: $message');
    }
  }

  // Utility method for widgets to safely make API calls
  static Future<T?> safeApiCall<T>(Future<T> Function() apiCall) async {
    try {
      return await apiCall();
    } catch (e) {
      handleError(e);
      return null;
    }
  }

  // Utility method for widgets to safely make API calls with loading state
  static Future<T?> safeApiCallWithLoading<T>(
    Future<T> Function() apiCall, {
    VoidCallback? onLoadingStart,
    VoidCallback? onLoadingEnd,
  }) async {
    try {
      onLoadingStart?.call();
      final result = await apiCall();
      return result;
    } catch (e) {
      handleError(e);
      return null;
    } finally {
      onLoadingEnd?.call();
    }
  }

  // Method to create standardized error from HTTP status codes
  static Exception createHttpException(int statusCode, String message, {dynamic data}) {
    switch (statusCode) {
      case 400:
        return ValidationException(message);
      case 401:
        return UnauthorizedException(message);
      case 403:
        return ForbiddenException(message);
      case 404:
        return NotFoundException(message);
      case 408:
        return TimeoutException(message);
      case 422:
        return ValidationException(message);
      case 500:
      case 502:
      case 503:
      case 504:
        return ServerException(message);
      default:
        if (statusCode >= 400 && statusCode < 500) {
          return ApiException(message, statusCode: statusCode, data: data);
        } else if (statusCode >= 500) {
          return ServerException(message);
        } else {
          return ApiException(message, statusCode: statusCode, data: data);
        }
    }
  }
}
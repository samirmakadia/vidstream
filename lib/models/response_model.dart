// API Response Models and Exceptions
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final Map<String, dynamic>? meta;
  final int? statusCode;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.meta,
    this.statusCode,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json)? fromJsonT,
  ) {
    return ApiResponse<T>(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null && fromJsonT != null 
        ? fromJsonT(json['data']) 
        : json['data'],
      meta: json['meta'],
      statusCode: json['statusCode'],
    );
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'message': message,
    'data': data,
    'meta': meta,
    'statusCode': statusCode,
  };
}

class PaginatedResponse<T> {
  final List<T> data;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;
  final bool hasNextPage;
  final bool hasPreviousPage;

  PaginatedResponse({
    required this.data,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemsPerPage,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    final List<dynamic> items = json['data'] ?? [];
    return PaginatedResponse<T>(
      data: items.map((item) => fromJsonT(item)).toList(),
      currentPage: json['currentPage'] ?? 1,
      totalPages: json['totalPages'] ?? 1,
      totalItems: json['totalItems'] ?? 0,
      itemsPerPage: json['itemsPerPage'] ?? 10,
      hasNextPage: json['hasNextPage'] ?? false,
      hasPreviousPage: json['hasPreviousPage'] ?? false,
    );
  }
}

// Authentication Models
class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final String token;
  final String tokenType;
  final int expiresIn;
  final Map<String, dynamic> user;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.token,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] ?? json['accessToken'] ?? '',
      refreshToken: json['refresh_token'] ?? json['refreshToken'] ?? '',
      token: json['token'] ?? json['token'] ?? '',
      tokenType: json['token_type'] ?? json['tokenType'] ?? 'Bearer',
      expiresIn: json['expires_in'] ?? json['expiresIn'] ?? 3600,
      user: json['user'] ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'token_type': tokenType,
    'token': token,
    'expires_in': expiresIn,
    'user': user,
  };
}

// Custom Exception Classes
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => 'ApiException: $message';
}

class AuthenticationException implements Exception {
  final String message;
  final int? statusCode;

  AuthenticationException(this.message, {this.statusCode});

  @override
  String toString() => 'AuthenticationException: $message';
}

class ValidationException implements Exception {
  final String message;
  final Map<String, List<String>>? errors;

  ValidationException(this.message, {this.errors});

  @override
  String toString() => 'ValidationException: $message';
}

class NetworkException implements Exception {
  final String message;
  final int? statusCode;

  NetworkException(this.message, {this.statusCode});

  @override
  String toString() => 'NetworkException: $message';
}

class UnauthorizedException extends AuthenticationException {
  UnauthorizedException([String? message]) 
    : super(message ?? 'Unauthorized access', statusCode: 401);
}

class ForbiddenException extends ApiException {
  ForbiddenException([String? message]) 
    : super(message ?? 'Access forbidden', statusCode: 403);
}

class NotFoundException extends ApiException {
  NotFoundException([String? message]) 
    : super(message ?? 'Resource not found', statusCode: 404);
}

class ServerException extends ApiException {
  ServerException([String? message]) 
    : super(message ?? 'Internal server error', statusCode: 500);
}

class TimeoutException extends NetworkException {
  TimeoutException([String? message]) 
    : super(message ?? 'Request timeout', statusCode: 408);
}
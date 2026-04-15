import 'package:flutter/foundation.dart';

/// Error types for categorization
enum ErrorType {
  timeout,
  network,
  unauthorized,
  forbidden,
  validation,
  notFound,
  serverError,
  serviceUnavailable,
  rateLimit,
  cancelled,
  httpError,
  unknown,
}

/// Error result class for standardized error handling
class ErrorResult {
  final String message;
  final ErrorType type;
  final int? statusCode;
  final String? suggestedAction;

  ErrorResult({
    required this.message,
    required this.type,
    this.statusCode,
    String? suggestedAction,
  }) : suggestedAction = suggestedAction ?? _getSuggestedAction(type);

  /// Get suggested action for error type
  static String _getSuggestedAction(ErrorType errorType) {
    switch (errorType) {
      case ErrorType.timeout:
      case ErrorType.network:
        return 'Check your internet connection and try again.';
      case ErrorType.unauthorized:
        return 'Please log in again to continue.';
      case ErrorType.forbidden:
        return 'Contact your administrator for access.';
      case ErrorType.validation:
        return 'Please check your input and try again.';
      case ErrorType.notFound:
        return 'The requested resource may have been moved or deleted.';
      case ErrorType.serverError:
      case ErrorType.serviceUnavailable:
        return 'Please try again in a few minutes.';
      case ErrorType.rateLimit:
        return 'Please wait before making another request.';
      case ErrorType.cancelled:
        return 'The operation was cancelled.';
      case ErrorType.unknown:
      case ErrorType.httpError:
        return 'Please try again or contact support if the issue persists.';
    }
  }

  /// Check if error is recoverable
  bool get isRecoverable => _isRecoverable(type);

  static bool _isRecoverable(ErrorType errorType) {
    switch (errorType) {
      case ErrorType.timeout:
      case ErrorType.network:
      case ErrorType.serviceUnavailable:
      case ErrorType.rateLimit:
        return true;
      case ErrorType.unauthorized:
      case ErrorType.forbidden:
      case ErrorType.validation:
      case ErrorType.notFound:
      case ErrorType.serverError:
      case ErrorType.httpError:
      case ErrorType.cancelled:
      case ErrorType.unknown:
        return false;
    }
  }

  /// Get full error message with suggested action
  String get fullMessage => suggestedAction != null 
      ? '$message\n\n\u2139\ufe0f $suggestedAction' 
      : message;

  @override
  String toString() {
    return 'ErrorResult(type: $type, message: $message, statusCode: $statusCode)';
  }
}

/// Centralized error management
class AppErrorHandler {
  // Private constructor to prevent instantiation
  AppErrorHandler._();

  /// Handle and categorize errors with user-friendly messages
  static ErrorResult handleError(dynamic error) {
    if (error is AppException) {
      return ErrorResult(
        message: error.message,
        type: error.type,
        statusCode: error.statusCode,
      );
    } else {
      return ErrorResult(
        message: 'An unexpected error occurred. Please try again.',
        type: ErrorType.unknown,
      );
    }
  }

  /// Log errors for debugging and monitoring
  static void logError(dynamic error, StackTrace? stackTrace, {String? context}) {
    if (kDebugMode) {
      debugPrint('=== ERROR LOG ===');
      debugPrint('Context: ${context ?? 'Unknown'}');
      debugPrint('Error: $error');
      debugPrint('Stack Trace: $stackTrace');
      debugPrint('================');
    }
  }
}

/// Custom exception class for app-specific errors
class AppException implements Exception {
  final String message;
  final ErrorType type;
  final int? statusCode;
  final dynamic originalError;

  AppException({
    required this.message,
    required this.type,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() {
    return 'AppException(type: $type, message: $message, statusCode: $statusCode)';
  }
}

/// Specific exception types
class ValidationException extends AppException {
  ValidationException(String message, {int? statusCode})
      : super(
          message: message,
          type: ErrorType.validation,
          statusCode: statusCode,
        );
}

class NetworkException extends AppException {
  NetworkException(String message)
      : super(
          message: message,
          type: ErrorType.network,
        );
}

class UnauthorizedException extends AppException {
  UnauthorizedException(String message)
      : super(
          message: message,
          type: ErrorType.unauthorized,
          statusCode: 401,
        );
}

class ForbiddenException extends AppException {
  ForbiddenException(String message)
      : super(
          message: message,
          type: ErrorType.forbidden,
          statusCode: 403,
        );
}

class ServerException extends AppException {
  ServerException(String message, {int? statusCode})
      : super(
          message: message,
          type: ErrorType.serverError,
          statusCode: statusCode,
        );
}

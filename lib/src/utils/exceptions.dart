abstract class TalkLynkException implements Exception {
  final String message;
  final String? code;
  final dynamic originalException;

  const TalkLynkException(
    this.message, {
    this.code,
    this.originalException,
  });

  @override
  String toString() {
    if (code != null) {
      return 'TalkLynkException ($code): $message';
    }
    return 'TalkLynkException: $message';
  }
}

/// Network-related exceptions
class NetworkException extends TalkLynkException {
  const NetworkException(String message,
      {String? code, dynamic originalException})
      : super(message, code: code, originalException: originalException);
}

/// API-related exceptions
class ApiException extends TalkLynkException {
  const ApiException(String message, {String? code, dynamic originalException})
      : super(message, code: code, originalException: originalException);
}

/// Authentication exceptions
class AuthenticationException extends TalkLynkException {
  const AuthenticationException(String message,
      {String? code, dynamic originalException})
      : super(message, code: code, originalException: originalException);
}

/// Authorization exceptions
class AuthorizationException extends TalkLynkException {
  const AuthorizationException(String message,
      {String? code, dynamic originalException})
      : super(message, code: code, originalException: originalException);
}

/// Resource not found exceptions
class NotFoundException extends TalkLynkException {
  const NotFoundException(String message,
      {String? code, dynamic originalException})
      : super(message, code: code, originalException: originalException);
}

/// Rate limit exceptions
class RateLimitException extends TalkLynkException {
  const RateLimitException(String message,
      {String? code, dynamic originalException})
      : super(message, code: code, originalException: originalException);
}

/// Server error exceptions
class ServerException extends TalkLynkException {
  const ServerException(String message,
      {String? code, dynamic originalException})
      : super(message, code: code, originalException: originalException);
}

/// WebRTC-related exceptions
class WebRTCException extends TalkLynkException {
  const WebRTCException(String message,
      {String? code, dynamic originalException})
      : super(message, code: code, originalException: originalException);
}

/// Call-related exceptions
class CallException extends TalkLynkException {
  const CallException(String message, {String? code, dynamic originalException})
      : super(message, code: code, originalException: originalException);
}

/// Room-related exceptions
class RoomException extends TalkLynkException {
  const RoomException(String message, {String? code, dynamic originalException})
      : super(message, code: code, originalException: originalException);
}

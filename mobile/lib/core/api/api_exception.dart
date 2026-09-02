/// A normalised error raised by [ApiClient]. Screens can show [message] directly.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;

  /// The backend's machine-readable `code` field when present
  /// (e.g. `USER_EXISTS`, `AUTH_ERROR`).
  final String? code;

  bool get isUnauthorized => statusCode == 401;
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => 'ApiException($statusCode, $message)';
}

/// Typed exceptions thrown by repositories.
/// This keeps error handling clean and consistent across the app.
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 4xx / 5xx HTTP errors from the backend.
class ApiException extends AppException {
  const ApiException(super.message, {this.statusCode});
  final int? statusCode;
}

/// Network unreachable / timeout.
class NetworkException extends AppException {
  const NetworkException([super.message = 'No internet connection or server unreachable.']);
}

/// File too large / unsupported format.
class FileException extends AppException {
  const FileException(super.message);
}

/// SSE stream error event received from backend.
class StreamException extends AppException {
  const StreamException(super.message);
}
/// App-wide configuration constants.
/// The [baseUrl] is the only value that changes between
/// local development and production (Railway deployment).
class AppConfig {
  AppConfig._();

  // ── Change this to your Railway URL when deployed ─────────────────────────
  static const String defaultBaseUrl = 'http://10.0.2.2:8000';
  // 10.0.2.2 is Android emulator's alias for the host machine's localhost.
  // On a real device on the same WiFi, use your machine's local IP e.g:
  // static const String defaultBaseUrl = 'http://192.168.1.x:8000';

  static const String appName = 'Personal Knowledge Base Agent';
  static const String appVersion = '1.0.0';

  // API timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(minutes: 5); // long for SSE
  static const Duration sendTimeout = Duration(minutes: 2);    // long for uploads

  // Pagination
  static const int pageSize = 20;

  // Upload
  static const int maxFileSizeMb = 50;
  static const List<String> allowedExtensions = [
    'pdf', 'txt', 'md', 'png', 'jpg', 'jpeg', 'tiff', 'bmp', 'webp',
  ];
}
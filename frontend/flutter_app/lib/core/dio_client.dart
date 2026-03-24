import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'exceptions.dart';

// ── SharedPreferences key ─────────────────────────────────────────────────────
const _kBaseUrlKey = 'base_url';

// ── Provider ──────────────────────────────────────────────────────────────────
final dioClientProvider = Provider<DioClient>((ref) => DioClient());

/// Singleton Dio wrapper.
/// All API calls go through this class.
class DioClient {
  late final Dio _dio;

  DioClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.defaultBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout: AppConfig.sendTimeout,
        headers: {'Accept': 'application/json'},
      ),
    );

    _dio.interceptors.addAll([
      _LogInterceptor(),
      _ErrorInterceptor(),
    ]);

    // Load persisted base URL (in case user changed it in settings)
    _loadBaseUrl();
  }

  Future<void> _loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kBaseUrlKey);
    if (saved != null && saved.isNotEmpty) {
      _dio.options.baseUrl = saved;
    }
  }

  Future<void> setBaseUrl(String url) async {
    final trimmed = url.trimRight().replaceAll(RegExp(r'/$'), '');
    _dio.options.baseUrl = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrlKey, trimmed);
  }

  String get baseUrl => _dio.options.baseUrl;

  // ── Standard HTTP helpers ─────────────────────────────────────────────────

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? params}) =>
      _dio.get<T>(path, queryParameters: params);

  Future<Response<T>> post<T>(String path, {dynamic data}) =>
      _dio.post<T>(path, data: data);

  Future<Response<T>> patch<T>(String path, {dynamic data}) =>
      _dio.patch<T>(path, data: data);

  Future<Response<T>> delete<T>(String path) => _dio.delete<T>(path);

  Future<Response<T>> postForm<T>(
      String path, {
        required FormData formData,
        void Function(int, int)? onSendProgress,
      }) =>
      _dio.post<T>(
        path,
        data: formData,
        onSendProgress: onSendProgress,
      );

  // ── SSE streaming ─────────────────────────────────────────────────────────
  /// Opens a Server-Sent Events stream and yields parsed event maps.
  /// The backend emits lines like:  data: {"type":"token","data":"Hello"}
  ///
  /// Proper line buffering — accumulates bytes into a string buffer and
  /// splits on newlines only when a complete line is available. This handles
  /// TCP chunks that don't align with SSE message boundaries, which could
  /// cause 500 / parse errors.
  Stream<Map<String, dynamic>> sseStream(
      String path, {
        Map<String, dynamic>? body,
      }) async* {
    // Use a separate Dio instance with no error interceptor for SSE
    // so that 2xx streaming responses are not rejected.
    final sseDio = Dio(
      BaseOptions(
        baseUrl: _dio.options.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout: AppConfig.sendTimeout,
      ),
    );

    late Response<ResponseBody> response;
    try {
      response = await sseDio.post<ResponseBody>(
        path,
        data: body != null ? jsonEncode(body) : null,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
            'Cache-Control': 'no-cache',
          },
          responseType: ResponseType.stream,
          // Do NOT validate status here — let the stream through
          validateStatus: (status) => status != null && status < 600,
        ),
      );
    } catch (e) {
      throw NetworkException('Failed to connect to server: $e');
    }

    // If the server returned a non-2xx status, surface it as an error
    if (response.statusCode != null && response.statusCode! >= 400) {
      throw ApiException(
        'Server returned ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final rawStream = response.data!.stream;

    // ── Line buffer ───────────────────────────────────────────────────────
    // Accumulate incoming bytes. Yield complete SSE lines only when we
    // have seen a newline — handles partial TCP chunks correctly.
    final lineBuffer = StringBuffer();

    await for (final chunk in rawStream) {
      // Decode bytes to string, tolerating malformed UTF-8
      final text = utf8.decode(chunk, allowMalformed: true);
      lineBuffer.write(text);

      // Extract all complete lines from the buffer
      final buffered = lineBuffer.toString();
      final lines = buffered.split('\n');

      // The last element may be incomplete — put it back in the buffer
      lineBuffer
        ..clear()
        ..write(lines.last);

      // Process all complete lines (everything except the last)
      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue; // blank separator lines in SSE

        if (line.startsWith('data:')) {
          final jsonStr = line.substring(5).trim();
          if (jsonStr.isEmpty) continue;
          try {
            final event = jsonDecode(jsonStr) as Map<String, dynamic>;
            yield event;
          } catch (_) {
            // Malformed JSON in one line — skip it, keep streaming
          }
        }
      }
    }

    // Flush anything remaining in the buffer after the stream closes
    final remaining = lineBuffer.toString().trim();
    if (remaining.startsWith('data:')) {
      final jsonStr = remaining.substring(5).trim();
      if (jsonStr.isNotEmpty) {
        try {
          final event = jsonDecode(jsonStr) as Map<String, dynamic>;
          yield event;
        } catch (_) {}
      }
    }
  }
}

// ── Interceptors ──────────────────────────────────────────────────────────────

class _LogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // ignore: avoid_print
    print('[DIO] ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // ignore: avoid_print
    print('[DIO] ERROR ${err.response?.statusCode}: ${err.message}');
    handler.next(err);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppException appEx;

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        appEx = const NetworkException();
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode ?? 0;
        final detail = err.response?.data is Map
            ? err.response!.data['detail'] ?? 'Server error'
            : 'Server error ($status)';
        appEx = ApiException(detail.toString(), statusCode: status);
      default:
        appEx = ApiException(err.message ?? 'Unknown error');
    }

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: appEx,
        message: appEx.message,
        type: err.type,
        response: err.response,
      ),
    );
  }
}
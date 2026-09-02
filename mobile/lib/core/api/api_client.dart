import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../env.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Thin wrapper over Dio that:
///  - prefixes every request with the resolved base URL
///  - attaches `Authorization: Bearer <token>` when one is stored
///  - unwraps the backend envelope `{ success, data, code }` down to `data`
///  - turns every failure into an [ApiException]
class ApiClient {
  ApiClient({required String baseUrl, required TokenStorage tokenStorage})
      : _tokens = tokenStorage,
        _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokens.read();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStorage _tokens;

  /// Test seam: swap the underlying HTTP transport.
  set httpClientAdapter(HttpClientAdapter adapter) =>
      _dio.httpClientAdapter = adapter;

  Future<Object?> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: query));

  Future<Object?> post(String path, {Object? body}) =>
      _send(() => _dio.post(path, data: body));

  Future<Object?> _send(Future<Response<dynamic>> Function() run) async {
    try {
      final res = await run();
      final data = res.data;
      if (data is Map && data.containsKey('data')) return data['data'];
      return data;
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  ApiException _map(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    String message = '';
    String? code;
    if (body is Map) {
      message = (body['error'] ?? body['message'] ?? '').toString();
      code = body['code']?.toString();
    }
    if (message.isEmpty) {
      message = switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'The server took too long to respond.',
        DioExceptionType.connectionError =>
          'Could not reach the Hiww server. Check the connection and API URL.',
        DioExceptionType.badResponse when status == 429 =>
          'Too many attempts. Wait a minute and try again.',
        _ => status != null
            ? 'Request failed ($status).'
            : 'Something went wrong. Please try again.',
      };
    }
    return ApiException(message, statusCode: status, code: code);
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: resolveApiBaseUrl(),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

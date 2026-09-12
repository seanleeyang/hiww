import 'dart:ui' show PlatformDispatcher;

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/verification_required_dialog.dart';
import '../../features/settings/locale_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';
import '../../l10n/app_localizations_th.dart';
import '../env.dart';
import '../navigation.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Thin wrapper over Dio that:
///  - prefixes every request with the resolved base URL
///  - attaches `Authorization: Bearer <token>` when one is stored
///  - unwraps the backend envelope `{ success, data, code }` down to `data`
///  - turns every failure into an [ApiException]
class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenStorage tokenStorage,
    String locale = 'en',
  }) : _tokens = tokenStorage,
      // A network-level failure (timeout, no connection, rate limit) never
      // reaches the backend, so there's no localized message in the response
      // body to read — these fallback strings have to be picked client-side.
      // No BuildContext is available this deep, so the already-resolved
      // locale this client was built with (see `apiClientProvider`) is used
      // directly against the generated localizations classes instead.
      _l10n = locale == 'th' ? AppLocalizationsTh() : AppLocalizationsEn(),
      _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          // Every response here is dynamic, user-specific marketplace data —
          // there's never a legitimate reason for the browser to serve a
          // cached copy on web, so opt out explicitly rather than relying on
          // the backend to always remember to set this on every route.
          headers: {
            'Content-Type': 'application/json',
            'Cache-Control': 'no-store',
            // The backend renders AppError/notification text per-locale from
            // this — see src/i18n/locale.ts.
            'Accept-Language': locale,
          },
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
  final AppLocalizations _l10n;

  /// Test seam: swap the underlying HTTP transport.
  set httpClientAdapter(HttpClientAdapter adapter) =>
      _dio.httpClientAdapter = adapter;

  Future<Object?> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: query));

  // Every request carries `Content-Type: application/json` (see BaseOptions), so
  // a bodyless POST/PATCH must still send `{}` — Fastify rejects an empty body
  // when the content type says JSON. Several endpoints are action-only
  // (`/offers/:id/accept`, `/orders/:id/claim-payment`, …).
  Future<Object?> post(String path, {Object? body}) =>
      _send(() => _dio.post(path, data: body ?? const <String, dynamic>{}));

  Future<Object?> patch(String path, {Object? body}) =>
      _send(() => _dio.patch(path, data: body ?? const <String, dynamic>{}));

  Future<Object?> delete(String path) => _send(() => _dio.delete(path));

  /// Multipart upload of raw [bytes] as the `file` field. Works on web too
  /// because the payload is bytes, not a file path.
  Future<Object?> upload(
    String path, {
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    return _send(
      () => _dio.post(
        path,
        data: form,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      ),
    );
  }

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
          _l10n.errorServerTimeout,
        DioExceptionType.connectionError => _l10n.errorCannotReachServer,
        DioExceptionType.badResponse when status == 429 => _l10n.errorTooManyAttemptsWait,
        _ => status != null
            ? _l10n.errorRequestFailedWithStatus(status)
            : '${_l10n.errorGenericTitle}. ${_l10n.errorPleaseTryAgain}',
      };
    }
    if (code == 'VERIFICATION_REQUIRED') {
      // Fire the "Before You Proceed" prompt from wherever this error
      // happens to surface, without every call site needing to special-case
      // it. Post-frame since this can run mid-build/mid-error-handling.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null) showVerificationRequiredDialog(ctx);
      });
    }
    return ApiException(message, statusCode: status, code: code);
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final chosen = ref.watch(localeControllerProvider).valueOrNull;
  final locale = chosen?.languageCode ?? PlatformDispatcher.instance.locale.languageCode;
  return ApiClient(
    baseUrl: resolveApiBaseUrl(),
    tokenStorage: ref.watch(tokenStorageProvider),
    locale: locale,
  );
});

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/core/api/api_client.dart';
import 'package:hiww_mobile/core/api/api_exception.dart';
import 'package:hiww_mobile/core/storage/token_storage.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return handler(options);
  }
}

ResponseBody _json(Map<String, dynamic> body, int status) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  late _MockSecureStorage secureStorage;
  late TokenStorage tokens;

  setUp(() {
    secureStorage = _MockSecureStorage();
    when(() => secureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    tokens = TokenStorage(secureStorage);
  });

  ApiClient clientWith(_FakeAdapter adapter) {
    final client = ApiClient(baseUrl: 'http://test.local', tokenStorage: tokens);
    client.httpClientAdapter = adapter;
    return client;
  }

  test('unwraps the { success, data } envelope', () async {
    final client = clientWith(_FakeAdapter(
      (_) => _json({'success': true, 'data': {'id': 'u1'}, 'code': 'ME'}, 200),
    ));

    final data = await client.get('/api/me');

    expect(data, isA<Map>());
    expect((data as Map)['id'], 'u1');
  });

  test('maps a backend error body to ApiException', () async {
    final client = clientWith(_FakeAdapter(
      (_) => _json(
        {'error': 'Invalid email or password', 'code': 'AUTH_ERROR'},
        401,
      ),
    ));

    await expectLater(
      client.post('/api/auth/login', body: {'email': 'x', 'password': 'y'}),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.code, 'code', 'AUTH_ERROR')
            .having((e) => e.isUnauthorized, 'isUnauthorized', true),
      ),
    );
  });

  test('attaches the bearer token when one is stored', () async {
    when(() => secureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => 'tok-123');
    final adapter = _FakeAdapter(
      (_) => _json({'success': true, 'data': {}, 'code': 'OK'}, 200),
    );
    final client = clientWith(adapter);

    await client.get('/api/me');

    expect(adapter.lastRequest!.headers['Authorization'], 'Bearer tok-123');
  });

  test('gives a friendly message when the server is unreachable', () async {
    final client = clientWith(_FakeAdapter((options) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'refused',
      );
    }));

    await expectLater(
      client.get('/api/me'),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', contains('Could not reach'))),
    );
  });
}

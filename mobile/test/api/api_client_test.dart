import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postintime/api/api_client.dart';
import 'package:postintime/api/token_store.dart';

/// A Dio adapter driven by a callback so tests decide how the "server" answers.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options, Future<void>? cancelFuture) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    requests.add(options);
    return handler(options, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(Object body, {int status = 200}) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

/// An unsigned JWT-shaped token carrying [claims].
String tokenWith(Map<String, Object?> claims) {
  String part(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part(claims)}.sig';
}

ApiClient clientFor(FakeAdapter adapter, {String? token, Duration timeout = requestTimeout, DateTime Function()? clock}) {
  final dio = Dio()..httpClientAdapter = adapter;
  return ApiClient(
    tokenStore: MemoryTokenStore(token),
    baseUrl: 'http://api.test',
    dio: dio,
    timeout: timeout,
    clock: clock ?? DateTime.now,
  );
}

void main() {
  final valid = tokenWith({'sub': 'user-1', 'email': 'me@example.com', 'exp': DateTime(2100).millisecondsSinceEpoch ~/ 1000});

  group('apiFetch timeout', () {
    test('waits 15 minutes before giving up', () {
      expect(requestTimeout, const Duration(minutes: 15));
      fakeAsync((async) {
        final adapter = FakeAdapter((options, cancelFuture) {
          // A server that never answers; only an abort ends the request.
          final completer = Completer<ResponseBody>();
          cancelFuture?.then((_) => completer.completeError(
                DioException.requestCancelled(requestOptions: options, reason: 'cancelled'),
              ));
          return completer.future;
        });
        final client = clientFor(adapter, token: valid);
        unawaited(client.load());
        async.flushMicrotasks();

        var settled = false;
        Object? outcome;
        client.get('/api/v1/slow').then<void>((_) {}, onError: (Object e) {
          outcome = e;
        }).whenComplete(() => settled = true);

        async.elapse(requestTimeout - const Duration(milliseconds: 1));
        expect(settled, isFalse);
        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();
        expect(settled, isTrue);
        expect((outcome! as ApiException).message, 'The server did not respond within 15 minutes. Please try again.');
      });
    });

    test('still honours a caller abort', () async {
      final adapter = FakeAdapter((options, cancelFuture) {
        final completer = Completer<ResponseBody>();
        cancelFuture?.then((_) => completer.completeError(
              DioException.requestCancelled(requestOptions: options, reason: 'cancelled'),
            ));
        return completer.future;
      });
      final client = clientFor(adapter, token: valid);
      await client.load();
      final cancel = CancelToken();
      Object? error;
      final caller = client.send('GET', '/api/v1/slow', cancelToken: cancel).then<void>((_) {}, onError: (Object e) {
        error = e;
      });
      cancel.cancel('user');
      await caller;
      expect(error, isA<DioException>());
      expect(CancelToken.isCancel(error! as DioException), isTrue);
    });

    test('returns responses that arrive in time', () async {
      final client = clientFor(FakeAdapter((_, _) async => json({'ok': true})), token: valid);
      await client.load();
      expect(await client.get('/api/v1/fast'), {'ok': true});
    });
  });

  group('requests', () {
    test('sends the bearer token and JSON body', () async {
      final adapter = FakeAdapter((_, _) async => json({'id': '1'}));
      final client = clientFor(adapter, token: valid);
      await client.load();
      await client.post('/api/v1/channels', body: {'name': 'Tech'});
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.toString(), 'http://api.test/api/v1/channels');
      expect(request.headers['Authorization'], 'Bearer $valid');
      expect(request.headers['Content-Type'], 'application/json');
      expect(request.data, jsonEncode({'name': 'Tech'}));
    });

    test('returns null for 204 responses', () async {
      final client = clientFor(FakeAdapter((_, _) async => ResponseBody.fromString('', 204)), token: valid);
      await client.load();
      expect(await client.delete('/api/v1/channels/1'), isNull);
    });

    test('surfaces the API error message and code', () async {
      final client = clientFor(
        FakeAdapter((_, _) async => json({'message': 'Slug taken', 'code': 'CONFLICT'}, status: 409)),
        token: valid,
      );
      await client.load();
      await expectLater(
        client.post('/api/v1/channels', body: {}),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Slug taken')
            .having((e) => e.code, 'code', 'CONFLICT')
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });

    test('falls back to a generic message when the error body is empty', () async {
      final client = clientFor(FakeAdapter((_, _) async => ResponseBody.fromString('{}', 500)), token: valid);
      await client.load();
      await expectLater(client.get('/api/v1/x'), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Request failed')));
    });
  });

  group('session expiry', () {
    test('an expired token signs the user out without calling the API', () async {
      final expired = tokenWith({'exp': 1000});
      final adapter = FakeAdapter((_, _) async => json({}));
      final client = clientFor(adapter, token: expired);
      await client.load();
      var expiredCalls = 0;
      client.onSessionExpired(() => expiredCalls++);

      await expectLater(client.get('/api/v1/channels'), throwsA(isA<ApiException>().having((e) => e.isSessionExpired, 'expired', isTrue)));
      expect(expiredCalls, 1);
      expect(client.token, isNull);
      expect(adapter.requests, isEmpty);
    });

    test('a 401 AUTH_EXPIRED response signs the user out', () async {
      final client = clientFor(
        FakeAdapter((_, _) async => json({'message': 'Token expired', 'code': 'AUTH_EXPIRED'}, status: 401)),
        token: valid,
      );
      await client.load();
      var expiredCalls = 0;
      client.onSessionExpired(() => expiredCalls++);
      await expectLater(client.get('/api/v1/channels'), throwsA(isA<ApiException>()));
      expect(expiredCalls, 1);
      expect(client.token, isNull);
    });

    test('auth requests never expire the session', () async {
      final client = clientFor(
        FakeAdapter((_, _) async => json({'message': 'Bad credentials', 'code': 'AUTH_FAILED'}, status: 401)),
        token: valid,
      );
      await client.load();
      var expiredCalls = 0;
      client.onSessionExpired(() => expiredCalls++);
      await expectLater(client.post('/api/v1/auth/login', body: {}), throwsA(isA<ApiException>()));
      expect(expiredCalls, 0);
      expect(client.token, valid);
    });

    test('treats tokens without an expiry claim as valid and missing tokens as expired', () async {
      final client = clientFor(FakeAdapter((_, _) async => json({})));
      await client.load();
      expect(client.isTokenExpired(), isTrue);
      expect(client.isTokenExpired('opaque-token'), isFalse);
      expect(client.isTokenExpired(tokenWith({'exp': 1})), isTrue);
    });

    test('reads the expiry from url-safe base64 payloads', () {
      expect(tokenExpiryMs(tokenWith({'exp': 2000000000, 'email': 'ü@example.com'})), 2000000000 * 1000);
      expect(tokenExpiryMs('not-a-jwt'), isNull);
    });
  });
}

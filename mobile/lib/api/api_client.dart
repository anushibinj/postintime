import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'token_store.dart';

/// How long to wait for the API before giving up. Publishing calls wait for the social media
/// webhook, which can take many minutes, so this matches the backend's 15 minute webhook timeout.
const Duration requestTimeout = Duration(minutes: 15);

const String sessionExpiredMessage = 'Session expired';
const String timeoutMessage = 'The server did not respond within 15 minutes. Please try again.';

class ApiException implements Exception {
  const ApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  bool get isSessionExpired => message == sessionExpiredMessage;

  @override
  String toString() => message;
}

/// Pulls the human readable message out of any thrown error.
String errorMessage(Object error, [String fallback = 'Something went wrong']) {
  if (error is ApiException && error.message.isNotEmpty) {
    return error.message;
  }
  return fallback;
}

/// Decodes the JWT payload without verifying it; only the expiry and identity claims are read.
Map<String, dynamic>? decodeTokenPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length < 2) {
      return null;
    }
    final decoded = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final payload = jsonDecode(decoded);
    return payload is Map<String, dynamic> ? payload : null;
  } catch (_) {
    return null;
  }
}

int? tokenExpiryMs(String token) {
  final exp = decodeTokenPayload(token)?['exp'];
  return exp is num ? exp.toInt() * 1000 : null;
}

bool _isAuthRequest(String path) => path.startsWith('/api/v1/auth/');

/// Talks to the PostInTime API: attaches the session token, enforces the long request timeout and
/// signs the user out when the session expires.
class ApiClient {
  ApiClient({
    required this._tokenStore,
    required this.baseUrl,
    Dio? dio,
    this._timeout = requestTimeout,
    this._clock = DateTime.now,
  })  : _dio = dio ?? Dio();

  final TokenStore _tokenStore;
  final Dio _dio;
  final Duration _timeout;
  final DateTime Function() _clock;
  final Set<void Function()> _sessionExpiredListeners = {};
  String? _token;

  /// The API origin; changing it applies to the next request.
  String baseUrl;

  /// Reads the stored token so [token] is available synchronously.
  Future<void> load() async {
    _token = await _tokenStore.read();
  }

  String? get token => _token;

  /// The current time as this client sees it (injectable so tests can fake it).
  DateTime now() => _clock();

  Future<void> setToken(String token) async {
    _token = token;
    await _tokenStore.write(token);
  }

  Future<void> clearToken() async {
    _token = null;
    await _tokenStore.delete();
  }

  bool isTokenExpired([String? candidate]) {
    final value = candidate ?? _token;
    if (value == null || value.isEmpty) {
      return true;
    }
    final expiryMs = tokenExpiryMs(value);
    if (expiryMs == null) {
      return false;
    }
    return _clock().millisecondsSinceEpoch >= expiryMs;
  }

  void Function() onSessionExpired(void Function() listener) {
    _sessionExpiredListeners.add(listener);
    return () => _sessionExpiredListeners.remove(listener);
  }

  void expireSession() {
    if (_token == null) {
      return;
    }
    unawaited(clearToken());
    for (final listener in List.of(_sessionExpiredListeners)) {
      listener();
    }
  }

  /// Sends a request and returns the decoded JSON body (`null` for an empty or 204 response).
  Future<dynamic> send(
    String method,
    String path, {
    Object? body,
    FormData? formData,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    if (!_isAuthRequest(path) && isTokenExpired()) {
      expireSession();
      throw const ApiException(sessionExpiredMessage);
    }

    final headers = <String, dynamic>{};
    if (formData == null) {
      headers['Content-Type'] = 'application/json';
    }
    final token = _token;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final cancel = CancelToken();
    var timedOut = false;
    final timer = Timer(_timeout, () {
      timedOut = true;
      cancel.cancel('timeout');
    });
    // A caller abort cancels the request too.
    unawaited(cancelToken?.whenCancel.then((error) => cancel.cancel(error.error)));

    try {
      final response = await _dio.request<String>(
        '$baseUrl$path',
        data: formData ?? (body == null ? null : jsonEncode(body)),
        queryParameters: query,
        cancelToken: cancel,
        options: Options(
          method: method,
          headers: headers,
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );
      return _handleResponse(path, response);
    } on DioException catch (error) {
      if (timedOut) {
        throw const ApiException(timeoutMessage);
      }
      if (CancelToken.isCancel(error)) {
        rethrow;
      }
      throw const ApiException('Could not reach the server. Check your connection and the server address.');
    } finally {
      timer.cancel();
    }
  }

  dynamic _handleResponse(String path, Response<String> response) {
    final status = response.statusCode ?? 0;
    final raw = response.data;
    if (status < 200 || status >= 300) {
      String? message;
      String? code;
      try {
        final decoded = jsonDecode(raw ?? '');
        if (decoded is Map<String, dynamic>) {
          message = decoded['message'] as String?;
          code = decoded['code'] as String?;
        }
      } catch (_) {
        message = response.statusMessage;
      }
      final isAuthFailure = code == 'AUTH_FAILED' || code == 'AUTH_EXPIRED';
      if (status == 401 && !_isAuthRequest(path) && isAuthFailure) {
        expireSession();
      }
      throw ApiException(
        message == null || message.isEmpty ? 'Request failed' : message,
        code: code,
        statusCode: status,
      );
    }
    if (status == 204 || raw == null || raw.isEmpty) {
      return null;
    }
    return jsonDecode(raw);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) => send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body}) => send('POST', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) => send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => send('DELETE', path);
}

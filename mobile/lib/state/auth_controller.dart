import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import 'core_providers.dart';

/// Timers longer than this overflow on some platforms, so a far-off expiry is re-checked in steps.
const Duration _maxTimer = Duration(days: 20);

AuthUser? userFromToken(String token) {
  final payload = decodeTokenPayload(token);
  if (payload == null) {
    return null;
  }
  final email = payload['email'] as String? ?? '';
  return AuthUser(token: token, userId: payload['sub'] as String? ?? '', email: email, displayName: email);
}

/// The signed-in user, restored from the stored token and signed out when it expires.
class AuthController extends Notifier<AuthUser?> {
  Timer? _expiryTimer;

  ApiClient get _client => ref.read(apiClientProvider);

  @override
  AuthUser? build() {
    final client = ref.watch(apiClientProvider);
    final stopListening = client.onSessionExpired(() {
      _expiryTimer?.cancel();
      state = null;
    });
    ref.onDispose(() {
      stopListening();
      _expiryTimer?.cancel();
    });

    final token = client.token;
    if (token == null || client.isTokenExpired(token)) {
      if (token != null) {
        unawaited(client.clearToken());
      }
      return null;
    }
    _scheduleExpiry(token);
    return userFromToken(token);
  }

  Future<void> login(String email, String password) async {
    setUser(await ref.read(authApiProvider).login(email, password));
  }

  Future<void> register(String email, String password, [String? displayName]) async {
    setUser(await ref.read(authApiProvider).register(email, password, displayName));
  }

  /// Signs in with a freshly issued session (login or register response).
  void setUser(AuthUser user) {
    state = user;
    _scheduleExpiry(user.token);
  }

  Future<void> logout() async {
    _expiryTimer?.cancel();
    await _client.clearToken();
    state = null;
  }

  void _scheduleExpiry(String token) {
    _expiryTimer?.cancel();
    final expiryMs = tokenExpiryMs(token);
    if (expiryMs == null) {
      return;
    }
    final remaining = Duration(milliseconds: expiryMs - _client.now().millisecondsSinceEpoch);
    final wait = remaining.isNegative ? Duration.zero : (remaining > _maxTimer ? _maxTimer : remaining);
    _expiryTimer = Timer(wait, () {
      if (_client.isTokenExpired(token)) {
        unawaited(logout());
      } else {
        _scheduleExpiry(token);
      }
    });
  }
}

final authProvider = NotifierProvider<AuthController, AuthUser?>(AuthController.new);

/// Changes whenever the signed-in session does, so cached server data is dropped on sign-out.
final sessionKeyProvider = Provider<String?>((ref) => ref.watch(authProvider)?.token);

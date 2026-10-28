import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the session JWT lives between app launches (the web app uses localStorage).
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

const tokenKey = 'postintime_token';

/// Keeps the token in the platform keychain / keystore.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: tokenKey);
    } catch (_) {
      // A keystore that cannot be read (for example after a restore) just means "signed out".
      return null;
    }
  }

  @override
  Future<void> write(String token) => _storage.write(key: tokenKey, value: token);

  @override
  Future<void> delete() => _storage.delete(key: tokenKey);
}

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this._token]);

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> delete() async => _token = null;
}

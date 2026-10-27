import '../models/models.dart';
import 'api_client.dart';

class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  Future<AuthUser> register(String email, String password, [String? displayName]) async {
    final json = await _client.post('/api/v1/auth/register', body: {
      'email': email,
      'password': password,
      if (displayName != null && displayName.isNotEmpty) 'displayName': displayName,
    }) as Map<String, dynamic>;
    final user = AuthUser.fromJson(json);
    await _client.setToken(user.token);
    return user;
  }

  Future<AuthUser> login(String email, String password) async {
    final json = await _client.post('/api/v1/auth/login', body: {
      'email': email,
      'password': password,
    }) as Map<String, dynamic>;
    final user = AuthUser.fromJson(json);
    await _client.setToken(user.token);
    return user;
  }
}

import '../models/models.dart';
import 'api_client.dart';

class ApiTokensApi {
  ApiTokensApi(this._client);

  final ApiClient _client;

  Future<List<ApiToken>> fetchApiTokens() async {
    final json = await _client.get('/api/v1/api-tokens') as List<dynamic>;
    return json.whereType<Map<String, dynamic>>().map(ApiToken.fromJson).toList();
  }

  Future<ApiToken> createApiToken({required String name, DateTime? expiresAt}) async {
    final json = await _client.post(
      '/api/v1/api-tokens',
      body: {'name': name, 'expiresAt': expiresAt?.toUtc().toIso8601String()},
    ) as Map<String, dynamic>;
    return ApiToken.fromJson(json);
  }

  /// Either sets a new expiry ([expiresAt]) or removes it ([neverExpires]).
  Future<ApiToken> updateApiToken(
    String tokenId, {
    String? name,
    DateTime? expiresAt,
    bool neverExpires = false,
  }) async {
    final json = await _client.patch(
      '/api/v1/api-tokens/$tokenId',
      body: {
        'name': ?name,
        if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
        if (neverExpires) 'neverExpires': true,
      },
    ) as Map<String, dynamic>;
    return ApiToken.fromJson(json);
  }

  Future<ApiToken> refreshApiToken(String tokenId, {DateTime? expiresAt, bool neverExpires = false}) async {
    final json = await _client.post(
      '/api/v1/api-tokens/$tokenId/refresh',
      body: {
        if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
        if (neverExpires) 'neverExpires': true,
      },
    ) as Map<String, dynamic>;
    return ApiToken.fromJson(json);
  }

  Future<void> deleteApiToken(String tokenId) async {
    await _client.delete('/api/v1/api-tokens/$tokenId');
  }
}

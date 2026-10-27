import '../models/models.dart';
import 'api_client.dart';

class PublishingApi {
  PublishingApi(this._client);

  final ApiClient _client;

  String _targets(String channelId, String postId) => '/api/v1/channels/$channelId/posts/$postId/targets';

  Future<List<PostTarget>> fetchTargets(String channelId, String postId) async {
    final json = await _client.get(_targets(channelId, postId)) as List<dynamic>;
    return json.whereType<Map<String, dynamic>>().map(PostTarget.fromJson).toList();
  }

  Future<List<PostTarget>> createTargets(String channelId, String postId, List<String> socialAccountIds) async {
    final json = await _client.post(_targets(channelId, postId), body: {'socialAccountIds': socialAccountIds})
        as List<dynamic>;
    return json.whereType<Map<String, dynamic>>().map(PostTarget.fromJson).toList();
  }

  Future<PublishResponse> publishTarget(String channelId, String postId, String targetId) async {
    final json = await _client.post('${_targets(channelId, postId)}/$targetId/publish') as Map<String, dynamic>;
    return PublishResponse.fromJson(json);
  }

  Future<PostTarget> markPublished(String channelId, String postId, String targetId, {String? externalUrl}) async {
    final json = await _client.post('${_targets(channelId, postId)}/$targetId/mark-published', body: {
      'externalUrl': ?externalUrl,
      'notes': 'Published manually',
    }) as Map<String, dynamic>;
    return PostTarget.fromJson(json);
  }

  Future<PostTarget> resetTarget(String channelId, String postId, String targetId) async {
    final json = await _client.post('${_targets(channelId, postId)}/$targetId/reset') as Map<String, dynamic>;
    return PostTarget.fromJson(json);
  }

  Future<PostTarget> togglePublished(String channelId, String postId, String socialAccountId) async {
    final json = await _client.post('${_targets(channelId, postId)}/toggle', body: {
      'socialAccountId': socialAccountId,
    }) as Map<String, dynamic>;
    return PostTarget.fromJson(json);
  }
}

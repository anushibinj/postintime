import '../models/models.dart';
import 'api_client.dart';

class ChannelsApi {
  ChannelsApi(this._client);

  final ApiClient _client;

  Future<List<Channel>> fetchChannels() async {
    final json = await _client.get('/api/v1/channels') as List<dynamic>;
    return json.whereType<Map<String, dynamic>>().map(Channel.fromJson).toList();
  }

  Future<Channel> fetchChannel(String channelId) async {
    final json = await _client.get('/api/v1/channels/$channelId') as Map<String, dynamic>;
    return Channel.fromJson(json);
  }

  Future<Channel> createChannel({required String name, required String slug, String? description}) async {
    final json = await _client.post('/api/v1/channels', body: {
      'name': name,
      'slug': slug,
      'description': ?description,
    }) as Map<String, dynamic>;
    return Channel.fromJson(json);
  }

  Future<Channel> updateChannel(
    String channelId, {
    String? name,
    String? slug,
    String? description,
    bool? enabled,
  }) async {
    final json = await _client.patch('/api/v1/channels/$channelId', body: {
      'name': ?name,
      'slug': ?slug,
      'description': ?description,
      'enabled': ?enabled,
    }) as Map<String, dynamic>;
    return Channel.fromJson(json);
  }

  Future<void> deleteChannel(String channelId) async {
    await _client.delete('/api/v1/channels/$channelId');
  }
}

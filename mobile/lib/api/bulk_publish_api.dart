import '../models/models.dart';
import 'api_client.dart';

class BulkPublishApi {
  BulkPublishApi(this._client);

  final ApiClient _client;

  String _jobs(String channelId) => '/api/v1/channels/$channelId/bulk-publish-jobs';

  Future<List<BulkPublishJob>> fetchJobs(String channelId) async {
    final json = await _client.get(_jobs(channelId)) as List<dynamic>;
    return json.whereType<Map<String, dynamic>>().map(BulkPublishJob.fromJson).toList();
  }

  Future<BulkPublishJob> createJob(
    String channelId,
    List<String> postIds,
    int intervalMinutes,
    List<String> socialAccountIds,
  ) async {
    final json = await _client.post(_jobs(channelId), body: {
      'postIds': postIds,
      'intervalMinutes': intervalMinutes,
      'socialAccountIds': socialAccountIds,
    }) as Map<String, dynamic>;
    return BulkPublishJob.fromJson(json);
  }

  Future<BulkPublishJob> cancelItem(String channelId, String jobId, String itemId) async {
    final json = await _client.post('${_jobs(channelId)}/$jobId/items/$itemId/cancel') as Map<String, dynamic>;
    return BulkPublishJob.fromJson(json);
  }

  Future<BulkPublishJob> cancelJob(String channelId, String jobId) async {
    final json = await _client.post('${_jobs(channelId)}/$jobId/cancel') as Map<String, dynamic>;
    return BulkPublishJob.fromJson(json);
  }
}

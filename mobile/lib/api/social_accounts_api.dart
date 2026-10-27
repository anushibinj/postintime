import '../models/models.dart';
import 'api_client.dart';

/// The editable fields of a social account; null fields are left out of the request.
class SocialAccountInput {
  const SocialAccountInput({
    this.platform,
    this.name,
    this.profileUrl,
    this.postingMode,
    this.webhookUrl,
    this.webhookAuthType,
    this.webhookUsername,
    this.webhookPassword,
  });

  final Platform? platform;
  final String? name;
  final String? profileUrl;
  final PostingMode? postingMode;
  final String? webhookUrl;
  final WebhookAuthType? webhookAuthType;
  final String? webhookUsername;
  final String? webhookPassword;

  Map<String, dynamic> toJson() => {
        if (platform != null) 'platform': platform!.name,
        if (name != null) 'name': name,
        if (profileUrl != null) 'profileUrl': profileUrl,
        if (postingMode != null) 'postingMode': postingMode!.name,
        if (webhookUrl != null) 'webhookUrl': webhookUrl,
        if (webhookAuthType != null) 'webhookAuthType': webhookAuthType!.name,
        if (webhookUsername != null) 'webhookUsername': webhookUsername,
        if (webhookPassword != null) 'webhookPassword': webhookPassword,
      };
}

class SocialAccountsApi {
  SocialAccountsApi(this._client);

  final ApiClient _client;

  String _base(String channelId) => '/api/v1/channels/$channelId/social-accounts';

  Future<List<SocialAccount>> fetchSocialAccounts(String channelId) async {
    final json = await _client.get(_base(channelId)) as List<dynamic>;
    return json.whereType<Map<String, dynamic>>().map(SocialAccount.fromJson).toList();
  }

  Future<SocialAccount> createSocialAccount(String channelId, SocialAccountInput data) async {
    final json = await _client.post(_base(channelId), body: data.toJson()) as Map<String, dynamic>;
    return SocialAccount.fromJson(json);
  }

  Future<SocialAccount> updateSocialAccount(String channelId, String accountId, SocialAccountInput data) async {
    final json = await _client.patch('${_base(channelId)}/$accountId', body: data.toJson()) as Map<String, dynamic>;
    return SocialAccount.fromJson(json);
  }

  Future<void> deleteSocialAccount(String channelId, String accountId) async {
    await _client.delete('${_base(channelId)}/$accountId');
  }

  Future<SocialAccount> enableSocialAccount(String channelId, String accountId) async {
    final json = await _client.post('${_base(channelId)}/$accountId/enable') as Map<String, dynamic>;
    return SocialAccount.fromJson(json);
  }

  Future<SocialAccount> disableSocialAccount(String channelId, String accountId) async {
    final json = await _client.post('${_base(channelId)}/$accountId/disable') as Map<String, dynamic>;
    return SocialAccount.fromJson(json);
  }
}
